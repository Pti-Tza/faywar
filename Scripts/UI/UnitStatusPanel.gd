# UI/UnitStatusPanel.gd
extends Panel
class_name UnitStatusPanel

@export var armor_bar: ProgressBar
@export var structure_bar: ProgressBar
@export var heat_gauge: ProgressBar
@export var unit_name: Label
@export var moves_label: Label

func update_display(unit: Unit) -> void:
	# Core stats
	unit_name.text = unit.unit_name
	moves_label.text = "MP: %d/%d" % [unit.get_remaining_mp(), unit.get_max_mp()]
	
	# Total armor and structure values
	var total_current_armor = unit.get_total_armor()
	var total_max_armor = unit.sections.reduce(func(acc, s): return acc + s.max_armor, 0)
	var total_current_structure = unit.get_total_structure()
	var total_max_structure = unit.sections.reduce(func(acc, s): return acc + s.max_structure, 0)
	
	armor_bar.value = total_current_armor
	armor_bar.max_value = total_max_armor
	
	structure_bar.value = total_current_structure
	structure_bar.max_value = total_max_structure
	
	# Heat system
	heat_gauge.value = unit.heat_system.current_heat
	heat_gauge.max_value = unit.heat_system.max_heat
	var heat_ratio = unit.heat_system.current_heat / unit.heat_system.max_heat
	var heat_color = Color.RED.lerp(Color.YELLOW, heat_ratio)
	
	# Create a StyleBoxFlat for the heat gauge fill
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = heat_color
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	
	# Apply the style to the heat gauge
	heat_gauge.add_theme_stylebox_override("fill", fill_style)
