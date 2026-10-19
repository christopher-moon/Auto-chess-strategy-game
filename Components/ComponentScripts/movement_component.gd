# movement component: entities with this component can move around the map when assigned paths
class_name MovementComponent
extends Component

var speed: float = 100.0
var path: PackedVector2Array = []

# movement component needs to reference the entity manager and map manager
@onready var entity_manager: EntityManager = get_tree().current_scene.get_node("EntityManager")
@onready var map_manager: MapManager = get_tree().current_scene.get_node("MapManager")

func _physics_process(_delta: float) -> void:
	
	if path.is_empty():
		return
		
	
		
	if entity is CharacterBody2D:
		if path.is_empty():
			entity.velocity = Vector2.ZERO
			return
		
		var target_position = path[0]
		var direction = (target_position - entity.global_position).normalized()
		
		entity.velocity = direction * speed
		entity.move_and_slide()	
			
		if entity.global_position.distance_to(target_position) < 5.0:
			path.remove_at(0)
			
		# Compare the current world coordinate map location against the Entity's property
		var current_grid_pos = Vector2(map_manager.world_to_grid(entity.global_position))
		if current_grid_pos != entity.current_grid_pos:
			# Tell the manager to shift it to the new coordinate
			entity_manager.update_entity_grid_position(entity, current_grid_pos)
