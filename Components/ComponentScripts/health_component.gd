# health component: entities with this component have health and can take damage
class_name HealthComponent
extends Component

var max_health: float = 10.0
var current_health: float = 10.0

func initialize(max_hp: float) -> void:
	max_health = max_hp
	current_health = max_hp
