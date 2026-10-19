# state: base class for unit states. a unit is only ever in one state at a time; the StateMachine
# owns one instance of each state per unit and switches between them
class_name State
extends RefCounted

# store owner entity
var entity: Entity

# called once by the StateMachine when the entity is spawned
func setup(parent_entity: Entity) -> void:
	entity = parent_entity

# called when the state machine switches TO this state
func enter() -> void:
	pass

# called when the state machine switches AWAY from this state
func exit() -> void:
	pass

# fired every AI tick while this is the current state
func on_tick() -> void:
	pass
