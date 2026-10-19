# base_entity: defines the general entity class, which all game entities fall into
class_name Entity
extends Node2D

enum Team {NEUTRAL, PLAYER, ENEMY}

const TEAM_COLORS := {
	Team.NEUTRAL: Color.WHITE,
	Team.PLAYER: Color(0.55, 0.75, 1.0),
	Team.ENEMY: Color(1.0, 0.5, 0.5),
}

# shared toggle for every entity's debug label (H in the test scene)
static var show_debug_labels: bool = true

signal died(entity: Entity)

@onready var debug_label: Label = get_node_or_null("DebugLabel")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

# references to the level's managers, injected by the spawner
var world: World
var data: EntityData

# universal identifiers:
var entity_id: int
var entity_name: String
var team: Team = Team.NEUTRAL
var shell_type: EntityData.EntityShell

# components (null when this entity doesn't have one), filled in by the spawner
var health: HealthComponent
var movement: MovementComponent
var combat: CombatComponent
var unit_spawner: SpawnerComponent
var projectile: ProjectileComponent

# AI: only entities with a behavior get a running state machine
var behavior: Behavior
var state_machine: StateMachine

# pathfinding and spatial location
var current_grid_pos: Vector2i
var pathing_weight: float = 1.0
var blocks_movement: bool = false
var blocks_line_of_sight: bool = false
var targetable: bool = true
# where the unit was spawned. defenders return here when out of combat
var home_tile: Vector2i

# status
var is_alive: bool = true
var stun_ticks: int = 0
var ticks_alive: int = 0

func _ready() -> void:
	if sprite:
		sprite.modulate = TEAM_COLORS[team] if data == null or data.tint_by_team else Color.WHITE
		if data:
			sprite.scale = Vector2.ONE * data.sprite_scale
	refresh_debug_label()

# called by the EntityManager once per AI tick
func tick() -> void:
	ticks_alive += 1
	if combat:
		combat.tick_cooldown()
	if unit_spawner:
		unit_spawner.tick()
	if state_machine:
		state_machine.tick()
	refresh_debug_label()

func is_hostile_to(other: Entity) -> bool:
	return team != Team.NEUTRAL and other.team != Team.NEUTRAL and team != other.team

func is_stunned() -> bool:
	return stun_ticks > 0

# stun stops moving and attacking, and makes the unit forget its target
func apply_stun(ticks: int) -> void:
	if ticks <= 0 or state_machine == null:
		return
	stun_ticks = maxi(stun_ticks, ticks)
	if combat:
		combat.clear_target()
	if movement:
		movement.stop()

# the label is refreshed on ticks rather than every frame
func refresh_debug_label() -> void:
	if not debug_label:
		return
	debug_label.visible = show_debug_labels
	if not show_debug_labels:
		return

	var text := "[%s] %s" % [entity_id, entity_name]
	if health:
		text += "\nHP: %s/%s" % [snappedf(health.current_health, 0.1), health.max_health]
	if state_machine:
		text += "\n%s" % state_machine.get_state_name()
	debug_label.text = text
