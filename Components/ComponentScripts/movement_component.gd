# movement component: entities with this component are physical bodies that steer along tile paths.
# the AI (on ticks) decides where to go; every physics frame the unit accelerates towards its next
# waypoint (limited by its mass), and collides with walls, structures and other units
class_name MovementComponent
extends Component

# AI ticks between automatic re-paths, so units react to tiles getting cheaper or pricier
const REPATH_TICKS := 5
# tiles: how far ahead along the path a unit looks for a straight line to cut across
const STRING_PULL_TILES := 4
# pixels: close enough to a waypoint to head for the next one
const WAYPOINT_RADIUS := 12.0
# pixels: close enough to the final tile to stop pushing
const ARRIVE_RADIUS := 3.0
# pixels: start easing off this far from the final tile
const SLOW_RADIUS := 40.0
# how hard units steer away from nearby units while walking (fraction of top speed)
const SEPARATION_STRENGTH := 0.5

var mass: float = 1.0
var max_speed: float = 100.0
var acceleration: float = 600.0
var friction: float = 800.0
var radius: float = 14.0
var velocity: Vector2 = Vector2.ZERO

# where the AI wants this unit to end up
var goal_tile: Vector2i
var has_goal: bool = false
# set when a movement-blocking entity (box, turret) stands on the next tile. the behavior reads and clears it
var blocker: Entity = null
# while set, the unit runs straight at this entity instead of following a path (melee charging its target)
var chase_target: Entity = null
# direction of the last step taken (for knockback from directly underneath, and later for animations)
var facing: Vector2i = Vector2i.RIGHT

var _body: CharacterBody2D # null if the shell isn't a CharacterBody2D; then the unit moves without collisions
var _path: Array[Vector2i] = [] # tiles still to visit, not counting the current waypoint
var _waypoint: Vector2i
var _has_waypoint: bool = false
# spreads units' periodic re-paths over different ticks, so a big wave doesn't path all on the same frame
var _repath_phase: int = 0
static var _spawn_count: int = 0

func _configure(data: EntityData) -> void:
	mass = maxf(data.mass, 0.01)
	max_speed = data.move_speed / sqrt(mass)
	acceleration = data.move_force / mass
	friction = data.friction
	radius = data.body_radius
	_repath_phase = _spawn_count % REPATH_TICKS
	_spawn_count += 1

	var node: Node = entity
	_body = node as CharacterBody2D
	if _body:
		_body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING # top-down: no floor or gravity

# --- called by the AI (on ticks) ---

# ask to walk to a tile. repaths when the goal changed, the path ran out, or every REPATH_TICKS
func request_goal(tile: Vector2i) -> void:
	chase_target = null
	var path_done := _path.is_empty() and not _has_waypoint and entity.current_grid_pos != tile
	var needs_path := not has_goal or tile != goal_tile or is_repath_due() or path_done
	goal_tile = tile
	has_goal = true
	if needs_path:
		_repath()

# run straight at `target` at full speed and keep pushing into it. collisions do the rest
func chase(target: Entity) -> void:
	if target != chase_target:
		stop()
		chase_target = target

# true on this unit's periodic re-path tick (a good moment to re-pick the goal too)
func is_repath_due() -> bool:
	return (entity.ticks_alive + _repath_phase) % REPATH_TICKS == 0

# stop pushing; friction brings the unit to rest
func stop() -> void:
	_path.clear()
	_has_waypoint = false
	has_goal = false
	chase_target = null

func is_moving() -> bool:
	return _has_waypoint or not _path.is_empty()

# the tile new paths should start from
func get_path_origin() -> Vector2i:
	return entity.current_grid_pos

# instant change of momentum (knockback, explosions): heavier units are moved less
func apply_impulse(impulse: Vector2) -> void:
	velocity += impulse / mass

func _repath() -> void:
	var origin := get_path_origin()
	_path = entity.world.map.get_tile_path(origin, goal_tile)
	if not _path.is_empty() and _path[0] == origin:
		_path.remove_at(0)
	_has_waypoint = false

# --- frame based movement ---

func _physics_process(delta: float) -> void:
	if entity == null or not entity.is_alive:
		return

	var desired := _steer()
	# push towards the desired velocity. with nothing to do, or while flying faster than it can run
	# (after a knockback), friction slows the unit down instead
	var rate := acceleration if desired != Vector2.ZERO and velocity.length() <= max_speed else friction
	velocity = velocity.move_toward(desired, rate * delta)

	_move(delta)

	var tile := entity.world.map.world_to_grid(entity.global_position)
	if tile != entity.current_grid_pos:
		entity.world.entities.update_entity_grid_position(entity, tile)

