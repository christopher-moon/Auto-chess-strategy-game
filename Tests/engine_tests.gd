# engine_tests: headless checks for the core engine rules. each test loads a fresh game scene.
# run from the project folder:
#   godot --headless --fixed-fps 60 --script res://Tests/engine_tests.gd
extends SceneTree

const GAME_SCENE := "res://Scenes/game.tscn"
const FPS := 60

# test-only behavior: walk to `goal`, breaking through anything in the way
class GoTo extends Behavior:
	var goal: Vector2i
	func _init(goal_tile: Vector2i) -> void:
		goal = goal_tile
	func decide(entity: Entity) -> int:
		_take_blocker_as_target(entity)
		if entity.combat.has_valid_target():
			var state := _engage(entity, entity.combat.target)
			if state != NO_ENGAGE:
				return state
		if entity.current_grid_pos == goal and not entity.movement.is_moving():
			return Id.IDLE
		entity.movement.request_goal(goal)
		return Id.MOVING

var game: Node
var failures: Array[String] = []
var _current := ""

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for test in [
		"test_melee_units_trade",
		"test_ranged_stops_at_nearest_tile_in_range",
		"test_line_of_sight_blocks_detection",
		"test_units_path_around_mines",
		"test_mine_explodes_when_walked_over",
		"test_units_path_around_boxes",
		"test_units_break_box_when_no_other_way",
		"test_knockback_stops_before_walls",
		"test_stun_stops_attacks_and_clears_target",
		"test_spawner_respects_max_count",
		"test_attacker_captures_objective",
		"test_defender_stays_leashed",
	]:
		_current = test
		await _load_game()
		await call(test)
		game.queue_free()
		await process_frame
	print("")
	if failures.is_empty():
		print("ALL TESTS PASSED")
	else:
		print("%d FAILURE(S):" % failures.size())
		for f in failures:
			print("  " + f)
	quit(1 if not failures.is_empty() else 0)

# --- helpers ---

func _load_game() -> void:
	game = load(GAME_SCENE).instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.get_node("LevelManager").time_limit = 999.0
	game.get_node("LevelManager").time_remaining = 999.0

func _spawn(entity_name: String, tile: Vector2i, team: Entity.Team, behavior: Behavior = null) -> Entity:
	var map: MapManager = game.get_node("MapManager")
	return game.get_node("EntitySpawner").spawn_entity(entity_name, map.grid_to_world(tile), team, behavior)

func _wall(tile: Vector2i) -> void:
	game.get_node("MapManager").set_wall(tile, true)

func _wait(seconds: float) -> void:
	for i in roundi(seconds * FPS):
		await process_frame

func _tick() -> int:
	return game.get_node("TimeManager").tick_count

func _alive(e: Variant) -> bool:
	return is_instance_valid(e) and e.is_alive

func _check(condition: bool, message: String) -> void:
	print("  %s %s: %s" % ["ok  " if condition else "FAIL", _current, message])
	if not condition:
		failures.append("%s: %s" % [_current, message])

# --- tests ---

func test_melee_units_trade() -> void:
	var attacker := AttackerBehavior.new()
	var a := _spawn("Melee", Vector2i(8, 10), Entity.Team.PLAYER, attacker)
	var b := _spawn("Melee", Vector2i(9, 10), Entity.Team.ENEMY, attacker)
	var death_ticks := {}
	a.died.connect(func(_e: Entity) -> void: death_ticks["a"] = _tick())
	b.died.connect(func(_e: Entity) -> void: death_ticks["b"] = _tick())
	await _wait(8.0)
	_check(death_ticks.has("a") and death_ticks.has("b"), "both units died")
	_check(death_ticks.get("a", -1) == death_ticks.get("b", -2), "they died on the same tick (%s)" % death_ticks)

func test_ranged_stops_at_nearest_tile_in_range() -> void:
	var ranged := _spawn("Ranged", Vector2i(6, 10), Entity.Team.PLAYER)
	var dummy := _spawn("Melee", Vector2i(12, 10), Entity.Team.ENEMY, Behavior.new())
	dummy.health.max_health = 1000.0
	dummy.health.current_health = 1000.0
	await _wait(4.0)
	_check(ranged.combat.target == dummy, "ranged unit locked onto the dummy")
	_check(ranged.current_grid_pos == Vector2i(8, 10), "stopped 4 tiles away, at (8, 10) (got %s)" % ranged.current_grid_pos)
	_check(dummy.health.current_health < 1000.0, "projectiles hit the dummy")

func test_line_of_sight_blocks_detection() -> void:
	_wall(Vector2i(10, 10))
	var ranged := _spawn("Ranged", Vector2i(8, 10), Entity.Team.PLAYER, Behavior.new())
	var dummy := _spawn("Melee", Vector2i(12, 10), Entity.Team.ENEMY, Behavior.new())
	var entities: EntityManager = game.get_node("EntityManager")
	_check(entities.find_nearest_enemy(ranged, 6.0) == null, "enemy behind a wall is not detected")
	game.get_node("MapManager").line_of_sight_enabled = false
	_check(entities.find_nearest_enemy(ranged, 6.0) == dummy, "detected once line of sight is switched off")

func test_units_path_around_mines() -> void:
	var mine := _spawn("Mine", Vector2i(10, 12), Entity.Team.ENEMY)
	var unit := _spawn("Melee", Vector2i(8, 12), Entity.Team.PLAYER, GoTo.new(Vector2i(12, 12)))
	await _wait(5.0)
	_check(unit.current_grid_pos == Vector2i(12, 12), "unit reached its goal")
	_check(_alive(mine), "mine was avoided")

