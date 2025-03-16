# hex_math.gd
class_name HexMath
extends Node
## 3D Hexagonal coordinate system utilities
## Implements axial + elevation coordinates with cube constraint (q + r + s = 0)

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