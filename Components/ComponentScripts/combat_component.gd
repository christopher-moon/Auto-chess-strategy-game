# combat_component: entities with this component can deal damage to other entities.
# it remembers the current target, which is held until the target dies, is obscured, or a stun resets it
class_name CombatComponent
extends Component

var attack_type: EntityData.AttackType = EntityData.AttackType.MELEE
var damage: float = 2.0
var attack_range: float = 1.0
var threat_range: float = 8.0
var requires_line_of_sight: bool = true
var knockback: int = 0
var stun_ticks: int = 0
var aoe_radius: float = 1.5
var projectile_name: String = ""
# ticks between attacks, from attack_speed
var cooldown_ticks: int = 5

var target: Entity = null
# explode only: the hostile unit that stepped onto our tile
var triggered_by: Entity = null

var _cooldown_remaining: int = 0

func _configure(data: EntityData) -> void:
	attack_type = data.attack_type
	damage = data.damage
	attack_range = data.attack_range
	threat_range = data.threat_range
	requires_line_of_sight = data.requires_line_of_sight
	knockback = data.knockback
	stun_ticks = entity.world.seconds_to_ticks(data.stun_duration) if data.stun_duration > 0.0 else 0
	aoe_radius = data.aoe_radius
	projectile_name = data.projectile_name
	cooldown_ticks = entity.world.seconds_to_ticks(1.0 / maxf(data.attack_speed, 0.01))

# --- targeting ---

func has_valid_target() -> bool:
	return target != null and is_instance_valid(target) and target.is_alive

func clear_target() -> void:
	target = null

func can_see(other: Entity) -> bool:
	return can_see_from(entity.current_grid_pos, other)

func can_see_from(tile: Vector2i, other: Entity) -> bool:
	return not requires_line_of_sight or entity.world.has_line_of_sight(tile, other.current_grid_pos)

func can_attack(other: Entity) -> bool:
	return can_attack_from(entity.current_grid_pos, other)

func can_attack_from(tile: Vector2i, other: Entity) -> bool:
	return Vector2(tile).distance_to(Vector2(other.current_grid_pos)) <= attack_range and can_see_from(tile, other)

# --- attacking ---

func tick_cooldown() -> void:
	if _cooldown_remaining > 0:
		_cooldown_remaining -= 1

func is_ready() -> bool:
	return _cooldown_remaining <= 0

# attacks never apply damage directly: hits are queued and land together when the tick resolves
func attack(other: Entity) -> void:
	_cooldown_remaining = cooldown_ticks
	var world := entity.world
	match attack_type:
		EntityData.AttackType.MELEE:
			world.combat.queue_hit(other, damage, knockback, stun_ticks, entity.current_grid_pos)
		EntityData.AttackType.PROJECTILE:
			world.spawner.spawn_projectile(projectile_name, entity, other)
		EntityData.AttackType.EXPLODE:
			world.combat.queue_explosion(entity, entity.current_grid_pos, aoe_radius, damage, knockback, stun_ticks)
			world.combat.queue_kill(entity)

# explode only: called by the EntityManager when something walks onto our tile
func on_tile_entered(other: Entity) -> void:
	if attack_type == EntityData.AttackType.EXPLODE and triggered_by == null and other.shell_type == EntityData.EntityShell.ACTOR and entity.is_hostile_to(other):
		triggered_by = other
