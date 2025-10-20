extends Node
class_name MissionEvent

### Class-level documentation ###
'''
MissionEvent is an abstract base class for atomic mission events that can be triggered during gameplay. 
It provides core execution logic for three types of events: instant, timed, and recurring. 
Subclasses must implement the _execute() method to define their specific behavior.

Key Features:
- ExecutionType enum for controlling event timing
- Priority-based handling for event sequencing
- Timer management for timed/recurring events
- Signal-based event lifecycle tracking
'''

### Enums ###
enum ExecutionType {
	INSTANT,    # Event executes immediately upon trigger
	TIMED,      # Event executes after a delay
	RECURRING   # Event executes repeatedly at fixed intervals
}

### Exported Properties ###
@export var execution_type: ExecutionType = ExecutionType.INSTANT
	# The type of event execution strategy to use

@export var delay: float = 0.0
	# Delay in seconds before executing timed events (ignored for other types)

@export var repeat_interval: float = 0.0
	# Interval in seconds between recurring executions (ignored for other types)

@export var priority: int = 1
	# Determines execution order (lower numbers executed first)

### Internal State ###
var _timer: Timer = null
	# Internal timer used for timed/recurring events

var _is_active: bool = false
	# Tracks whether the event is currently executing

### Signals ###
signal event_activated
	# Emitted when event execution begins

signal event_ended
	# Emitted when event execution completes or is interrupted

### Public API ###
'''
@func execute
@brief Initiates the event execution based on its execution type
@note Validates state before starting new executions
'''
func execute() -> void:
	if _is_active:
		push_warning("Event already active: %s" % name)
		return

	match execution_type:
		ExecutionType.INSTANT:
			_start_instant()
		ExecutionType.TIMED:
			_start_timed()
		ExecutionType.RECURRING:
			_start_recurring()

'''
@func stop
@brief Cancels ongoing execution and cleans up resources
@description Stops timers and signals completion
'''
func stop() -> void:
	if _timer:
		_timer.stop()
		_timer.queue_free()
		_timer = null
	_is_active = false
	emit_signal("event_ended")

### Execution Logic ###
'''
@func _start_instant
@brief Handles immediate execution
@description Calls _execute() immediately then stops the event
'''
func _start_instant() -> void:
	_execute()
	stop()

'''
@func _start_timed
@brief Sets up timed execution
@description Creates a one-shot timer with the configured delay
'''
func _start_timed() -> void:
	_timer = Timer.new()
	_timer.wait_time = delay
	_timer.one_shot = true
	_timer.timeout.connect(_execute_wrapper)
	add_child(_timer)
	_timer.start()
	_is_active = true

'''
@func _start_recurring
@brief Sets up recurring execution
@description Creates a repeating timer with the configured interval
'''
func _start_recurring() -> void:
	_timer = Timer.new()
	_timer.wait_time = repeat_interval
	_timer.one_shot = false
	_timer.timeout.connect(_execute_wrapper)
	add_child(_timer)
	_timer.start()
	_is_active = true

'''
@func _execute_wrapper
@brief Safely invokes the actual execution logic
@description Ensures signals are emitted properly
'''
func _execute_wrapper() -> void:
	_execute()
	emit_signal("event_activated")

'''
@func _execute
@brief Abstract method for custom event logic
@warning Must be implemented in derived classes
@note Contains error enforcement to prevent misuse
'''
func _execute() -> void:
	push_error("Implement _execute() in derived class")

### Lifecycle ###

'''
@func _exit_tree
@brief Ensures proper cleanup when node is removed from scene tree
@description 
    1. Stops any ongoing event execution
    2. Releases timer resources
    3. Calls parent class cleanup
@note Must be called during node removal
'''

func _exit_tree() -> void:
	# Cleanup resources
	if _timer:
		_timer.stop()
		_timer = null
	# Call Node's _exit_tree()
	#super()
