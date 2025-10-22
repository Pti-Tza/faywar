extends Node
class_name MissionScenario

'''
MissionScenario is the central configuration resource for defining mission parameters, objectives, and failure conditions.
It serves as the blueprint for all mission logic, allowing designers to compose complex scenarios through modular components.
'''

### Core Metadata ###

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
