# attacking_state: hitting the current target whenever the attack cooldown is ready.
# units that charge keep running into the target meanwhile; the rest hold the tile they started
# attacking from, and step back onto it if a recoil or a shove knocks them off.
# the behavior only picks this state while the target is in range
class_name AttackingState
extends State

var _hold_tile: Vector2i

func enter() -> void:
	_hold_tile = entity.current_grid_pos

func exit() -> void:
	if entity.movement:
		entity.movement.stop()

func on_tick() -> void:
	var combat := entity.combat
	var movement := entity.movement
	if movement:
		if combat.charge_while_attacking and combat.has_valid_target():
			movement.chase(combat.target)
		elif entity.current_grid_pos != _hold_tile:
			movement.request_goal(_hold_tile)
		elif not movement.is_moving():
			movement.stop()
	if combat.is_ready() and combat.has_valid_target():
		combat.attack(combat.target)
