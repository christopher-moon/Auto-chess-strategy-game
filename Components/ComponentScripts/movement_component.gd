# movement component: entities with this component walk tile to tile along paths.
# the AI (on ticks) decides where to go; the walking itself happens every physics frame
class_name MovementComponent
extends Component

const ARRIVE_DISTANCE := 1.0
# AI ticks between automatic re-paths, so units react to tiles getting cheaper or pricier
const REPATH_TICKS := 5

var speed: float = 100.0
var knockback_speed: float = 400.0

# where the AI wants this unit to end up
var goal_tile: Vector2i
var has_goal: bool = false
# set when a movement-blocking entity (box, turret) stands on the next tile. the behavior reads and clears it
var blocker: Entity = null
# direction of the last step taken (for knockback from directly underneath, and later for animations)
var facing: Vector2i = Vector2i.RIGHT

var _path: Array[Vector2i] = [] # tiles still to visit, not counting the current step
var _step_tile: Vector2i # tile we are walking towards right now
var _has_step: bool = false
var _is_knockback: bool = false
var _ticks_since_path: int = 0

func _configure(data: EntityData) -> void:
	speed = data.move_speed

# --- called by the AI (on ticks) ---

# ask to walk to a tile. repaths when the goal changed, the path ran out, or every REPATH_TICKS
func request_goal(tile: Vector2i) -> void:
	_ticks_since_path += 1
	var needs_path := not has_goal or tile != goal_tile or _ticks_since_path >= REPATH_TICKS or (_path.is_empty() and get_path_origin() != tile)
	goal_tile = tile
	has_goal = true
	if needs_path:
		_repath()

# drop the rest of the path. the current step still finishes, so units always come to rest on a tile centre
func stop() -> void:
	_path.clear()
	has_goal = false

func is_moving() -> bool:
	return _has_step or not _path.is_empty()

# the tile new paths should start from: where we are heading if mid-step, else where we stand
func get_path_origin() -> Vector2i:
	return _step_tile if _has_step else entity.current_grid_pos

# slide straight to `tile` (already checked to be safe by the CombatManager), cancelling the path
func knock_to(tile: Vector2i) -> void:
	_path.clear()
	has_goal = false
	_step_tile = tile
	_has_step = true
	_is_knockback = true

func _repath() -> void:
	_ticks_since_path = 0
	var origin := get_path_origin()
	_path = entity.world.map.get_tile_path(origin, goal_tile)
	if not _path.is_empty() and _path[0] == origin:
		_path.remove_at(0)

# --- frame based movement ---

func _physics_process(delta: float) -> void:
	if entity == null or not entity.is_alive:
		return

	if not _has_step and not _start_next_step():
		return

	var target_position := entity.world.map.grid_to_world(_step_tile)
	var step_speed := knockback_speed if _is_knockback else speed
	entity.global_position = entity.global_position.move_toward(target_position, step_speed * delta)

	var tile := entity.world.map.world_to_grid(entity.global_position)
	if tile != entity.current_grid_pos:
		entity.world.entities.update_entity_grid_position(entity, tile)

	if entity.global_position.distance_to(target_position) <= ARRIVE_DISTANCE:
		entity.global_position = target_position
		_has_step = false
		_is_knockback = false

# take the next tile off the path, unless something is standing in the way
func _start_next_step() -> bool:
	if _path.is_empty() or entity.is_stunned():
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
	_step_tile = next
	_has_step = true
	return true
