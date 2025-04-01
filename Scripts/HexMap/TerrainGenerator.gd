@tool
 #terrain_generator.gd
extends MeshInstance3D
class_name TerrainGenerator

@export var regenerate: bool = false:
	set(v):
		generate_terrain()

@export var size: int = 100
@export var height_scale: float = 50.0
@export var noise_scale: float = 0.1
@export var noise_seed: int = 0

func _ready() -> void:
	generate_terrain()
	
func generate_terrain():
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(size, size)
	plane_mesh.subdivide_depth = size / 2
	plane_mesh.subdivide_width = size / 2
	
	var noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = noise_scale
	
	var surface_tool = SurfaceTool.new()
	surface_tool.create_from(plane_mesh, 0)
	
	var data = surface_tool.commit()
	var arr = data.surface_get_arrays(0)
	var vertices = arr[ArrayMesh.ARRAY_VERTEX] as PackedVector3Array
	
	for i in vertices.size():
		var vertex = vertices[i]
		vertex.y = noise.get_noise_2d(vertex.x, vertex.z) * height_scale
		vertices[i] = vertex
	
	arr[ArrayMesh.ARRAY_VERTEX] = vertices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	self.mesh = mesh
	_generate_collision()

func _generate_collision():
	# Remove old collision if exists
	for child in get_children():
		if child is StaticBody3D:
			remove_child(child)
			child.queue_free()

	# Create new collision body
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	
	# Create trimesh collision shape from mesh
	if mesh.get_surface_count() > 0:
		var shape = mesh.create_trimesh_shape()
		if shape:
			collision_shape.shape = shape
			static_body.add_child(collision_shape)
			add_child(static_body)
		else:
			push_error("Failed to create collision shape")
	else:
		push_error("No mesh surfaces available for collision")
