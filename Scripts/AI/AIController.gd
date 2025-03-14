
extends BaseController
class_name AIController
# Configuration
@export var ai_strategy: AIStrategy
@export var decision_delay: float = 0.5

# State
var current_unit: Node
var current_plan: Dictionary
var decision_timer: float = 0.0

func begin_turn(unit: Node) -> void:
	super(unit)
	current_unit = unit
	ai_strategy.initialize(unit)
	_generate_plan()

func _generate_plan():
	current_plan = {
		"movement": ai_strategy.calculate_movement(),
		"combat": ai_strategy.calculate_combat(),
		"priority": ai_strategy.get_priority()
	}

func process_turn(delta: float) -> void:
	decision_timer += delta
	if decision_timer >= decision_delay:
		_execute_next_action()
		decision_timer = 0.0

func _execute_next_action():
	if current_plan.movement.valid:
		_execute_movement()
	elif current_plan.combat.valid:
		_execute_combat()
	else:
		end_turn()

func _execute_movement():
	MovementSystem.request_path(
		current_unit,
		current_plan.movement.target,
		ai_strategy.movement_speed
	)
	action_selected.emit("move")

func _execute_combat():
	AttackSystem.execute_attack(
		current_unit,
		current_plan.combat.target,
		current_plan.combat.weapon
	)
	action_selected.emit("attack")

func end_turn():
	current_unit = null
	current_plan = {}
	super()
