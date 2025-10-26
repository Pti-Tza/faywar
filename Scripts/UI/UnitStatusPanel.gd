# UI/UnitStatusPanel.gd
extends Panel
class_name UnitStatusPanel

@onready var armor_bar := $VBox/ArmorBar
@onready var structure_bar := $VBox/StructureBar
@onready var heat_gauge := $VBox/HeatGauge
@onready var unit_name := $VBox/NameLabel
@onready var moves_label := $VBox/MovesLabel

func update_display(unit: Unit) -> void:
	# Core stats
	unit_name.text = unit.unit_data.display_name
	moves_label.text = "MP: %d/%d" % [unit.remaining_mp, unit.stats.movement_range]
	
	# Section status
	var current_section = unit.get_selected_section()
	armor_bar.value = current_section.current_armor
	armor_bar.max_value = current_section.section_data.max_armor
	
	structure_bar.value = current_section.current_structure
	structure_bar.max_value = current_section.section_data.max_structure
	
	# Heat system
	heat_gauge.value = unit.heat_system.current_heat
	heat_gauge.max_value = unit.heat_system.max_heat
	heat_gauge.tint_progress = Color.RED.lerp(
		Color.YELLOW, 
		unit.heat_system.current_heat / unit.heat_system.max_heat
	)
