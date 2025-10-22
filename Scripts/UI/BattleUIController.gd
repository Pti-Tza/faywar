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

    # Connect UI elements
    bottom_action_panel.action_selected.connect(_on_action_selected)
    
    # Connect game systems
    BattleController.instance.action_validated.connect(_on_action_validated)
    BattleController.instance.action_executed.connect(_on_action_executed)

func _on_unit_selected(unit: Unit) -> void:
    unit_status.update_display(unit)
    if unit.controller.team_index == 0:
        bottom_action_panel.show_for_unit(unit)

func _show_movement_ui(unit: Unit) -> void:
    unit_status.update_display(unit)
    bottom_action_panel.update_actions(unit)
    HexGridHighlights.instance.update_movement_range(unit)

func _show_attack_result(attacker: Unit, target: Unit, weapon: WeaponData) -> void:
    combat_log.add_entry(
        "{attacker} attacked {target} with {weapon}".format({
            "attacker": attacker.unit_data.name,
            "target": target.unit_data.name,
            "weapon": weapon.weapon_name
        }),
        "combat"
    )


func _on_action_selected(action_type: String):
    match action_type:
        "move":
            highlight_movement()
        "attack": 
            highlight_attack()
        _:
            HexGridHighlights.instance.clear_all_highlights()

func highlight_movement():
    var unit = BattleController.instance.active_unit
    var reachable = BattleController.instance.get_movement_range(unit)
    HexGridHighlights.instance.update_movement_highlights(reachable)

func highlight_attack():
    var unit = BattleController.instance.active_unit
    var weapons = BattleController.instance.get_available_weapons(unit)
    
    for weapon in weapons:
     HexGridHighlights.instance.update_attack_highlights(unit, weapon)

func _on_action_validated(action: String, valid: bool):
    if valid:
        bottom_action_panel.disable_action(action)
    else:
        push_error("Invalid action")

func _on_action_executed(action: String, result: Dictionary):
    combat_log.create_log_entry(action, result)
    HexGridHighlights.instance.clear_all_highlights()
    bottom_action_panel.reset_actions()



func _on_movement(unit: Unit, path: Array) -> void:
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