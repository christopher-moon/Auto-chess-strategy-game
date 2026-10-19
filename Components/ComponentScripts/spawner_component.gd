# spawner_component: spawns units of its entity's team next to it on a fixed timer, up to a max count.
# while the max count is alive, the timer waits
class_name SpawnerComponent
extends Component

var spawn_entity_name: String = ""
var max_count: int = 3
var interval_ticks: int = 20

var _timer: int = 0
var _spawned: Array[Entity] = []

func _configure(data: EntityData) -> void:
	spawn_entity_name = data.spawn_entity_name
	max_count = data.spawn_max_count
	interval_ticks = entity.world.seconds_to_ticks(data.spawn_interval)

func get_alive_count() -> int:
	return _spawned.size()

func tick() -> void:
	for i in range(_spawned.size() - 1, -1, -1):
		if not is_instance_valid(_spawned[i]) or not _spawned[i].is_alive:
			_spawned.remove_at(i)

	if _spawned.size() >= max_count:
		return

	_timer += 1
	if _timer < interval_ticks:
		return

	var tile: Variant = entity.world.find_open_tile_near(entity.current_grid_pos)
	if tile == null:
		return # surrounded; try again next tick

	_timer = 0
	var spawned := entity.world.spawner.spawn_entity(spawn_entity_name, entity.world.map.grid_to_world(tile), entity.team)
	if spawned:
		_spawned.append(spawned)
