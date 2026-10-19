# entity_data: this is the blueprint for entity resource files, which are used by the spawner to build + initialize specific entities into the game
class_name EntityData
extends Resource

# the base classification for the entity (actor, obstacle, trigger)
# actor = unit, obstacle = wall/turret/spawner, trigger = hazard/projectile
enum EntityShell {ACTOR, OBSTACLE, TRIGGER}

# how a combat component deals its damage
# melee = direct hit, projectile = fires a projectile entity, explode = area damage around itself, then dies
enum AttackType {MELEE, PROJECTILE, EXPLODE}

@export_group("Setup")
@export var entity_name: String = "New Entity"
@export var shell_type: EntityShell = EntityShell.ACTOR
@export var sprite_texture: Texture2D
@export var sprite_scale: float = 1.0
@export var tint_by_team: bool = true
# the AI that drives this entity. leave empty on units to use the spawner's per-team default
@export var behavior: Behavior

@export_group("Physical")
# heavier units speed up more slowly, have a lower top speed, and win shoving matches
@export var mass: float = 1.0
# collision circle radius in pixels (a tile is 64)
@export var body_radius: float = 14.0
# A* cost multiplier for the tile this entity stands on (1 = normal ground)
@export var pathing_weight: float = 1.0
# units can't walk onto this entity's tile (boxes, turrets). paths may still go through it, at its pathing_weight
@export var blocks_movement: bool = false
@export var blocks_line_of_sight: bool = false
# whether enemies will pick this entity as a target
@export var targetable: bool = true

@export_group("Components")
@export var has_health: bool = false
@export var has_movement: bool = false
@export var has_combat: bool = false
@export var has_spawner: bool = false
@export var has_projectile: bool = false

@export_group("Health")
@export var max_health: float = 10.0

@export_group("Movement")
# top speed in pixels per second at mass 1. actual top speed = move_speed / sqrt(mass)
@export var move_speed: float = 100.0
# pushing force in pixels/second² at mass 1. actual acceleration = move_force / mass
@export var move_force: float = 600.0
# how quickly the unit slows down when it isn't pushing, in pixels/second²
@export var friction: float = 800.0

@export_group("Combat")
@export var attack_type: AttackType = AttackType.MELEE
@export var damage: float = 2.0
# attacks per second
@export var attack_speed: float = 1.0
# ranges are measured in tiles
@export var attack_range: float = 1.0
@export var threat_range: float = 8.0
@export var requires_line_of_sight: bool = true
# tiles the target is pushed away on hit (never into walls or blockers)
@export var knockback: int = 0
# seconds
@export var stun_duration: float = 0.0
# explode only: radius in tiles
@export var aoe_radius: float = 1.5
# projectile only: entity name of the projectile to fire
@export var projectile_name: String = "Arrow"

@export_group("Spawner")
@export var spawn_entity_name: String = "Melee"
@export var spawn_max_count: int = 3
# seconds between spawns
@export var spawn_interval: float = 4.0

@export_group("Projectile")
# pixels per second
@export var projectile_speed: float = 400.0
# tiles travelled before the projectile fizzles out
@export var projectile_max_distance: float = 8.0
# pixels
@export var projectile_hit_radius: float = 20.0
