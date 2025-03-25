# UI/BottomActionPanel.gd
extends PanelContainer
class_name BottomActionPanel

## Custom signals
signal movement_initiated(unit: UnitHandler)
signal attack_initiated(unit: UnitHandler)

#signal ability_used(ability: AbilityResource)


@export var end_turn_btn : Button
@export var core_actions : Node
@export var abilities : Node
@export var system_commands : Node

# Preloaded resources
@export var action_button_scene : Node

# Action configuration
@export var CORE_ACTIONS = {
    "move": {"text": "Move", "icon": "res://Assets/Textures/UI/move_icon.png"},
    "attack": {"text": "Attack", "icon": "res://Assets/Textures/UI/attack_icon.png"},
    "brace": {"text": "Brace", "icon": "res://Assets/Textures/UI/brace_icon.png"}
}

var current_unit: UnitHandler

func show_for_unit(unit: UnitHandler) -> void:
    current_unit = unit
    visible = true
    _clear_actions()
    _populate_core_actions()
    #_populate_abilities()
    #_populate_system_commands()

func _clear_actions() -> void:
    for child in core_actions.get_children():
        child.queue_free()
    for child in abilities.get_children():
        child.queue_free()
    for child in get_children():
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

#func _populate_abilities() -> void:
#    if current_unit.abilities.is_empty():
#        var label = Label.new()
#        label.text = "No Abilities Available"
#        return
#    
#        var btn = action_button_scene.instantiate()
#        btn.configure(
#            ability.display_name,
#            load(ability.icon_path),
#            ability.can_activate(current_unit)
#        )
#        btn.connect("pressed", Callable(self, "_on_ability_selected").bind(ability))
#        abilities.add_child(btn)

#func _populate_system_commands() -> void:
    

func _is_action_available(action: String) -> bool:
    match action:
        "move": return current_unit.remaining_mp > 0
        "attack": return current_unit.can_attack
        "brace": return current_unit.can_brace
    return false

func _on_core_action_selected(action: String) -> void:
    match action:
        "move":
            HexGridHighlights.instance.show_movement_range(PlayerController.instance.current_unit)
            PlayerController.instance.prepare_movement()
        "attack":
            HexGridHighlights.instance.show_attack_range(PlayerController.instance.current_unit)
        "brace":
            current_unit.activate_brace()
            PlayerController.instance.end_turn()
            hide()
#abilities not implemented yet
#func _on_ability_selected(ability: AbilityResource) -> void:
#    ability.activate(current_unit)
#    Events.emit_signal("ability_used", ability)
#    hide()

