# Golem

Golem is a Godot 4.7 character you can drop into a 3D level. It walks, runs, jumps, crouches, and ragdolls. The camera can sit in first person, third person, or over either shoulder. Low steps are climbed. Escape opens a menu of the player's options.

This repository is the character plus a test level, so you can try it before copying it into another game. How to do that copy is in [docs/adding-to-a-game.md](docs/adding-to-a-game.md). What changed, and when, is in [timeline.md](timeline.md).

## Try the test level

Open the project in Godot 4.7 and run it. The mouse is captured when the player is ready. The keys below are the ones in this project's input map.

- W A S D move
- Space jump. A tap and a held press reach the same height. Hold a direction and the jump speeds up to your walk or run speed, even if you only just started moving
- Shift run
- X crouch
- E ragdoll, and E again to stand up
- V first person, N third person, M aim left, B aim right
- Y show or capture the mouse
- O and L zoom the third-person camera
- I and K change the field of view
- Escape opens and closes the options menu

The debug readout in the corner is part of the player scene. It shows the current state and a few movement numbers.

Floors and walls in the test level are on physics layer 2, Environment. The body does not collide with other layers.
