# stationary_behavior: for turrets. never moves; shoots the nearest visible enemy in attack range
class_name StationaryBehavior
extends Behavior

func decide(entity: Entity) -> int:
	var combat := entity.combat
	_validate_target(entity)

	if combat.has_valid_target() and not combat.can_attack(combat.target):
		combat.clear_target()
	if not combat.has_valid_target():
		combat.target = _acquire_target(entity, combat.attack_range)

	return Id.ATTACKING if combat.has_valid_target() else Id.IDLE
