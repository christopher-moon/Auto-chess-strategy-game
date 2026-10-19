# health component: entities with this component have health and can take damage
class_name HealthComponent
extends Component

signal health_changed(current: float, maximum: float)

var max_health: float = 10.0
var current_health: float = 10.0

func _configure(data: EntityData) -> void:
	max_health = data.max_health
	current_health = data.max_health

# only the CombatManager calls this, while resolving a tick. death is handled there too,
# after every hit of the tick has landed, so units that hit each other on the same tick can trade
func apply_damage(amount: float) -> void:
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)

func is_depleted() -> bool:
	return current_health <= 0.0
