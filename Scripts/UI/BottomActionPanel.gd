# UI/BottomActionPanel.gd
extends PanelContainer

@onready var core_actions := $Margin/HBox/CoreActions
@onready var abilities := $Margin/HBox/Abilities
@onready var system_commands := $Margin/HBox/SystemCommands

# Preloaded resources
@onready var action_button_scene = preload("res://UI/ActionButton.tscn")

# Action configuration
const CORE_ACTIONS = {
    "move": {"text": "Move", "icon": "res://Assets/move_icon.png"},
    "attack": {"text": "Attack", "icon": "res://Assets/attack_icon.png"},
    "brace": {"text": "Brace", "icon": "res://Assets/brace_icon.png"}
}

var current_unit: UnitHandler

func show_for_unit(unit: UnitHandler) -> void:
    current_unit = unit
    visible = true
    _clear_actions()
    _populate_core_actions()
    _populate_abilities()
    _populate_system_commands()

func _clear_actions() -> void:
    for child in core_actions.get_children():
        child.queue_free()
    for child in abilities.get_children():
        child.queue_free()
    for child in system_commands.get_children():
        child.queue_free()

func _populate_core_actions() -> void:
    for action_key in CORE_ACTIONS:
        var btn = action_button_scene.instantiate()
        btn.configure(
            CORE_ACTIONS[action_key].text,
            load(CORE_ACTIONS[action_key].icon),
            _is_action_available(action_key)
        )
        btn.connect("pressed", Callable(self, "_on_core_action_selected").bind(action_key))
        core_actions.add_child(btn)

func _populate_abilities() -> void:
    if current_unit.abilities.is_empty():
        var label = Label.new()
        label.text = "No Abilities Available"
        abilities.add_child(label)
        return
    
    for ability in current_unit.abilities:
        var btn = action_button_scene.instantiate()
        btn.configure(
            ability.display_name,
            load(ability.icon_path),
            ability.can_activate(current_unit)
        )
        btn.connect("pressed", Callable(self, "_on_ability_selected").bind(ability))
        abilities.add_child(btn)

func _populate_system_commands() -> void:
    var end_turn_btn = Button.new()
    end_turn_btn.text = "End Turn"
    end_turn_btn.icon = load("res://Assets/end_turn_icon.png")
    end_turn_btn.connect("pressed", Callable(Events.emit_signal).bind("turn_end_requested"))
    system_commands.add_child(end_turn_btn)

func _is_action_available(action: String) -> bool:
    match action:
        "move": return current_unit.remaining_mp > 0
        "attack": return current_unit.can_attack
        "brace": return current_unit.can_brace
    return false

func _on_core_action_selected(action: String) -> void:
    match action:
        "move":
            Events.emit_signal("movement_initiated", current_unit)
            hide()
        "attack":
            Events.emit_signal("attack_initiated", current_unit)
        "brace":
            current_unit.activate_brace()
            hide()

func _on_ability_selected(ability: AbilityResource) -> void:
    ability.activate(current_unit)
    Events.emit_signal("ability_used", ability)
    hide()