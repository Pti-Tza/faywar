# UI/CombatLog.gd
extends ScrollContainer
class_name CombatLog

@onready var log_container := $VBox

func add_entry(message: String, type: String = "info") -> void:
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