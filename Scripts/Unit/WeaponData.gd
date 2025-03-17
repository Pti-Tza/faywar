
extends ComponentData
class_name WeaponData

enum WeaponType {
    BALLISTIC,
    ENERGY,
    MISSILE
}

@export_category("Base Properties")

@export var weapon_type: WeaponType = WeaponType.BALLISTIC
@export var damage: float = 10.0
@export var heat_generation: float = 4.0
@export_range(0, 100) var base_accuracy: float = 0.7  # 70% base hit chance
@export var cooldown_time: float = 3.0  # Seconds between shots
@export var effective_range: Vector2 = Vector2(100, 500)  # Min/max optimal range
@export var projectile_per_attack : int = 1

@export_category("Ammunition")
@export var uses_ammo: bool = false
@export var max_ammo: int = 10
@export var current_ammo: int = 10


@export_category("Visuals")
@export var projectile_scene: PackedScene
@export var fire_sound: AudioStream
#@export var fire_effect: GPUParticles2D