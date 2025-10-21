
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
