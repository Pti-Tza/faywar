# HexCoord.gd
class_name HexCoord
extends RefCounted

var q: int
var r: int

func _init(q_pos: int, r_pos: int):
    q = q_pos
    r = r_pos

func _to_string() -> String:
    return "HexCoord(%d, %d)" % [q, r]

func _hash() -> int:
    return q << 16 | (r & 0xFFFF)

func equals(other: HexCoord) -> bool:
    return q == other.q && r == other.r

static func from_vector(vec: Vector2i) -> HexCoord:
    return HexCoord.new(vec.x, vec.y)