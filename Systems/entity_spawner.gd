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
@export var spawner_comp_scene: PackedScene
@export var projectile_comp_scene: PackedScene

# entity database
@export_category("Entity Database")
# entity resource files go here
@export var entity_library: Array[EntityData]

# behavior given to fighting units when neither the spawn call nor their data names one. AI is never tied to team
@export_category("Default Behavior")
@export var default_unit_behavior: Behavior

var world: World

var _db: Dictionary = {}
var _id_counter: int = 100

# managers
@onready var entity_container: Node2D = $"../EntityContainer"
@onready var entity_manager: EntityManager = $"../EntityManager"
@onready var map_manager: MapManager = $"../MapManager"
@onready var combat_manager: CombatManager = $"../CombatManager"
@onready var time_manager: TimeManager = $"../TimeManager"

func _ready() -> void:
	world = World.new(map_manager, entity_manager, combat_manager, self, time_manager)
	# Build the dictionary for fast lookups
	for data in entity_library:
		if data: # Safety check in case of empty array slots
			_db[data.entity_name] = data

func has_entity(entity_name: String) -> bool:
	return _db.has(entity_name)

func get_data(entity_name: String) -> EntityData:
	return _db.get(entity_name)

func spawn_entity(entity_name: String, pos: Vector2, team: Entity.Team, behavior_override: Behavior = null) -> Entity:
	var data: EntityData = _db.get(entity_name)
	if not data:
		push_error("EntitySpawner: '%s' not found in library!" % entity_name)
		return null

	# 1. Instantiate the correct Shell based on the Enum
	var entity: Entity
	match data.shell_type:
		EntityData.EntityShell.ACTOR:
			entity = actor_template.instantiate()
		EntityData.EntityShell.OBSTACLE:
			entity = obstacle_template.instantiate()
		EntityData.EntityShell.TRIGGER:
			entity = trigger_template.instantiate()

	# 2. Identity (components read world/team while configuring)
	entity.world = world
	entity.data = data
	entity.entity_name = data.entity_name
	entity.team = team
	entity.shell_type = data.shell_type
	entity.entity_id = _id_counter
	_id_counter += 1
	entity.pathing_weight = data.pathing_weight
	entity.blocks_movement = data.blocks_movement
	entity.blocks_line_of_sight = data.blocks_line_of_sight
	entity.targetable = data.targetable
	entity.position = pos
	entity.current_grid_pos = map_manager.world_to_grid(pos)
	entity.home_tile = entity.current_grid_pos

	# 3. Assign Visuals and body size
	var sprite := entity.get_node_or_null("Sprite2D") as Sprite2D
	if sprite and data.sprite_texture:
		sprite.texture = data.sprite_texture
	var collider := entity.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider and collider.shape is CircleShape2D:
		# the template's shape is shared by every instance, so each entity gets its own copy
		collider.shape = collider.shape.duplicate()
		collider.shape.radius = data.body_radius

	# 4. Add Components Additively
	var comps_folder := entity.get_node("Components")
	if data.has_health:
		entity.health = _add_component(health_comp_scene, comps_folder, entity, data)
	if data.has_movement:
		entity.movement = _add_component(move_comp_scene, comps_folder, entity, data)
	if data.has_combat:
		entity.combat = _add_component(combat_comp_scene, comps_folder, entity, data)
	if data.has_spawner:
		entity.unit_spawner = _add_component(spawner_comp_scene, comps_folder, entity, data)
	if data.has_projectile:
		entity.projectile = _add_component(projectile_comp_scene, comps_folder, entity, data)

	# 5. AI, for entities that fight: explicit behavior > data behavior > default (units that move)
	if entity.combat:
		entity.behavior = behavior_override if behavior_override else data.behavior
		if entity.behavior == null and entity.movement:
			entity.behavior = default_unit_behavior
		if entity.behavior:
			entity.state_machine = entity.get_node("StateMachine")
			entity.state_machine.setup(entity)

	# 6. Add to scene tree and register with Entity Manager
	entity_container.add_child(entity)
	entity_manager.register_entity(entity)

	return entity

# fire `projectile_name` from `shooter` towards where `target` is standing now
func spawn_projectile(projectile_name: String, shooter: Entity, target: Entity) -> Entity:
	var projectile := spawn_entity(projectile_name, shooter.global_position, shooter.team)
	if projectile == null or projectile.projectile == null:
		push_error("EntitySpawner: '%s' is not a projectile" % projectile_name)
		return projectile
	var combat := shooter.combat
	projectile.projectile.launch(target.global_position - shooter.global_position, combat.damage, combat.get_push(false), combat.stun_ticks)
	return projectile

func _add_component(scene: PackedScene, folder: Node, entity: Entity, data: EntityData) -> Component:
	var component: Component = scene.instantiate()
	folder.add_child(component)
	component.setup(entity, data)
	return component
