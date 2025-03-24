extends CanvasLayer
class_name BattleUIController

@onready var unit_status := $UnitStatusPanel
@onready var bottom_action_panel := $BottomActionPanel
@onready var initiative := $InitiativeTracker
@onready var combat_log := $CombatLog

func _ready() -> void:
    # Connect to game systems
    UnitManager.instance.unit_selected.connect(_on_unit_selected)
    MovementSystem.instance.move_executed.connect(_on_movement)
    AttackSystem.instance.attack_resolved.connect(_on_attack)
    InitiativeSystem.instance.turn_order_updated.connect(_on_turn_order_updated)
    
    # Connect to player controller
    var player_controller = get_tree().get_first_node_in_group("player_controller")
    player_controller.action_move_requested.connect(_show_movement_ui)
    player_controller.action_attack_requested.connect(_show_attack_result)

func _on_unit_selected(unit: UnitHandler) -> void:
    unit_status.update_display(unit)
    if unit.controller.team_index == 0:
        bottom_action_panel.show_for_unit(unit)

func _show_movement_ui(unit: UnitHandler) -> void:
    unit_status.update_display(unit)
    bottom_action_panel.update_actions(unit)
    HexGridHighlights.instance.update_movement_range(unit)

func _show_attack_result(attacker: UnitHandler, target: UnitHandler, weapon: WeaponData) -> void:
    combat_log.add_entry(
        "{attacker} attacked {target} with {weapon}".format({
            "attacker": attacker.unit_data.name,
            "target": target.unit_data.name,
            "weapon": weapon.weapon_name
        }),
        "combat"
    )

func _on_player_movement_intent(unit: UnitHandler):
    var reachable = MovementSystem.instance.get_available_hexes(unit)
    HexGridHighlights.instance.update_movement_highlights(reachable)
    _toggle_action_buttons(true)

func _on_player_attack_intent(unit: UnitHandler):
    var weapons = unit.get_available_weapons()
    _show_weapon_selection(weapons)

func _on_action_selected(action_type: String):
    HexGridHighlights.clear_highlights()
    _toggle_action_buttons(false)


func _on_movement(unit: UnitHandler, path: Array) -> void:
    unit_status.update_display(unit)
    combat_log.add_entry("{unit} moved {distance}".format({
        "unit": unit.unit_data.name,
        "distance": path.size()
    }), "movement")

func _on_attack(result: AttackResult) -> void:
    var entry = "{attacker} -> {target}: {dmg} dmg".format({
        "attacker": result.attacker.unit_data.name,
        "target": result.target.unit_data.name,
        "dmg": result.total_damage
    })
    combat_log.add_entry(entry, "damage" if result.total_damage > 0 else "miss")

func _on_turn_order_updated(order: Array) -> void:
    initiative.update_turn_order(order)