# the velocity the unit wants right now
func _steer() -> Vector2:
	if entity.is_stunned():
		return Vector2.ZERO
	if chase_target:
		if not is_instance_valid(chase_target) or not chase_target.is_alive:
			chase_target = null
			return Vector2.ZERO
		var direction := entity.global_position.direction_to(chase_target.global_position)
		if direction != Vector2.ZERO:
			facing = Vector2i(direction.round())
		return direction * max_speed
	if not _has_waypoint and not _next_waypoint():
		return Vector2.ZERO

	var map := entity.world.map
	var offset := map.grid_to_world(_waypoint) - entity.global_position
	if not _path.is_empty() and offset.length() <= WAYPOINT_RADIUS:
		if not _next_waypoint():
			return Vector2.ZERO
		offset = map.grid_to_world(_waypoint) - entity.global_position

	var distance := offset.length()
	if _path.is_empty():
		# final tile: ease in and stop
		if distance <= ARRIVE_RADIUS:
			_has_waypoint = false
			return Vector2.ZERO
		return offset / distance * minf(max_speed, max_speed * distance / SLOW_RADIUS)

	return (offset / distance + _separation() * SEPARATION_STRENGTH).limit_length(1.0) * max_speed

# take the next tile off the path, unless something is standing in the way
func _next_waypoint() -> bool:
	_has_waypoint = false
	if _path.is_empty():
		return false

	var next := _path[0]
	if not entity.world.map.is_walkable(next):
		# a wall appeared on the path; the next tick's repath will route around it
		_path.clear()
		return false

	var in_the_way := entity.world.entities.get_blocker_at(next, entity)
	if in_the_way:
		blocker = in_the_way
		_path.clear()
		return false

	_path.remove_at(0)
	# string-pulling: skip ahead to later waypoints we can walk to in a straight line, so units
	# cut across open ground instead of zig-zagging tile by tile
	var allowed := {next: true, entity.current_grid_pos: true}
	var lookahead := STRING_PULL_TILES
	while not _path.is_empty() and lookahead > 0:
		lookahead -= 1
		allowed[_path[0]] = true
		if not _can_walk_straight(entity.global_position, _path[0], allowed):
			break
		next = _path[0]
		_path.remove_at(0)

	if next != entity.current_grid_pos:
		facing = (next - entity.current_grid_pos).clampi(-1, 1)
	_waypoint = next
	_has_waypoint = true
	return true

# true when a body our size can walk from `from` to the centre of `tile` without touching a wall,
# a blocker, or a pricey tile (mine etc.) the path didn't choose to cross. `allowed` are the path's own tiles
func _can_walk_straight(from: Vector2, tile: Vector2i, allowed: Dictionary) -> bool:
	var map := entity.world.map
	var to := map.grid_to_world(tile)
	var direction := (to - from).normalized()
	var side := Vector2(-direction.y, direction.x) * radius
	var steps := ceili(from.distance_to(to) / 8.0)
	for i in range(1, steps + 1):
		var point := from.lerp(to, float(i) / steps)
		for offset in [Vector2.ZERO, side, -side]:
			var cell := map.world_to_grid(point + offset)
			if not map.is_walkable(cell) or entity.world.entities.get_blocker_at(cell, entity):
				return false
			if map.get_tile_weight(cell) > 1.0 and not allowed.has(cell):
				return false
	return true

# a gentle push away from units we are about to overlap, so crowds spread out instead of jamming
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other in entity.world.entities.get_entities_in_radius(entity.current_grid_pos, 1.5):
		if other == entity or other.movement == null:
			continue
		var away := entity.global_position - other.global_position
		var reach := (radius + other.movement.radius) * 1.5
		var distance := away.length()
		if distance > 0.01 and distance < reach:
			push += away / distance * (1.0 - distance / reach)
	return push

func _move(delta: float) -> void:
	if _body == null:
		entity.global_position += velocity * delta
		return

	var before := velocity
	_body.velocity = velocity
	_body.move_and_slide()
	velocity = _body.velocity

	# bumping into another unit trades momentum, and walking into one shoves it along,
	# so heavy units plough through light ones while light ones barely move heavy ones
	var bumped: Array[Entity] = []
	for i in _body.get_slide_collision_count():
		var collision := _body.get_slide_collision(i)
		var other := collision.get_collider() as Entity
		if other and other != entity and other.movement and not other in bumped:
			bumped.append(other)
			_bump(other.movement, collision.get_normal(), before, delta)

func _bump(other: MovementComponent, normal: Vector2, our_velocity: Vector2, delta: float) -> void:
	# normal points from the other unit towards us; `into` is how fast we were pushing into it
	var into := -our_velocity.dot(normal)
	if into <= 0.0:
		return
	# the heavier we are compared to them, the more of our push carries on and the further they go
	var share := mass / (mass + other.mass)
	var moved := other.shove(-normal * into * share * delta)
	# give back the part of our push the collision took away, but only as far as they actually gave
	# way (not at all if they are pinned against a wall)
	var lost := maxf(0.0, into + velocity.dot(normal))
	velocity -= normal * minf(lost, into * share * moved)

# move straight away by `offset` (walls still stop it), e.g. when another unit pushes into us.
# returns how much of the offset was actually travelled, from 0 to 1
func shove(offset: Vector2) -> float:
	var start := entity.global_position
	if _body:
		_body.move_and_collide(offset)
	else:
		entity.global_position += offset
	var tile := entity.world.map.world_to_grid(entity.global_position)
	if tile != entity.current_grid_pos:
		entity.world.entities.update_entity_grid_position(entity, tile)
	return clampf(start.distance_to(entity.global_position) / offset.length(), 0.0, 1.0) if offset.length() > 0.0 else 0.0
