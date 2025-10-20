extends Node
class_name MissionScenario

'''
MissionScenario is the central configuration resource for defining mission parameters, objectives, and failure conditions.
It serves as the blueprint for all mission logic, allowing designers to compose complex scenarios through modular components.
'''

### Core Metadata ###
@export_category("Mission Metadata")
@export var mission_name: String = "Operation Phoenix" 
	# Display name for the mission
@export var mission_id: String = "campaign_1_mission_3" 
	# Unique identifier for tracking and loading
@export var mission_description: String = "Eliminate hostile forces in a strategic engagement." 
	# Brief description for UI display
@export var mission_difficulty: int = 0 
	# 0=Easy, 1=Medium, 2=Hard (for procedural adjustments)

@export_category("Team Configuration")
@export var team_relationships := {
	# Team 0 (Player)
	0: {
		allies = [3],  # Team 3 is ally
		enemies = [1, 2]  # Teams 1 and 2 are hostile
	},
	# Team 1 (Enemy)
	1: {
		allies = [2],
		enemies = [0, 3]
	}
}

### Objective Configuration ###
@export_category("Mission Objectives")
@export var primary_objectives: Array[MissionObjective] = []
	# Objectives required for mission victory
@export var secondary_objectives: Array[MissionObjective] = []
	# Optional objectives for bonus rewards

### Combat Rules ###
@export_category("Combat Rules")
@export var turn_limit: int = -1 
	# Maximum turns before auto-failure (-1 = no limit)
@export var auto_save_interval: int = 5 
	# Turns between auto-saves (0 = disabled)
@export var environmental_effects: Array[MissionEvent] = []
	# Persistent effects applied at mission start

### Progression ###
@export_category("Progression")
@export var victory_rewards: Dictionary = {"xp": 1000, "currency": 5000} 
	# Rewards granted on mission success
@export var failure_consequences: Dictionary = {"xp_loss": 200, "unit_damage": 0.15} 
	# Penalties applied on mission failure

### Visibility ###
@export_category("Editor")
@export var preview_image: Texture = null 
	# Thumbnail for mission selection UI
@export var is_available: bool = true 
	# Determines if mission can be selected

### Validation ###
func _validate_properties() -> void:
	if mission_id.is_empty():
		push_error("Mission ID cannot be empty")
	
	if primary_objectives.size() == 0:
		push_warning("No primary objectives defined")
	
	if turn_limit < -1:
		push_error("Turn limit must be -1 (unlimited) or higher")

### Helper Methods ###
func has_victory_conditions() -> bool:
	return primary_objectives.size() > 0

func is_time_limited() -> bool:
	return turn_limit > 0

func get_total_objectives() -> int:
	return primary_objectives.size() + secondary_objectives.size()
