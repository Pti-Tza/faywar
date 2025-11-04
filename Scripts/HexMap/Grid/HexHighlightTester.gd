extends Node3D
class_name HexHighlightTester

@export var terrain: Terrain3D
@export var hex_grid_manager: HexGridManager
@export var decal_highlighter: HexDecalHighlighter
@export var test_mode: String = "circle"  # circle, random, path
@export var test_radius: int = 3
@export var test_cell_count: int = 15
@export var highlight_color: Color = Color.GREEN

var _test_cells: Array[HexCell] = []
@export var _current_test_index: int = 0
var _test_path: Array[HexCell] = []
var _test_timer: Timer

func _ready():
	# Setup test timer
	_test_timer = Timer.new()
	_test_timer.wait_time = 1.0
	_test_timer.timeout.connect(_run_next_test)
	add_child(_test_timer)
	
	# Initialize components
	assert(terrain != null, "Terrain reference missing")
	assert(hex_grid_manager != null, "HexGridManager reference missing")
	assert(decal_highlighter != null, "DecalHighlighter reference missing")
	
	# Start tests
	_prepare_test_data()
	_test_timer.start()

func _prepare_test_data():
	match test_mode:
		"circle":
			var center = hex_grid_manager.get_cell(10, 10)
			if center:
				_test_cells = hex_grid_manager.get_cells_in_range(center.axial_coords, test_radius)
		
		"random":
			var all_cells = hex_grid_manager.cells
			_test_cells = []
			for i in range(min(test_cell_count, all_cells.size())):
				_test_cells.append(all_cells.pick_random())
		
		"path":
			var start : HexCell = hex_grid_manager.get_cell(-5, -5)
			var end : HexCell = hex_grid_manager.get_cell(-8, -8)
			
			if not start or not end:
				push_error("Start or end cell not found!")
				return
				
			_test_path = hex_grid_manager.find_unit_path(UnitManager.instance.active_units[0], start.position, end.position)
			_test_cells = _test_path

func _run_next_test():
	match test_mode:
		"circle", "random":
			_run_standard_test()
		"path":
			_run_path_test()
		_:
			_run_standard_test()

func _run_standard_test():
	# Clear previous highlights
	decal_highlighter.clear_highlights()
	
	# Highlight current cell
	if _current_test_index < _test_cells.size():
		decal_highlighter.highlight_cells([_test_cells[_current_test_index]])
		
		# Debug output
		var cell = _test_cells[_current_test_index]
		print("Highlighting cell: (%d, %d) at position: %s" % [
			cell.q, cell.r, cell.position
		])
		
		_current_test_index += 1
	else:
		# Cycle back to start
		_current_test_index = 0
		print_test_summary()

func _run_path_test():
	decal_highlighter.clear_highlights()
	
	if _current_test_index < _test_path.size():
		# Highlight entire path up to current point
		var visible_path = _test_path.slice(0, _current_test_index + 1)
		decal_highlighter.highlight_cells(visible_path)
		
		print("Path step %d/%d: (%d, %d)" % [
			_current_test_index + 1, 
			_test_path.size(),
			_test_path[_current_test_index].q,
			_test_path[_current_test_index].r
		])
		
		_current_test_index += 1
	else:
		_current_test_index = 0
		print_test_summary()

func print_test_summary():
	print("\n--- TEST SUMMARY ---")
	print("Test Mode: ", test_mode)
	print("Cells Tested: ", _test_cells.size())
	print("Terrain: ", terrain.name)
	print("Decal Pool Size: ", decal_highlighter.max_active_decals)
	print("Active Decals: ", decal_highlighter._active_decals.size())
	print("----------------------\n")

func _input(event):
	# Manual control for debugging
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_run_next_test()
			KEY_C:
				decal_highlighter.clear_highlights()
				print("Cleared all highlights")
			KEY_R:
				_prepare_test_data()
				_current_test_index = 0
				print("Reset test data")
			KEY_1:
				test_mode = "circle"
				_prepare_test_data()
				print("Switched to circle test mode")
			KEY_2:
				test_mode = "random"
				_prepare_test_data()
				print("Switched to random test mode")
			KEY_3:
				test_mode = "path"
				_prepare_test_data()
				print("Switched to path test mode")
			KEY_UP:
				test_radius = min(test_radius + 1, 10)
				_prepare_test_data()
				print("Increased radius to: ", test_radius)
			KEY_DOWN:
				test_radius = max(test_radius - 1, 1)
				_prepare_test_data()
				print("Decreased radius to: ", test_radius)
