# Engine architecture

## The tick

Logic runs on a fixed 0.2s tick (`TimeManager.tick_rate`). Movement, projectiles and (later) animation run every frame.

Each tick runs in this order:

1. **Think and act.** `EntityManager.process_ai_tick()` calls `Entity.tick()` on every entity. Units pick a state and act, but attacks only *queue* hits.
2. **Resolve.** `CombatManager.resolve()` applies every queued hit at once: first damage, then stun and push for survivors, then deaths. Two units that hit each other on the same tick both die (trading).
3. **React.** `TimeManager.on_global_tick` fires, and `LevelManager` updates the timer and capture progress.

Projectile impacts happen during frames, but their hits are queued the same way and land on the next resolve.

## Entities

An entity is a shell scene (`Entities/actor.tscn`, `obstacle.tscn`, `trigger.tscn`) plus components, built by `EntitySpawner` from an `EntityData` resource (`Entities/EntityData/*.tres`). Each component reads its own stats from the data in `_configure()`.

| Entity | Components | Notes |
|---|---|---|
| Melee | health, movement, combat | |
| Ranged | health, movement, combat | fires `Arrow` |
| Arrow | projectile | flies straight; hits the first hostile, or a box |
| Mine | health, combat (explode) | path weight 50; explodes when a hostile unit enters its tile |
| Turret | health, combat | blocks movement; stationary behavior |
| Spawner | health, spawner | spawns its team's units on a timer, up to a max count |
| Box | health | blocks movement and sight, not pathfinding (weight 20) |
| Brute | health, movement, combat | heavy melee (mass 3): slow to start, shoves others, knockback 2 |

To add an entity, make a new `EntityData` .tres and add it to `EntitySpawner.entity_library` in `game.tscn`.

`Systems/world.gd` holds references to the managers and is injected into every entity, so components never search the scene tree.

## Physical movement

Units (actors) are `CharacterBody2D` circles (`body_radius`) with their own velocity. The AI still picks a goal tile on ticks and A* still makes the tile path; every physics frame the `MovementComponent` steers towards the next waypoint:

- acceleration = `move_force / mass`, top speed = `move_speed / sqrt(mass)`, and `friction` slows a unit down when it isn't pushing
- `move_and_slide()` handles collisions with walls, holes and the map edge (`MapManager` builds a static collider per solid tile), structures and other units
- walking into another unit shoves it by `mass / (your mass + their mass)`, so heavy units plough through light ones
- a light separation force spreads crowds out so they don't jam
- paths are 8-way, but a diagonal step never clips the corner of a wall or a pricey tile (mine, box); waypoints are string-pulled (up to 4 tiles ahead), so units walk straight across open ground
- periodic re-paths are spread over different ticks per unit, so a big wave doesn't path all on the same frame

### Knockback

A hit adds a push to the target's velocity: `velocity += direction × push / target mass`, and friction bleeds it off. Walls and other bodies stop it through normal collisions.

Pushes never snowball:
- all pushes a unit takes in one tick combine into one, no stronger than the strongest of them, so three attackers knock a unit back no harder than one (hits from opposite sides cancel out)
- a push never leaves a unit faster than that push alone would, or than it was already moving, so hits in a row don't stack into a launch

`push = damage × push_per_damage + knockback_bonus`, and melee blows also add the attacker's own pushing force, `mass × acceleration × push_per_force`. `push_per_damage` and `push_per_force` are on the CombatManager node; `knockback_bonus` is per unit (negative for weaker shoves).

`recoil` (per unit) is a set push the attacker takes away from its target with every attack, applied with the tick's other hits. Ranged units use it for a bow's kick.

### Fighting on the move

With `charge_while_attacking` on (the default, used by Melee and Brute), a unit in the Attacking state runs straight at its target at full speed and bumps into it, then stays in contact, closing in again whenever a hit knocks the target back. With it off (Ranged), the unit holds the tile it started shooting from; if recoil or a shove knocks it off, it steps back on.

Units no longer stop exactly on tile centres; the tile a unit is "on" is the tile under its centre. Try the Brute (key 7, mass 3) against Melee units to see weight at work.

## AI: behaviors and states

A unit has exactly one active state (`States/`): **Idle**, **Moving**, **Attacking** or **Stunned**. Each tick, its **behavior** (`Behaviors/`) picks the state, and the `StateMachine` switches and runs it.

- **Attacker**: fights any visible enemy in threat range. With nobody in sight, it walks to the cheapest objective tile.
- **Defender**: guards its home tile (`Entity.home_tile`, the tile it spawned on). It only fights from tiles within `leash_range` tiles of home, and walks back home whenever it is out of combat.
- **Stationary** (turrets): shoots the nearest visible enemy in range.
- **Mine**: explodes once triggered.

Behaviors are shared resources, so they keep no per-unit data. The target lives on `CombatComponent.target`, and the goal tile lives on `MovementComponent.goal_tile`. A target is held until it dies or is obscured, or until a stun clears it. Units walk to the first tile on the cheapest path that is in range of the target, not to the target's own tile. If a box or a structure blocks the path, they break through it.

For a new behavior (patrol, for example), extend `Behavior` and override `decide()`.

AI is never tied to team; either side can use any behavior. A unit's AI comes from, in order: the `behavior` passed to `spawn_entity` (a card or the debug controls), the `behavior` in its data, or the spawner's `default_unit_behavior` (Attacker). A Spawner's units use its data's `spawn_behavior` when set.

## Map

`MapManager` owns three `TileMapLayer`s: Ground, Obstacle (walls) and Objective. Walls, holes and off-map tiles are solid for A*. Entities add weight to their tile (`pathing_weight`), so paths avoid mines and boxes unless there is no other way. Line of sight checks walls and entities with `blocks_line_of_sight`. It can be switched off globally (`line_of_sight_enabled`) or per unit (`requires_line_of_sight`).

## Debug controls (game.tscn)

`1` Melee, `2` Ranged, `3` Mine, `4` Turret, `5` Spawner, `6` Box, `7` Brute (all at the mouse tile)
`Tab` switch team · `A` switch the AI placed units get (Attacker / Defender) · `W` toggle wall · `O` toggle objective tile · `X` delete · `S` stun
`L` line of sight · `H` debug labels and lines · `Space` pause · `R` restart

The level timer starts when the first Player unit is placed. The level is won by holding the zone uncontested for 5s. It is lost when time runs out or every Player unit dies.

## Tests

```
godot --headless --fixed-fps 60 --script res://Tests/engine_tests.gd
```

The tests cover trading, ranged units holding at range and recoiling, melee charging, knockback not stacking, defenders returning home, AI not tied to team, line of sight, mines, boxes, knockback, stun, spawner caps, capture, the defender leash, and the physics (inertia by mass, units taking up space, shoving, wall collisions).
