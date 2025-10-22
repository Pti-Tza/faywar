# HexGridHighlights.gd
class_name HexGridHighlights
extends Node3D

static var instance : HexGridHighlights
## Highlight types with associated colors
enum HighlightType {
	MOVE_RANGE,      # Light blue
	ATTACK_RANGE,    # Red outline
	VALID_TARGET,    # Solid red
	ABILITY_RANGE,   # Purple
	HOVER            # Yellow
}

# Configuration
@export var highlight_materials: Array[Material] = [
	preload("res://Materials/move_range.tres"),     # Index 0 = MOVE_RANGE
	preload("res://Materials/attack_range.tres"),    # Index 1 = ATTACK_RANGE
	preload("res://Materials/valid_target.tres"),    # Index 2 = VALID_TARGET
	preload("res://Materials/ability_range.tres"),   # Index 3 = ABILITY_RANGE
	preload("res://Materials/hover.tres")            # Index 4 = HOVER
]

# References
@onready var hex_grid: HexGridManager = %HexGridManager
@onready var multi_mesh: MultiMeshInstance3D = $MultiMeshInstance3D

var current_highlights := {}

func _init():
	instance = self

func _ready() -> void:
	assert(highlight_materials.size() == HighlightType.size(),
		"Highlight materials array size must match HighlightType enum count")

	_initialize_multimesh()
	clear_all_highlights()

func _initialize_multimesh() -> void:
	# Create multimesh based on grid size
	var mm = MultiMesh.new()
	mm.mesh = preload("res://Meshes/hex_highlight.mesh")
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = hex_grid.get_all_cells().size()
	multi_mesh.multimesh = mm
	
	for i in hex_grid.get_all_cells().size():
		var cell = hex_grid.get_all_cells()[i]
		var transform = Transform3D().translated(hex_grid.axial_to_world(cell.q, cell.r))
		mm.set_instance_transform(i, transform)
		mm.set_instance_visibility(i, false)  # Direct MultiMesh reference

func update_movement_highlights(unit: Unit) -> void:
	var reachable = MovementSystem.instance.get_reachable_hexes(unit)
	_set_highlight_type(reachable, HighlightType.MOVE_RANGE)

func update_attack_highlights(unit: Unit, weapon: WeaponData) -> void:
	var attack_range = AttackSystem.instance.get_attack_range(unit, weapon)
	_set_highlight_type(attack_range, HighlightType.ATTACK_RANGE)

#ability system not implemented
#func update_ability_highlights(unit: Unit, ability: AbilityResource) -> void:
 #   var ability_range = AbilitySystem.instance.get_ability_range(unit, ability)
  #  _set_highlight_type(ability_range, HighlightType.ABILITY_RANGE)

func set_hover_highlight(cell: HexCell) -> void:
	clear_highlight_type(HighlightType.HOVER)
	_set_highlight_type([cell], HighlightType.HOVER)

func clear_highlight_type(type: HighlightType) -> void:
	for cell in current_highlights.get(type, []):
		var index = hex_grid.get_cell_index(cell)
		multi_mesh.multimesh.set_instance_visibility(index, false)
	current_highlights.erase(type)

func clear_all_highlights() -> void:
	for type in HighlightType.values():
		clear_highlight_type(type)

func _set_highlight_type(cells: Array[HexCell], type: HighlightType) -> void:
	if cells.is_empty():
		return
	
	# Validate cell indices
	var valid_cells := cells.filter(func(c): return hex_grid.has_cell(c))
	
	# Clear previous highlights
	clear_highlight_type(type)
	
	# Set new highlights
	for cell in valid_cells:
		var index = hex_grid.get_cell_index(cell)
		if index >= 0 && index < multi_mesh.multimesh.instance_count:
			multi_mesh.multimesh.set_instance_visibility(index, true)
			multi_mesh.multimesh.set_instance_color(
				index, 
				_get_highlight_color(type)
			)
	
	current_highlights[type] = valid_cells

func _get_highlight_color(type: HighlightType) -> Color:
	match type:
		HighlightType.MOVE_RANGE: return Color(0.2, 0.5, 1.0, 0.3)
		HighlightType.ATTACK_RANGE: return Color(1.0, 0.1, 0.1, 0.2)
		HighlightType.VALID_TARGET: return Color(1.0, 0.3, 0.3, 0.6)
		HighlightType.ABILITY_RANGE: return Color(0.7, 0.2, 1.0, 0.4)
		HighlightType.HOVER: return Color(1.0, 0.8, 0.2, 0.4)
		_: return Color.TRANSPARENT
