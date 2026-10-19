# attacking_state: hitting the current target whenever the attack cooldown is ready.
# units that charge keep running into the target meanwhile; the rest stand still and hold position.
# the behavior only picks this state while the target is in range
class_name AttackingState
extends State

func exit() -> void:
	if entity.movement:
		entity.movement.stop()

func on_tick() -> void:
	var combat := entity.combat
	if entity.movement:
		if combat.charge_while_attacking and combat.has_valid_target():
			entity.movement.chase(combat.target)
		else:
			entity.movement.stop()
	if combat.is_ready() and combat.has_valid_target():
		combat.attack(combat.target)
