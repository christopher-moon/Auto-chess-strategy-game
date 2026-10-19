# entity_data: this is the blueprint for entity resource files, which are used by the spawner to build + initialize specific entities into the game
class_name EntityData
extends Resource

# the base classification for the entity (actor, obstacle, trigger)
# actor = unit, obstacle = wall/turret, trigger = hazard/projectile
enum EntityShell {ACTOR, OBSTACLE, TRIGGER}

@export_group("Setup")
@export var entity_name: String = "New Entity"
@export var shell_type: EntityShell = EntityShell.ACTOR
@export var sprite_texture: Texture2D

@export_group("Pathfinding")
@export var pathing_weight: float = 1.0

@export_group("Components")
@export var has_health: bool = false
@export var has_movement: bool = false
@export var has_combat: bool = false

@export_group("Stats")
# health exclusive stats
@export var max_health: float = 10.0
# movement exclusive stats
@export var move_speed: float = 100.0
# combat exclusive stats
@export var damage: float = 2.0
@export var attack_speed: float = 1.0
@export var attack_range: float = 1.0
@export var threat_range: float = 8.0
