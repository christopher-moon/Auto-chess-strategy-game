# movement component: entities with this component are physical bodies that steer along tile paths.
# the AI (on ticks) decides where to go; every physics frame the unit accelerates towards its next
# waypoint (limited by its mass), and collides with walls, structures and other units
class_name MovementComponent
extends Component

# AI ticks between automatic re-paths, so units react to tiles getting cheaper or pricier
const REPATH_TICKS := 5
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
var knockback_speed: float = 400.0

# where the AI wants this unit to end up
var goal_tile: Vector2i
var has_goal: bool = false
# set when a movement-blocking entity (box, turret) stands on the next tile. the behavior reads and clears it
var blocker: Entity = null
# direction of the last step taken (for knockback from directly underneath, and later for animations)
var facing: Vector2i = Vector2i.RIGHT

var _body: CharacterBody2D # null if the shell isn't a CharacterBody2D; then the unit moves without collisions
var _path: Array[Vector2i] = [] # tiles still to visit, not counting the current waypoint
var _waypoint: Vector2i
var _has_waypoint: bool = false
var _ticks_since_path: int = 0
var _knock_target: Vector2
var _knock_time_left: float = 0.0

func _configure(data: EntityData) -> void:
	mass = maxf(data.mass, 0.01)
	max_speed = data.move_speed / sqrt(mass)
	acceleration = data.move_force / mass
	friction = data.friction
	radius = data.body_radius

	var node: Node = entity
	_body = node as CharacterBody2D
	if _body:
		_body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING # top-down: no floor or gravity

# --- called by the AI (on ticks) ---

# ask to walk to a tile. repaths when the goal changed, the path ran out, or every REPATH_TICKS
func request_goal(tile: Vector2i) -> void:
	_ticks_since_path += 1
	var path_done := _path.is_empty() and not _has_waypoint and entity.current_grid_pos != tile
	var needs_path := not has_goal or tile != goal_tile or _ticks_since_path >= REPATH_TICKS or path_done
	goal_tile = tile
	has_goal = true
	if needs_path:
		_repath()

# stop pushing; friction brings the unit to rest
func stop() -> void:
	_path.clear()
	_has_waypoint = false
	has_goal = false

func is_moving() -> bool:
	return _has_waypoint or not _path.is_empty() or _knock_time_left > 0.0

# the tile new paths should start from
func get_path_origin() -> Vector2i:
	return entity.current_grid_pos

# slide to `tile` (already checked to be safe by the CombatManager), cancelling the path
func knock_to(tile: Vector2i) -> void:
	stop()
	_knock_target = entity.world.map.grid_to_world(tile)
	_knock_time_left = entity.global_position.distance_to(_knock_target) / knockback_speed + 0.1

func _repath() -> void:
	_ticks_since_path = 0
	var origin := get_path_origin()
	_path = entity.world.map.get_tile_path(origin, goal_tile)
	if not _path.is_empty() and _path[0] == origin:
		_path.remove_at(0)
	_has_waypoint = false

# --- frame based movement ---

func _physics_process(delta: float) -> void:
	if entity == null or not entity.is_alive:
		return

	if _knock_time_left > 0.0:
		_knock_time_left -= delta
		var to_target := _knock_target - entity.global_position
		velocity = Vector2.ZERO if to_target.length() <= ARRIVE_RADIUS else to_target.normalized() * knockback_speed
	else:
		var desired := _steer()
		# push towards the desired velocity; with nothing to do, friction slows the unit down
		var rate := acceleration if desired != Vector2.ZERO else friction
		velocity = velocity.move_toward(desired, rate * delta)

	_move(delta)

	var tile := entity.world.map.world_to_grid(entity.global_position)
	if tile != entity.current_grid_pos:
		entity.world.entities.update_entity_grid_position(entity, tile)

# the velocity the unit wants right now
func _steer() -> Vector2:
	if entity.is_stunned():
		return Vector2.ZERO
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
	if next != entity.current_grid_pos:
		facing = next - entity.current_grid_pos
	_waypoint = next
	_has_waypoint = true
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
