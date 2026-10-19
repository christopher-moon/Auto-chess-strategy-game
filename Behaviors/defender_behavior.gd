# defender_behavior: guards its home tile (where it was spawned). it fights enemies it can reach from a
# tile within `leash_range` tiles of home, and walks back home whenever it is out of combat
class_name DefenderBehavior
extends Behavior

# tiles from home a defender will go to fight
@export var leash_range: float = 3.0

func decide(entity: Entity) -> int:
	var combat := entity.combat
	_validate_target(entity)
	_take_blocker_as_target(entity)

	var home := Vector2(entity.home_tile)
	var near_home := func(tile: Vector2i) -> bool: return Vector2(tile).distance_to(home) <= leash_range

	# only look for fights while guarding home
	if not combat.has_valid_target() and near_home.call(entity.current_grid_pos):
		combat.target = _acquire_target(entity, combat.threat_range)

	if combat.has_valid_target():
		# boxes in our way get broken wherever they are; enemies only get chased inside the leash
		var allowed: Callable = near_home if entity.is_hostile_to(combat.target) else Callable()
		if allowed.is_valid() and not near_home.call(entity.current_grid_pos) and not combat.can_attack(combat.target):
			combat.clear_target()
		else:
			var state := _engage(entity, combat.target, allowed)
			if state != NO_ENGAGE:
				return state
			combat.clear_target()

	return _return_home(entity)

func _return_home(entity: Entity) -> int:
	var movement := entity.movement
	if movement == null or movement.is_waiting() or entity.current_grid_pos == entity.home_tile and not movement.is_moving():
		return Id.IDLE
	movement.request_goal(entity.home_tile)
	return Id.MOVING if movement.is_moving() else Id.IDLE
