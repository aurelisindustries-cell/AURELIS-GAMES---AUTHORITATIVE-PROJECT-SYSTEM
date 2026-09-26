# AI Components

`AIRoot` owns the Memory Bank and ticks its `AINode` children from top to bottom. AI nodes return `SUCCES`, `FAILURE`, or `ACTIVE`.

## Node families

- `Flows/Fallback`: runs children until one succeeds.
- `Flows/StepSequence`: runs children until one fails.
- `Flows/Simultaneous`: ticks every child together.
- `Sensors`: immediate checks that may read or write Memory Bank values.
- `Tasks`: ongoing or immediate behaviors.
- `Filters`: single-child behavior modifiers.

## Included nodes

- Sensors: Find Target, Distance to Target, Health Below, Memory Exists.
- Tasks: Move to Target, Patrol Between Points, Face Target, Request Action, Set Memory, Wait.
- Filters: Cooldown, Inverter, Repeat.

`NavigationPoint2D` is a draggable scene marker. Assign two of them to a `PatrolBetweenPoints` task to make an enemy alternate between those locations. `Enemies/patrol_enemy.tscn` is ready to place and exposes both markers directly in its scene.

## Creating another node

Extend `AINode` and override `tick(delta)`. Return `ExecutionSignal.ACTIVE` while work continues. Read shared values with `memory_get()` and write them with `memory_set()`.

AI decisions should emit `AIRoot.task_requested` when another component must perform combat, animation, audio, or another authored system. This keeps decision logic separate from the enemy's movement and combat components.
