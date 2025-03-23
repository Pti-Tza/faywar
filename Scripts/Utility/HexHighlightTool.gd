# HexHighlightTool.gd
class_name HexHighlightTool
extends MeshInstance3D

@export var hex_size: float = 1.0
@export var border_thickness: float = 0.1

func _ready():
	generate_hex_mesh()

func generate_hex_mesh():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Outer vertices
	var outer_vertices = []
	for i in 6:
		var angle = deg_to_rad(60 * i - 30)
		outer_vertices.append(Vector3(
			hex_size * cos(angle),
			0,
			hex_size * sin(angle)
		))
	
	# Inner vertices (for border effect)
	var inner_vertices = []
	for v in outer_vertices:
		inner_vertices.append(v * (1 - border_thickness))
	
	# Create triangles
	for i in 6:
		var next_i = (i + 1) % 6
		
		# Outer ring
		st.add_vertex(outer_vertices[i])
		st.add_vertex(outer_vertices[next_i])
		st.add_vertex(inner_vertices[i])
		
		st.add_vertex(inner_vertices[i])
		st.add_vertex(outer_vertices[next_i])
		st.add_vertex(inner_vertices[next_i])
	
	# Generate mesh
	mesh = st.commit()
	self.mesh = mesh
	ResourceSaver.save(mesh, "res://Meshes/hex_highlight.mesh")
