# projectile_component: flies straight forward every frame and queues a hit on the first thing it strikes.
# the hit lands on the next tick resolve, like every other attack
class_name ProjectileComponent
extends Component

var speed: float = 400.0
var max_distance: float = 512.0
var hit_radius: float = 20.0

var direction: Vector2 = Vector2.RIGHT
var damage: float = 0.0
var push: float = 0.0
var stun_ticks: int = 0

var _travelled: float = 0.0

func _configure(data: EntityData) -> void:
	speed = data.projectile_speed
	max_distance = data.projectile_max_distance * entity.world.map.tile_size
	hit_radius = data.projectile_hit_radius

func launch(dir: Vector2, dmg: float, push_strength: float, stun: int) -> void:
	direction = dir.normalized()
	damage = dmg
	push = push_strength
	stun_ticks = stun
	entity.rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if entity == null or not entity.is_alive:
		return

	var step := speed * delta
	entity.global_position += direction * step
	_travelled += step

	var world := entity.world
	var tile := world.map.world_to_grid(entity.global_position)
	if tile != entity.current_grid_pos:
		world.entities.update_entity_grid_position(entity, tile)

	if world.map.is_solid(tile):
		_expire()
		return

	for other in world.entities.get_entities_in_radius(tile, 1.5):
		if _can_hit(other) and other.global_position.distance_to(entity.global_position) <= hit_radius:
			# push along the flight direction
			world.combat.queue_hit(other, damage, push, stun_ticks, other.global_position - direction)
			_expire()
			return

	if _travelled >= max_distance:
		_expire()

# hits hostile targets and neutral obstacles like boxes; flies past friends and mines
func _can_hit(other: Entity) -> bool:
	if other == entity or not other.is_alive or other.health == null:
		return false
	if entity.is_hostile_to(other):
		return other.targetable
	return other.team == Entity.Team.NEUTRAL and other.blocks_movement

func _expire() -> void:
	entity.world.entities.remove_entity(entity)