func test_mine_explodes_when_walked_over() -> void:
	# a pocket whose only exit is the mine tile
	for t in [Vector2i(8, 9), Vector2i(8, 11), Vector2i(7, 10), Vector2i(9, 9), Vector2i(9, 11)]:
		_wall(t)
	var mine := _spawn("Mine", Vector2i(9, 10), Entity.Team.ENEMY)
	var unit := _spawn("Melee", Vector2i(8, 10), Entity.Team.PLAYER, GoTo.new(Vector2i(11, 10)))
	var was_stunned := false
	var knocked_to := Vector2i(-1, -1)
	for i in 3 * FPS:
		await process_frame
		if _alive(unit) and unit.is_stunned():
			if not was_stunned:
				await _wait(0.2)
				knocked_to = unit.current_grid_pos
			was_stunned = true
	_check(not _alive(mine), "mine exploded")
	_check(_alive(unit) and is_equal_approx(unit.health.current_health, 4.0), "unit took 6 damage")
	_check(was_stunned, "unit was stunned")
	_check(knocked_to == Vector2i(8, 10), "unit was knocked back the way it came (got %s)" % knocked_to)
	await _wait(3.0)
	_check(unit.current_grid_pos == Vector2i(11, 10), "unit carried on to its goal after the stun")

func test_units_path_around_boxes() -> void:
	var box := _spawn("Box", Vector2i(10, 12), Entity.Team.NEUTRAL)
	var unit := _spawn("Melee", Vector2i(8, 12), Entity.Team.PLAYER, GoTo.new(Vector2i(12, 12)))
	await _wait(5.0)
	_check(unit.current_grid_pos == Vector2i(12, 12), "unit reached its goal")
	_check(_alive(box) and is_equal_approx(box.health.current_health, box.health.max_health), "box was left alone")

func test_units_break_box_when_no_other_way() -> void:
	for t in [Vector2i(8, 9), Vector2i(8, 11), Vector2i(7, 10), Vector2i(9, 9), Vector2i(9, 11)]:
		_wall(t)
	var box := _spawn("Box", Vector2i(9, 10), Entity.Team.NEUTRAL)
	var unit := _spawn("Melee", Vector2i(8, 10), Entity.Team.PLAYER, GoTo.new(Vector2i(11, 10)))
	await _wait(12.0)
	_check(not _alive(box), "box was destroyed")
	_check(unit.current_grid_pos == Vector2i(11, 10), "unit walked through the gap (at %s)" % unit.current_grid_pos)

func test_knockback_stops_before_walls() -> void:
	_wall(Vector2i(11, 12))
	var hitter := _spawn("Melee", Vector2i(8, 12), Entity.Team.PLAYER, AttackerBehavior.new())
	hitter.combat.knockback = 3
	var dummy := _spawn("Melee", Vector2i(9, 12), Entity.Team.ENEMY, Behavior.new())
	dummy.health.max_health = 1000.0
	dummy.health.current_health = 1000.0
	await _wait(1.0)
	_check(dummy.current_grid_pos == Vector2i(10, 12), "pushed 1 tile, stopping before the wall (at %s)" % dummy.current_grid_pos)

func test_stun_stops_attacks_and_clears_target() -> void:
	var hitter := _spawn("Melee", Vector2i(8, 12), Entity.Team.PLAYER, AttackerBehavior.new())
	var dummy := _spawn("Melee", Vector2i(9, 12), Entity.Team.ENEMY, Behavior.new())
	dummy.health.max_health = 1000.0
	dummy.health.current_health = 1000.0
	await _wait(0.5)
	hitter.apply_stun(10)
	_check(hitter.combat.target == null, "stun cleared the target")
	var hp := dummy.health.current_health
	await _wait(1.5)
	_check(hitter.state_machine.current_id == StateMachine.StateId.STUNNED, "unit is in the stunned state")
	_check(is_equal_approx(dummy.health.current_health, hp), "no damage dealt while stunned")
	await _wait(2.0)
	_check(dummy.health.current_health < hp, "unit fights again after the stun")

func test_spawner_respects_max_count() -> void:
	var spawner := _spawn("Spawner", Vector2i(8, 12), Entity.Team.ENEMY)
	await _wait(20.0)
	_check(spawner.unit_spawner.get_alive_count() == 3, "3 units alive (got %d)" % spawner.unit_spawner.get_alive_count())
	_check(game.get_node("EntityManager").count_team_actors(Entity.Team.ENEMY) == 3, "no extra units spawned")

func test_attacker_captures_objective() -> void:
	var level: LevelManager = game.get_node("LevelManager")
	_spawn("Melee", Vector2i(8, 12), Entity.Team.PLAYER)
	await _wait(20.0)
	_check(level.state == LevelManager.LevelState.WON, "zone captured (state %s, progress %s)" % [level.state, level.capture_progress])

func test_defender_stays_leashed() -> void:
	var defender := _spawn("Melee", Vector2i(12, 14), Entity.Team.ENEMY)
	# 5 walking tiles from the objective: inside threat range, outside the leash
	var far := _spawn("Melee", Vector2i(12, 9), Entity.Team.PLAYER, Behavior.new())
	await _wait(3.0)
	_check(is_equal_approx(far.health.current_health, far.health.max_health), "defender ignored the unit outside its leash")
	_check(game.get_node("MapManager").distance_to_objective(defender.current_grid_pos) == 0, "defender stayed on the objective")
	var near := _spawn("Melee", Vector2i(12, 12), Entity.Team.PLAYER, Behavior.new())
	await _wait(3.0)
	_check(near.health.current_health < near.health.max_health, "defender fought the unit inside its leash")
