# state: base class for states 
class_name state
extends Node

# store owner and state machine
var entity: Entity
#var state_machine: StateMachine

# called once by the StateMachine when the entity is spawned
func setup(parent_entity: Entity) -> void:
	entity = parent_entity
	#state_machine = machine

# called when the state machine switches TO this state
func enter() -> void:
	pass

# called when the state machine switches AWAY from this state
func exit() -> void:
	pass

# fired by the EntityManager's 0.2s tick (Phase 1: Intent)
func on_tick() -> void:
	pass
