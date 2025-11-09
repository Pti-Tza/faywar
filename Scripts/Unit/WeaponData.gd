
extends ComponentData
class_name WeaponData

enum AttackPattern { SINGLE, CLUSTER, CONCENTRATED }
enum WeaponType { BALLISTIC, ENERGY, MISSILE, ARTILLERY }


@export_category("Core Properties")
@export var weapon_name: String = "Unnamed Weapon"
@export var weapon_type: WeaponType = WeaponType.BALLISTIC
@export var attack_pattern: AttackPattern = AttackPattern.SINGLE
@export var damage: float = 5.0
@export var heat_generation: float = 2.0

@export_category("Cluster Weapons")
@export var cluster_size: int = 1
@export var cluster_spread: float = 0.0
@export var cluster_table: Array[int] = []

@export_category("Ammunition")
@export var uses_ammo: bool = false
@export var max_ammo: int = 0
@export var ammo_explosion_risk: float = 0.1

@export_category("Advanced")
@export var critical_hit_bonus: float = 0.1
@export var minimum_range: int = 0
@export var optimal_range: int = 10
@export var maximum_range: int = 20
@export var projectile_per_attack : int = 1

# Current ammo tracking
var current_ammo: int:
	get:
		if max_ammo > 0:
			# If max_ammo is defined, use current ammo (default to max if not set)
			if not has_meta("current_ammo_value"):
				set_meta("current_ammo_value", max_ammo)
			return get_meta("current_ammo_value")
		else:
			return -1  # Indicate unlimited ammo
	set(value):
		if max_ammo > 0:
			var clamped_value = clamp(value, 0, max_ammo)
			set_meta("current_ammo_value", clamped_value)
