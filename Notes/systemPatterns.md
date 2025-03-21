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
 

# Damage Propagation Path
```mermaid
sequenceDiagram
    Attacker->>AttackSystem: resolve_attack()
    AttackSystem->>WeaponHandler: resolve()
    WeaponHandler->>UnitHandler: get_armor()
    UnitHandler->>SectionHandler: apply_damage()
    SectionHandler->>ComponentHandler: check_destroyed()
    ComponentHandler-->>AttackSystem: result     