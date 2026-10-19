# test_script.gd: initilize everything + some basic game controls for testing
extends Node2D
#yeow meow goose rax
@onready var spawner: EntitySpawner = $EntitySpawner
@onready var entity_manager: EntityManager = $EntityManager
@onready var map_manager: MapManager = $MapManager

func _ready():	
	# Delete the hardcoded test unit from the scene tree if you still have it,
	# we want to spawn them dynamically now!
	if has_node("EntityContainer/BaseUnit"):
		$EntityContainer/BaseUnit.queue_free()

# basic game controls
func _input(event):
	# 1: Spawn a friendly warrior
	if event is InputEventKey and event.keycode == KEY_1 and event.pressed:
		var spawn_pos = get_global_mouse_position()
		# 1. Convert pixels to grid index (e.g., 140, 150 -> 2, 2)
		spawn_pos = map_manager.world_to_grid(spawn_pos)
		# 2. Convert grid index back to the CENTER of that tile in pixels
		spawn_pos = map_manager.grid_to_world(spawn_pos)
		spawner.spawn_entity("Warrior", spawn_pos, "friendly")
		
	# 2: Spawn an enemy warrior
	if event is InputEventKey and event.keycode == KEY_2 and event.pressed:
		var spawn_pos = get_global_mouse_position()
		spawn_pos = map_manager.world_to_grid(spawn_pos)
		spawn_pos = map_manager.grid_to_world(spawn_pos)
		spawner.spawn_entity("Warrior", spawn_pos, "enemy")
		
	# 3: Spawn a mine
	if event is InputEventKey and event.keycode == KEY_3 and event.pressed:
		var spawn_pos = get_global_mouse_position()
		spawn_pos = map_manager.world_to_grid(spawn_pos)
		spawn_pos = map_manager.grid_to_world(spawn_pos)
		spawner.spawn_entity("Mine", spawn_pos, "enemy")
		
	# LEFT CLICK: Command all moving units
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("command move")
		var target_pos = get_global_mouse_position()
		
		# System-level command: Loop through the EntityManager's tracked list
		for unit in entity_manager.actors:
			# Find the movement component dynamically
			var move_comp = unit.get_node_or_null("Components/MovementComponent")
			if move_comp:
				print("found mover")
				move_comp.path = map_manager.get_world_path(unit.global_position, target_pos)
