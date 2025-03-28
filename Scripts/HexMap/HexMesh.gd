extends MeshInstance3D
class_name HexMesh

var outer_radius: float = HexGridManager.instance.outer_radius
var inner_radius: float = outer_radius * sqrt(3.0) / 2.0
var _cell: HexCell

func initialize(cell: HexCell):
	_cell = cell
	generate_mesh()

func generate_mesh():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Hex top surface (local space)
	var center = Vector3.ZERO
	var corners = []
	for i in 6:
		corners.append(get_corner(i))
	
	# Create triangle fan
	for i in 6:
		st.add_vertex(center)
		st.add_vertex(corners[i])
		st.add_vertex(corners[(i + 1) % 6])
	
	# Create bridges to neighbors
	for direction in 6:
		var neighbor = HexGridManager.instance.get_neighbor(_cell.q, _cell.r, direction)
		if neighbor:
			add_bridge(st, direction, neighbor)
	
	st.generate_normals()
	mesh = st.commit()

func add_bridge(st: SurfaceTool, direction: int, neighbor: HexCell):
	var current_corner1 = get_corner(direction)
	var current_corner2 = get_corner(direction + 1)
	
	# Get neighbor's opposite edge
	var neighbor_dir = (direction + 3) % 6
	var neighbor_corner1 = get_corner(neighbor_dir)
	var neighbor_corner2 = get_corner(neighbor_dir + 1)
	
	# Convert to world positions
	var world_current1 = to_global(current_corner1)
	var world_current2 = to_global(current_corner2)
	var world_neighbor1 = neighbor.to_global(neighbor_corner1)
	var world_neighbor2 = neighbor.to_global(neighbor_corner2)
	
	# Convert back to local space
	var local_neighbor1 = to_local(world_neighbor1)
	var local_neighbor2 = to_local(world_neighbor2)
	
	# Create quad
	st.add_vertex(current_corner1)
	st.add_vertex(current_corner2)
	st.add_vertex(local_neighbor2)
	
	st.add_vertex(current_corner1)
	st.add_vertex(local_neighbor2)
	st.add_vertex(local_neighbor1)

func get_corner(index: int) -> Vector3:
	var angle = deg_to_rad(60 * (index % 6) + 30)
	return Vector3(
		outer_radius * cos(angle),
		0,
		outer_radius * sin(angle)
	)
