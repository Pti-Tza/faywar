# TeamManager.gd
extends Node
class_name TeamManager
## Singleton managing team relationships
static var instance: TeamManager

## Team relationships matrix
## Format: { team_index: { allies: [], enemies: [] } }
@export_category("Team Configuration")
@export var _team_relationships := {
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

func _init():
	instance = self


func are_allies(team_a: int, team_b: int) -> bool:
	return team_a == team_b || _team_relationships[team_a].allies.has(team_b)

func are_enemies(team_a: int, team_b: int) -> bool:
	return _team_relationships[team_a].enemies.has(team_b)

func get_hostile_teams(for_team: int) -> Array[int]:
	return _team_relationships[for_team].enemies
