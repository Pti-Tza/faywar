# HitProfile.gd
extends Resource
class_name HitProfile

## Defines hit probabilities for different unit sections based on attack angle
## This resource allows for easy configuration of which sections can be hit from different angles

@export_group("Hit Probabilities by Direction")
@export var front_hit_weights: Dictionary = {"Front": 70, "Left": 15, "Right": 15}
@export var rear_hit_weights: Dictionary = {"Rear": 70, "Left": 15, "Right": 15}
@export var left_hit_weights: Dictionary = {"Left": 60, "Front": 20, "Rear": 20}
@export var right_hit_weights: Dictionary = {"Right": 60, "Front": 20, "Rear": 20}

## Define which sections exist on this unit for hit probability calculations
@export var valid_sections: Array[String] = ["Front", "Rear", "Left", "Right", "Turret", "Head"]

## Get hit weights based on attack angle (in degrees)
func get_hit_weights_for_angle(attack_angle: float) -> Dictionary:
	var normalized_angle = fposmod(attack_angle + 180, 360) - 180
	
	if normalized_angle >= -45 and normalized_angle < 45:
		return front_hit_weights
	elif normalized_angle >= 45 and normalized_angle < 135:
		return right_hit_weights
	elif normalized_angle >= 135 or normalized_angle < -135:
		return rear_hit_weights
	else: # -135 to -45
		return left_hit_weights

## Normalize weights so they sum to 10 for probability calculations
func normalize_weights(weights: Dictionary) -> Dictionary:
	var total = 0.0
	for value in weights.values():
		total += value
	
	if total == 0:
		return weights
	
	var normalized = {}
	for section in weights.keys():
		normalized[section] = weights[section] / total
	
	return normalized