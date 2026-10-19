#entity_spawner: entity "factory", in charge of instantiating scenes, and registering to entity manager
class_name EntitySpawner
extends Node

# entity "shells"
@export_category("Base Templates")
@export var actor_template: PackedScene
@export var obstacle_template: PackedScene
@export var trigger_template: PackedScene

# entity components
@export_category("Component Scenes")
@export var health_comp_scene: PackedScene
@export var move_comp_scene: PackedScene
@export var combat_comp_scene: PackedScene

# entity database
@export_category("Entity Database")
# entity resource files go here
@export var entity_library: Array[EntityData]

var _db: Dictionary = {}
var _id_counter: int = 100

# managers
@onready var entity_container: Node2D = $"../EntityContainer"
@onready var entity_manager: EntityManager = $"../EntityManager"
@onready var map_manager: MapManager = $"../MapManager"

func _ready() -> void:
	# Build the dictionary for fast lookups
	for data in entity_library:
		if data: # Safety check in case of empty array slots
			_db[data.entity_name] = data

func spawn_entity(entity_name: String, pos: Vector2, team: String) -> Node2D:
	var data: EntityData = _db.get(entity_name)
	if not data: 
		push_error("EntitySpawner: '%s' not found in library!" % entity_name)
		return null

	# 1. Instantiate the correct Shell based on the Enum
	var entity: Node2D
	match data.shell_type:
		EntityData.EntityShell.ACTOR: 
			entity = actor_template.instantiate()
		EntityData.EntityShell.OBSTACLE: 
			entity = obstacle_template.instantiate()
		EntityData.EntityShell.TRIGGER: 
			entity = trigger_template.instantiate()
	
	entity.global_position = pos

	# 2. Assign Visuals
	var sprite = entity.get_node_or_null("Sprite2D")
	if sprite and data.sprite_texture: 
		sprite.texture = data.sprite_texture

	# 3. Add Components Additively
	var comps_folder = entity.get_node("Components")
	
	if data.has_health:
		var h = health_comp_scene.instantiate()
		comps_folder.add_child(h)
		h.setup(entity)
		h.initialize(data.max_health)

	if data.has_movement:
		var m = move_comp_scene.instantiate()
		comps_folder.add_child(m)
		m.setup(entity)
		m.speed = data.move_speed
		
	if data.has_combat:
		var c = combat_comp_scene.instantiate()
		comps_folder.add_child(c)
		c.setup(entity)
		c.initialize(data.damage, data.attack_speed, data.attack_range, data.threat_range)

	# 4. Finalize Identity (Already in the template)
	entity.entity_name = data.entity_name
	entity.team = team
	entity.shell_type = data.shell_type
	entity.entity_id = _id_counter
	_id_counter += 1
	entity.pathing_weight = data.pathing_weight
	
	# 5. Add to scene tree and register with Entity Manager
	entity_container.add_child(entity)
	var grid_pos = map_manager.world_to_grid(pos)
	entity.current_grid_pos = Vector2(grid_pos)
	
	entity_manager.register_entity(entity)

	return entity
