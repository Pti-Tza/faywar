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
	moves_label.text = "MP: %d" % [unit.walk_mp]
	
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
	heat_gauge.tint_progress = Color.RED.lerp(
		Color.YELLOW,
		unit.heat_system.current_heat / unit.heat_system.max_heat
	)
