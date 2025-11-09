# HitProfile.gd
extends Node
class_name HitProfile

## Defines hit probabilities for different unit sections based on attack angle
## This resource allows for easy configuration of which sections can be hit from different angles

var front_hit_weights: Dictionary = {}
var rear_hit_weights: Dictionary = {}
var left_hit_weights: Dictionary = {}
var right_hit_weights: Dictionary = {}

## Define which sections exist on this unit for hit probability calculations
var valid_sections: Array[UnitSection] = []

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
