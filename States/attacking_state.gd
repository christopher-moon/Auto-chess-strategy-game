# attacking_state: standing still and hitting the current target whenever the attack cooldown is ready.
# the behavior only picks this state while the target is in range
class_name AttackingState
extends State

func enter() -> void:
	if entity.movement:
		entity.movement.stop()

func on_tick() -> void:
	var combat := entity.combat
	if combat.is_ready() and combat.has_valid_target():
		combat.attack(combat.target)
