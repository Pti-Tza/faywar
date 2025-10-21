## Architectural Overview

 ```mermaid
    flowchart TD
    BattleController --> InitiativeSystem
    BattleController --> HexGridManager
    BattleController --> UnitManager
    
    UnitHandler --> SectionHandler
    SectionHandler --> ComponentHandler
    
    AIStrategy <|-- BerserkerStrategy
    AIStrategy <|-- SniperStrategy

## Attack System Architecture
```mermaid
flowchart TD
    AttackSystem --> StandardAttackHandler
    AttackSystem --> ClusterAttackHandler

    
    StandardAttackHandler --> SingleHit[Single Location Damage]
    ClusterAttackHandler --> MultiHit[Multiple Locations]
 

## Damage Propagation Path
```mermaid
sequenceDiagram
    Attacker->>AttackSystem: resolve_attack()
    AttackSystem->>WeaponHandler: resolve()
    WeaponHandler->>UnitHandler: get_armor()
    UnitHandler->>SectionHandler: apply_damage()
    SectionHandler->>ComponentHandler: check_destroyed()
    ComponentHandler-->>AttackSystem: result     



## Battle Architecture

 flowchart TD
    BC[BattleController] -->|Manages| MS[MovementSystem]
    BC -->|Manages| AS[AttackSystem]
    
    PC[PlayerController] -->|Emits Actions| BC
    AI[AIController] -->|Emits Actions| BC
    
    BC -->|Executes Via| MS
    BC -->|Executes Via| AS

    style BC fill:#f9f,stroke:#333
    style PC fill:#ccf,stroke:#333
    style AI fill:#cfc,stroke:#333
    style MS fill:#fdd,stroke:#333
    style AS fill:#dfd,stroke:#333



gdscript
Copy
# PlayerController.gd
func execute_move(path: Array[HexCell]):
    action_selected.emit("move", {"path": path})

# BasicAIController.gd 
func calculate_and_emit_move():
    var path = find_best_path()
    action_selected.emit("move", {"path": path})
BattleController Action Handling

gdscript
Copy
# BattleController.gd
func _on_controller_action(action: String, details: Dictionary):
    if not _validate_action_ownership(sender):
        return
    
    match action:
        "move": _execute_validated_move(details)
        "attack": _execute_validated_attack(details)

func _execute_validated_move(details):
    if movement_system.validate(_active_unit, details.path):
        movement_system.execute(_active_unit, details.path)
    else:
        handle_invalid_action()   

## Updated Action Handling Flow
```mermaid
flowchart TD
    UI[BottomActionPanel] -->|action_selected| BUI[BattleUIController]
    BUI -->|action_intent| PC[PlayerController]
    PC -->|action_request| BC[BattleController]
    BC -->|validate_turn_ownership| VAL[Validation Layer]
    VAL -->|UUID Check| UN[Unit Registry]
    BC -->|execute_action| SYS[Game Systems]
    SYS -->|result| BUI
    BUI -->|update| LOG[CombatLog]
    BUI -->|highlight| GRID[HexGrid]        




