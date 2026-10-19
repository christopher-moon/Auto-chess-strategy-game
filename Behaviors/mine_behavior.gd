# mine_behavior: waits until a hostile unit enters its tile, then explodes
class_name MineBehavior
extends Behavior

func decide(entity: Entity) -> int:
	var combat := entity.combat
	if combat.triggered_by == null:
		# also catch units that were already standing here when the mine was placed
		for other in entity.world.entities.get_entities_at_grid(entity.current_grid_pos):
			combat.on_tile_entered(other)
	if combat.triggered_by == null:
		return Id.IDLE

	combat.target = combat.triggered_by if is_instance_valid(combat.triggered_by) else entity
	return Id.ATTACKING
