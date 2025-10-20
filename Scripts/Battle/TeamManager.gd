# TeamManager.gd
extends Node
class_name TeamManager
## Singleton managing team relationships
static var instance: TeamManager

## Team relationships matrix
## Format: { team_index: { allies: [], enemies: [] } }
var _team_relationships := {}

func _init():
	instance = self

func initialize(scenario: MissionScenario):
	# Load relationships from mission setup
	_team_relationships = scenario.team_relationships.duplicate()

func are_allies(team_a: int, team_b: int) -> bool:
	return team_a == team_b || _team_relationships[team_a].allies.has(team_b)

func are_enemies(team_a: int, team_b: int) -> bool:
	return _team_relationships[team_a].enemies.has(team_b)

func get_hostile_teams(for_team: int) -> Array[int]:
	return _team_relationships[for_team].enemies
