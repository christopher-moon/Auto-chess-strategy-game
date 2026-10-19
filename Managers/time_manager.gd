# time_manager: handles global tick used in AI decisions
# every tick runs in a fixed order: 1. every entity thinks and acts (attacks are only queued),
# 2. the CombatManager applies all queued hits at once, 3. listeners (level rules, UI) react
class_name TimeManager
extends Node

signal on_global_tick

@export var tick_rate: float = 0.2
var _time_accumulator: float = 0.0
var is_ticking: bool = true
var tick_count: int = 0

@onready var entity_manager: EntityManager = $"../EntityManager"
@onready var combat_manager: CombatManager = $"../CombatManager"

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
	tick_count += 1
	# 1. Direct calls (Fast, deterministic order)
	entity_manager.process_ai_tick()
	combat_manager.resolve()

	# 2. Emit signal for anything else listening (level rules, UI, Spawners)
	on_global_tick.emit()

# Easy hooks for pausing/resuming game logic (dont forget to change mode for time/ui so game wont get stuck)
func pause_game() -> void:
	is_ticking = false
	get_tree().paused = true

func resume_game() -> void:
	is_ticking = true
	get_tree().paused = false
