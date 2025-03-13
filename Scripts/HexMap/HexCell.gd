extends Node3D
class_name HexCell


var q: int
var r: int
var elevation: int = 0
var terrain_type: String = "plains"
var unit: Node3D = null
var hexPosition: Vector3:
    get: return global_position
    set(value): global_position = value

func _init(axial_q: int, axial_r: int):
    q = axial_q
    r = axial_r
    name = "HexCell(%d,%d)" % [q, r]

func is_blocked() -> bool:
    return unit != null || terrain_type == "impassable"