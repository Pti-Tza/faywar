# initiative_data.gd
class_name InitiativeData
extends Resource
## Configuration resource for initiative calculation and presentation
##
## Centralized data container for tuning initiative system behavior.
## Configure calculation parameters, tiebreaker rules, and UI responsiveness.
## Create multiple resources for different game modes or rule sets.

@export_category("Calculation Parameters")
## Weight multiplier for unit speed in initiative calculation
## Higher values increase speed's impact on turn order
@export var base_speed_weight: float = 1.0

## Weight multiplier for unit agility in initiative calculation
## Combines with speed for composite initiative score
@export var agility_weight: float = 0.5

## Random variance range applied to initiative scores (min, max)
## Adds unpredictability while maintaining stat dominance
## Format: Vector2(x = minimum variance, y = maximum variance)
@export var variance_range: Vector2 = Vector2(-0.1, 0.1)

@export_category("Tiebreakers")
## Ordered list of tiebreaker criteria (first match wins)
## Valid values: "speed", "agility", "random"
## Example: ["speed", "random"] - Compare speed, then random if tied
@export var tiebreaker_priority := ["speed", "agility", "random"]

## Seed value for deterministic random tiebreakers
## Zero = true random, Non-zero = reproducible results
@export var random_seed: int = 0

@export_category("UI Configuration")
## Delay (in seconds) before updating turn order predictions
## Prevents visual jitter during rapid calculations
@export var prediction_update_delay: float = 0.2

#region Usage Example
## Create in Godot Editor:
## 1. Right-click in FileSystem > New Resource
## 2. Select InitiativeData
## 3. Configure parameters in Inspector
##
## Script Access:
## var initiative_config = load("res://path/initiative_data.tres")
## var speed_weight = initiative_config.base_speed_weight
#endregion

#region Best Practices
## - Create different resources for varied game modes
## - Use negative variance for strategic unpredictability
## - Set random_seed for competitive/replayable matches
## - Combine multiple resources for difficulty levels
#endregion

## Fast-paced game variant
#var fast_config = InitiativeData.new()
#fast_config.base_speed_weight = 2.0
#fast_config.agility_weight = 0.2
#fast_config.variance_range = Vector2(-0.2, 0.2)
#fast_config.tiebreaker_priority = ["speed", "random"]
#fast_config.prediction_update_delay = 0.1
