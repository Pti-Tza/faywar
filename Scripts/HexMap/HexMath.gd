# hex_math.gd
class_name HexMath
extends Node
## 3D Hexagonal coordinate system utilities
## Implements axial + elevation coordinates with cube constraint (q + r + s = 0)

static func get_max_elevation_change(mobility: int) -> int:
	match mobility:
		Unit.MobilityType.BIPEDAL: return 2
		Unit.MobilityType.WHEELED: return 1
		Unit.MobilityType.TRACKED: return 1
		Unit.MobilityType.HOVER: return 3
		Unit.MobilityType.AERIAL: return 999
		_: return 0

static func get_elevation_cost(mobility: int, elevation_diff: int) -> float:
	match mobility:
		Unit.MobilityType.BIPEDAL:
			return _bipedal_elevation_cost(elevation_diff)
		Unit.MobilityType.WHEELED:
			return _wheeled_elevation_cost(elevation_diff)
		Unit.MobilityType.TRACKED:
			return abs(elevation_diff) * 0.7
		Unit.MobilityType.HOVER, Unit.MobilityType.AERIAL:
			return 0.0
		_:
			return 0.0

static func _bipedal_elevation_cost(diff: int) -> float:
	if diff > 0: return diff * 1.0    # 1 MP per level climbed
	if diff < 0: return abs(diff) * 0.5  # 0.5 MP per level descended
	return 0.0

static func _wheeled_elevation_cost(diff: int) -> float:
	if diff > 0: return diff * 2.0    # 1 MP per level climbed
	if diff < 0: return abs(diff) * 0.5  # 0.5 MP per level descended
	return 0.0    

static func get_water_movement_multiplier(mobility: int) -> float:
	match mobility:
		Unit.MobilityType.HOVER: return 0.8
		Unit.MobilityType.AERIAL: return 1.0
		_: return 2.0  # Penalty for non-aquatic units

const SQRT3 = sqrt(3)
const HEX_SIZE = Vector2(2.0, 1.732)  # Width/Height ratios

static func axial_to_world(hex: Vector3, cell_size: float) -> Vector3:
	var x = cell_size * (SQRT3 * hex.x + SQRT3/2 * hex.z)
	var z = cell_size * (3.0/2 * hex.z)
	return Vector3(x, hex.y * cell_size, z)

static func world_to_axial(pos: Vector3, cell_size: float) -> Vector3:
	var q = (SQRT3/3 * pos.x - 1.0/3 * pos.z) / cell_size
	var r = (2.0/3 * pos.z) / cell_size
	return cube_to_axial(Vector3(q, -q-r, r))

static func cube_to_axial(cube: Vector3) -> Vector3:
	return Vector3(cube.x, cube.y, cube.z)

static func get_neighbors(hex: Vector3) -> Array[Vector3]:
	return [
		hex + Vector3(1, -1, 0), hex + Vector3(1, 0, -1), hex + Vector3(0, 1, -1),
		hex + Vector3(-1, 1, 0), hex + Vector3(-1, 0, 1), hex + Vector3(0, -1, 1)
	]
	
static func is_valid_axial(q: int, r: int, grid_radius:int) -> bool:
	# Battletech map validation rules
	var s = -q - r
	return abs(q) <= grid_radius && abs(r) <= grid_radius && abs(s) <= grid_radius	
