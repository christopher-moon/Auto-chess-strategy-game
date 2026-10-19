# base_entity: defines the general entity class, which all game entities fall into
class_name Entity
extends Node2D

@onready var debug_label: Label = $DebugLabel
@onready var health = get_node_or_null("Components/HealthComponent")

# universal identifiers:
var entity_id: int
var entity_name: String
var team: String
var shell_type: EntityData.EntityShell

# pathfinding and spatial location 
var current_grid_pos: Vector2
var pathing_weight: float

func _process(_delta: float) -> void:
	if not debug_label: return
	
	var text = "[%s] %s\nTeam: %s" % [entity_id, entity_name, team]
	if health:
		text += "\nHP: %s/%s" % [health.current_health, health.max_health]
		
	debug_label.text = text
