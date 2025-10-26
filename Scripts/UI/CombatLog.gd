# UI/CombatLog.gd
extends ScrollContainer
class_name CombatLog

@export var log_container : VBoxContainer

func add_simple_entry(message: String, type: String = "info") -> void:
	var entry = RichTextLabel.new()
	entry.bbcode_enabled = true
	entry.fit_content_height = true
	
	var color = ""
	match type:
		"damage": color = "#FF4444"
		"heal": color = "#44FF44"
		"warning": color = "#FFFF44"
	
	entry.text = "[color=%s][%s] %s[/color]" % [
		color,
		Time.get_time_string_from_system(),
		message
	]
	
	log_container.add_child(entry)
	ensure_control_visible(entry)

func create_log_entry(action: String, result: Dictionary) -> Dictionary:
	var entry = {
		"timestamp": Time.get_time_dict_from_system(),
		"type": action,
		"message": "",
		"color": "#FFFFFF",
		"data": {}
	}
	
	match action:
		"move":
			entry["color"] = "#4CAF50"  # Green
			entry["message"] = _format_move_message(result)
			entry["data"] = {
				"unit": result.unit.uuid,
				"path_length": result.path.size(),
				"mp_used": result.mp_cost
			}
		
		"attack":
			entry["color"] = "#F44336"  # Red
			entry["message"] = _format_attack_message(result)
			entry["data"] = {
				"attacker": result.attacker.uuid,
				"target": result.target.uuid,
				"damage": result.total_damage,
				"critical": result.critical_hits > 0
			}
		
		"ability":
			entry["color"] = "#9C27B0"  # Purple
			entry["message"] = _format_ability_message(result)
			entry["data"] = {
				"ability": result.ability_id,
				"targets": result.targets.map(func(t): return t.uuid)
			}
		
		_:
			entry["message"] = "Unknown action occurred"
			entry["color"] = "#FFEB3B"  # Yellow
	
	return entry

func _format_move_message(result: Dictionary) -> String:
	return "[{time}] {unit} moved {count} hexes using {mp} MP".format({
		"time": _get_formatted_time(),
		"unit": result.unit.unit_data.name,
		"count": result.path.size(),
		"mp": result.mp_cost
	})

func _format_attack_message(result: Dictionary) -> String:
	var crit_text = " (Critical!)" if result.critical_hits > 0 else ""
	return "[{time}] {attacker} -> {target}: {damage} dmg{crit}".format({
		"time": _get_formatted_time(),
		"attacker": result.attacker.unit_data.name,
		"target": result.target.unit_data.name,
		"damage": result.total_damage,
		"crit": crit_text
	})

func _format_ability_message(result: Dictionary) -> String:
	return "[{time}] {unit} used {ability} on {targets}".format({
		"time": _get_formatted_time(),
		"unit": result.source.unit_data.name,
		"ability": result.ability_name,
		"targets": result.targets.map(func(t): return t.unit_data.name).join(", ")
	})

func _get_formatted_time() -> String:
	var time = Time.get_time_dict_from_system()
	return "{hour:02}:{minute:02}:{second:02}".format({
		"hour": time.hour,
		"minute": time.minute,
		"second": time.second
	})
	
func add_entry(entry: Dictionary) -> void:
	var rich_text = "[color={color}]{message}[/color]".format({
		"color": entry.color,
		"message": entry.message
	})
	
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content_height = true
	label.text = rich_text
	
	# Store raw data in metadata
	label.set_meta("log_data", entry.data)
	
	log_container.add_child(label)
	ensure_control_visible(label)        
