# moving_state: walking towards the goal tile the behavior picked this tick
class_name MovingState
extends State

func exit() -> void:
	entity.movement.stop()
