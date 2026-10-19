# stunned_state: can't move or attack, and the target was dropped when the stun landed
class_name StunnedState
extends State

func enter() -> void:
	if entity.movement:
		entity.movement.stop()
	if entity.combat:
		entity.combat.clear_target()
