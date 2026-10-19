# debug_overlay: draws each unit's current target and attack range on top of the map
class_name DebugOverlay
extends Node2D

var entity_manager: EntityManager

func _ready() -> void:
	z_index = 100

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if entity_manager == null:
		return
	var tile_size := entity_manager.map_manager.tile_size
	for list in [entity_manager.actors, entity_manager.obstacles]:
		for e: Entity in list:
			if e.combat == null:
				continue
			var color: Color = Entity.TEAM_COLORS[e.team]
			if e.combat.has_valid_target():
				draw_line(e.global_position, e.combat.target.global_position, color, 2.0)
			draw_arc(e.global_position, e.combat.attack_range * tile_size, 0.0, TAU, 32, Color(color, 0.35), 1.0)
