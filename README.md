# Golem

Golem is a Godot 4.7 character you can drop into a 3D level. It walks, runs, jumps, crouches, and ragdolls. The camera can sit in first person, third person, or over either shoulder. Low steps are climbed. Escape opens a menu of the player's options.

The head bob, the speed-based view, the slide, the side wall run, and the vault are adapted from the [NOSHOT first-person controller](https://github.com/theRealUnd3rdog/Godot_Noshot_Controller) by [theRealUnd3rdog](https://github.com/theRealUnd3rdog). That project is MIT, Copyright (c) 2023 theRealUnd3rdog.

This repository is the character plus a test level, so you can try it before adding it to another game. The character lives in `addons/golem`. How to track that folder from another project is in [docs/adding-to-a-game.md](docs/adding-to-a-game.md). What changed, and when, is in [timeline.md](timeline.md).

## Try the test level

Open the project in Godot 4.7 and run it. The mouse is captured when the player is ready. The keys below are the ones in this project's input map.

- W A S D move
- Space jump. A tap and a held press reach the same height. Hold a direction and the jump speeds up to your walk or run speed, even if you only just started moving. A jump that reaches a low ledge hops onto it. Jump again, or push away from the face, and you leave that climb. A jump into a wall climbs a little and then fades, which can be enough to reach a ledge. Running along a side wall runs on that wall, and jump pushes off it. The Escape menu can turn off Can Climb Ledges, Can Climb Walls, and Can Wall Run
- Shift run. Hold it to sprint. Crouching from a walk ignores the run key. Crouching while that sprint is already up to speed starts a slide that keeps going after you let go of Shift, then leaves you crouched. Can Slide turns the slide off, and a crouch during a run then cancels the run. Running into a block taller than a step vaults over it. Walking into that block stops. Can Vault turns the vault off
- X crouch. A jump that starts crouched stands you up as you leave the ground, so the camera is up before you land
- E ragdoll, and E again to stand up
- V first person, N third person, M aim left, B aim right
- Y show or capture the mouse
- O and L zoom the third-person camera
- I and K change the field of view. Can Speed Fov makes the view widen with speed instead of the flat walk and run bonuses. Can Turn Lean rolls the view a little when you turn the mouse while moving. Can View Noise adds a small shake that grows with speed and is larger in the air. Each one can be turned off in the Escape menu
- Escape opens and closes the options menu

The debug readout is part of the player scene and starts hidden. It can show the current state and a few movement numbers when that layer is turned visible.

Floors and walls in the test level are on physics layer 2, Environment. The body does not collide with other layers.
