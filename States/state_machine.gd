# state_machine: holds a unit's single active state. each tick the behavior picks which state the
# unit should be in, the machine switches if needed, then runs that state's on_tick
class_name StateMachine
extends Node

enum StateId {IDLE, MOVING, ATTACKING, STUNNED}

signal state_changed(previous: StateId, current: StateId)

var entity: Entity
var current_id: StateId = StateId.IDLE
var current: State

var _states: Dictionary = {}

func setup(parent_entity: Entity) -> void:
	entity = parent_entity
	_states = {
		StateId.IDLE: IdleState.new(),
		StateId.MOVING: MovingState.new(),
		StateId.ATTACKING: AttackingState.new(),
		StateId.STUNNED: StunnedState.new(),
	}
	for state in _states.values():
		state.setup(entity)
	current_id = StateId.IDLE
	current = _states[current_id]
	current.enter()

func tick() -> void:
	if entity.stun_ticks > 0:
		change_state(StateId.STUNNED)
		entity.stun_ticks -= 1
		return

	var next: StateId = entity.behavior.decide(entity) if entity.behavior else StateId.IDLE
	change_state(next)
	current.on_tick()

func change_state(id: StateId) -> void:
	if id == current_id:
		return
	var previous := current_id
	current.exit()
	current_id = id
	current = _states[id]
	current.enter()
	state_changed.emit(previous, id)

# for debug labels, and later for picking state-based animation loops
func get_state_name() -> String:
	return StateId.keys()[current_id].capitalize()
