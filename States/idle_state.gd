# idle_state: standing still. the behavior decides when to leave
class_name IdleState
extends State

func enter() -> void:
	if entity.movement:
		entity.movement.stop()
