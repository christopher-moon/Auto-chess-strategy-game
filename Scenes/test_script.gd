# test_script.gd: initilize everything + some basic game controls for testing
extends Node2D

# number keys spawn these at the mouse tile
const SPAWN_KEYS := {
	KEY_1: "Melee",
	KEY_2: "Ranged",
	KEY_3: "Mine",
	KEY_4: "Turret",
	KEY_5: "Spawner",
	KEY_6: "Box",
	KEY_7: "Brute",
}
# entities that always spawn as neutral, whatever team is selected
const NEUTRAL_ENTITIES := ["Box"]
const TEST_STUN_SECONDS := 2.0
# AI given to placed units (and to units from placed spawners). A cycles through them, whatever the team
const AI_CHOICES := {
	"Attacker": preload("res://Behaviors/attacker.tres"),
	"Defender": preload("res://Behaviors/defender.tres"),
}

@onready var spawner: EntitySpawner = $EntitySpawner
@onready var entity_manager: EntityManager = $EntityManager
@onready var map_manager: MapManager = $MapManager
@onready var time_manager: TimeManager = $TimeManager
@onready var level_manager: LevelManager = $LevelManager

var selected_team: Entity.Team = Entity.Team.PLAYER
var selected_ai: String = "Attacker"
var _hud: Label
var _overlay: DebugOverlay

func _ready() -> void:
	_overlay = DebugOverlay.new()
	_overlay.entity_manager = entity_manager
	add_child(_overlay)

	var canvas := CanvasLayer.new()
	add_child(canvas)
	_hud = Label.new()
	_hud.position = Vector2(40, 1180)
	_hud.add_theme_font_size_override("font_size", 28)
	canvas.add_child(_hud)

func _process(_delta: float) -> void:
	_hud.text = _hud_text()

# basic game controls
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var tile := map_manager.world_to_grid(get_global_mouse_position())

	if SPAWN_KEYS.has(event.keycode):
		_spawn_at(SPAWN_KEYS[event.keycode], tile)
		return

	match event.keycode:
		KEY_TAB, KEY_T:
			selected_team = Entity.Team.ENEMY if selected_team == Entity.Team.PLAYER else Entity.Team.PLAYER
		KEY_A:
			var names := AI_CHOICES.keys()
			selected_ai = names[(names.find(selected_ai) + 1) % names.size()]
		KEY_W:
			map_manager.set_wall(tile, map_manager.is_walkable(tile))
		KEY_O:
			map_manager.set_objective(tile, not map_manager.is_objective(tile))
		KEY_X:
			for e in entity_manager.get_entities_at_grid(tile).duplicate():
				entity_manager.remove_entity(e)
		KEY_S:
			for e in entity_manager.get_entities_at_grid(tile):
				e.apply_stun(spawner.world.seconds_to_ticks(TEST_STUN_SECONDS))
		KEY_L:
			map_manager.line_of_sight_enabled = not map_manager.line_of_sight_enabled
		KEY_H:
			Entity.show_debug_labels = not Entity.show_debug_labels
			_overlay.visible = Entity.show_debug_labels
			for e in entity_manager.actors + entity_manager.obstacles + entity_manager.triggers:
				e.refresh_debug_label()
		KEY_SPACE:
			if level_manager.state == LevelManager.LevelState.WAITING or level_manager.state == LevelManager.LevelState.RUNNING:
				time_manager.is_ticking = not time_manager.is_ticking
		KEY_R:
			get_tree().reload_current_scene()

func _spawn_at(entity_name: String, tile: Vector2i) -> void:
	if not map_manager.is_walkable(tile) or entity_manager.get_blocker_at(tile):
		return
	var team := Entity.Team.NEUTRAL if entity_name in NEUTRAL_ENTITIES else selected_team
	var ai: Behavior = AI_CHOICES[selected_ai]
	# entities with their own AI in their data (turrets, mines) keep it
	var data := spawner.get_data(entity_name)
	var entity := spawner.spawn_entity(entity_name, map_manager.grid_to_world(tile), team, ai if data and data.behavior == null else null)
	if entity and entity.unit_spawner:
		entity.unit_spawner.spawn_behavior = ai

func _hud_text() -> String:
	var lines: Array[String] = []
	match level_manager.state:
		LevelManager.LevelState.WAITING:
			lines.append("Place a Player unit to start the timer")
		LevelManager.LevelState.RUNNING:
			lines.append("Time %.1fs   Capture %.1f / %.1fs%s" % [level_manager.time_remaining, level_manager.capture_progress, level_manager.capture_time, "   CONTESTED" if level_manager.is_contested else ""])
		LevelManager.LevelState.WON:
			lines.append("VICTORY: %s   (R to restart)" % level_manager.end_reason)
		LevelManager.LevelState.LOST:
			lines.append("DEFEAT: %s   (R to restart)" % level_manager.end_reason)
	lines.append("Team: %s   AI: %s   Line of sight: %s%s" % [Entity.Team.keys()[selected_team].capitalize(), selected_ai, "on" if map_manager.line_of_sight_enabled else "off", "   PAUSED" if not time_manager.is_ticking and level_manager.state <= LevelManager.LevelState.RUNNING else ""])
	lines.append("1 Melee  2 Ranged  3 Mine  4 Turret  5 Spawner  6 Box  7 Brute")
	lines.append("Tab team  A AI  W wall  O objective  X delete  S stun")
	lines.append("L line of sight  H debug  Space pause  R restart")
	return "\n".join(lines)
