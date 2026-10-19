# level_manager: level rules. runs the level timer and the objective, and decides win or loss.
# the timer starts when the attacking team places its first unit (later: plays its first card)
class_name LevelManager
extends Node

enum ObjectiveType {CAPTURE_ZONE, DESTROY_TARGETS}
enum LevelState {WAITING, RUNNING, WON, LOST}

signal level_started
signal level_ended(won: bool, reason: String)

@export var objective_type: ObjectiveType = ObjectiveType.CAPTURE_ZONE
@export var time_limit: float = 120.0
# seconds the attacking team must hold the zone, uncontested
@export var capture_time: float = 5.0
@export var attacking_team: Entity.Team = Entity.Team.PLAYER

@onready var entity_manager: EntityManager = $"../EntityManager"
@onready var map_manager: MapManager = $"../MapManager"
@onready var time_manager: TimeManager = $"../TimeManager"

var state: LevelState = LevelState.WAITING
var time_remaining: float = 0.0
var capture_progress: float = 0.0
var is_contested: bool = false
var end_reason: String = ""

func _ready() -> void:
	time_remaining = time_limit
	entity_manager.entity_registered.connect(_on_entity_registered)
	time_manager.on_global_tick.connect(_on_tick)

func _on_entity_registered(entity: Entity) -> void:
	if state == LevelState.WAITING and entity.team == attacking_team and entity.shell_type == EntityData.EntityShell.ACTOR:
		state = LevelState.RUNNING
		level_started.emit()

func _on_tick() -> void:
	if state != LevelState.RUNNING:
		return
	var dt := time_manager.tick_rate
	time_remaining = maxf(time_remaining - dt, 0.0)

	match objective_type:
		ObjectiveType.CAPTURE_ZONE:
			_update_capture(dt)
		ObjectiveType.DESTROY_TARGETS:
			push_warning("LevelManager: DESTROY_TARGETS is not implemented yet")

	if state != LevelState.RUNNING:
		return
	if time_remaining <= 0.0:
		_end(false, "Out of time")
	elif entity_manager.count_team_actors(attacking_team) == 0:
		_end(false, "All units defeated")

# progress fills while attackers stand on objective tiles and no defender does
func _update_capture(dt: float) -> void:
	var attackers := 0
	var defenders := 0
	for tile in map_manager.objective_tiles:
		for e in entity_manager.get_entities_at_grid(tile):
			if e.shell_type != EntityData.EntityShell.ACTOR:
				continue
			if e.team == attacking_team:
				attackers += 1
			elif e.team != Entity.Team.NEUTRAL:
				defenders += 1

	is_contested = attackers > 0 and defenders > 0
	if attackers > 0 and defenders == 0:
		capture_progress = minf(capture_progress + dt, capture_time)
		if capture_progress >= capture_time:
			_end(true, "Zone captured")

func _end(won: bool, reason: String) -> void:
	state = LevelState.WON if won else LevelState.LOST
	end_reason = reason
	time_manager.is_ticking = false
	level_ended.emit(won, reason)
