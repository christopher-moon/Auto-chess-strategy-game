# combat_component: entities with this component can deal damage to other entities
class_name CombatComponent
extends Component

var damage: float = 2.0
var attack_speed: float = 1.0
var attack_range: float = 1.0
var threat_range: float = 8.0

func initialize(dmg: float, spd: float, atk_rng: float, thrt_rng: float) -> void:
	damage = dmg
	attack_speed = spd
	attack_range = atk_rng
	threat_range = thrt_rng
