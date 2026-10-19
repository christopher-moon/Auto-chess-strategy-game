# time_manager: handles global tick used in AI decisions
class_name TimeManager
extends Node

signal on_global_tick 

@export var tick_rate: float = 0.2
var _time_accumulator: float = 0.0
var is_ticking: bool = true

@onready var entity_manager: EntityManager = $"../EntityManager"

func _process(delta: float) -> void:
	if not is_ticking:
		return
		
	_time_accumulator += delta
	
	# "While" loop handles frame drops. If a frame takes 0.5s, 
	# this ensures we still fire the missed 0.2s ticks.
	while _time_accumulator >= tick_rate:
		_time_accumulator -= tick_rate
		broadcast_tick()
		
func broadcast_tick() -> void:
	# 1. Direct call to EntityManager (Fast, deterministic)
	entity_manager.process_ai_tick()
	
	# 2. Emit signal for anything else listening (UI, Spawners)
	on_global_tick.emit()

# Easy hooks for pausing/resuming game logic (dont forget to change mode for time/ui so game wont get stuck)
func pause_game() -> void:
	is_ticking = false
	get_tree().paused = true
	
func resume_game() -> void:
	is_ticking = true
	get_tree().paused = false
