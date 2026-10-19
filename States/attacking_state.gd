# attacking_state: fighting the current target. the unit keeps moving as its behavior steers it
# (charging in, closing to range, or holding still) and hits the target whenever it is in range
# and the attack cooldown is ready
class_name AttackingState
extends State

func exit() -> void:
	if entity.movement:
		entity.movement.stop()

func on_tick() -> void:
	var combat := entity.combat
	if combat.is_ready() and combat.has_valid_target() and combat.can_attack(combat.target):
		combat.attack(combat.target)
