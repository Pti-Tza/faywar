class_name AttackResult

var valid: bool = true
var hits: Array[HitData] = []
var total_damage: float = 0.0
var heat_generated: float = 0.0
var ammo_used: int = 0
var critical_hits: int = 0

func _init():
    for hit in hits:
        if hit.critical:
            critical_hits += 1