extends Node
class_name test_battle_starter

@export var unit1 : PackedScene 

func _ready():
	await HexGridManager.instance.grid_initialized
	UnitManager.instance.spawn_unit(unit1, Vector3i(5,15,5), 0)
	BattleController.instance.start_battle()
