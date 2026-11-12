# Using Golem in a game

Instance `res://addons/golem/player/player.tscn`. The body and the camera spring arm collide with physics layer 2 unless the instance overrides them. In this project that layer is named Environment. A floor on another layer is a floor the character will fall through. Can Climb Ledges and Can Climb Walls can be turned off on the player.

The debug HUD is part of the scene and starts hidden.

The camera captures the mouse in its `_ready`.

## Actions

The player needs input actions with these names. The keys can be whatever the game wants. The names cannot, unless you change the player too.

When the Golem plugin is enabled, the editor adds any of these names that the project does not already have, using the key listed here. A name that already exists keeps its binding.

Set on the player scene:

- `move_forward` (W), `move_backward` (S), `move_left` (A), `move_right` (D)
- `jump` (Space)
- `run` (Shift)

Written as those exact strings in the state scripts:

- `crouch` (X)
- `ragdoll` (E)

Written as those exact strings in the camera script:

- `first_person` (V), `third_person` (N), `third_aim_left` (M), `third_aim_right` (B)

Defaults on the player script, used when the scene does not override them:

- `zoom_in` (O), `zoom_out` (L)
- `fov_decrease` (I), `fov_increase` (K)
- `toggle_mouse_mode` (Y)

This project's map does define `toggle_mouse_mode` (Y). It also defines a different action named `mouse_mode` (left bracket). The player reads `toggle_mouse_mode`, not `mouse_mode`.

The map also has `pan_up`, `pan_down`, `pan_left`, `pan_right`, `aim_cam`, and `aim_cam_side`. No current player script reads those names. The plugin does not add them.

The Escape menu reads `options_menu` (Escape).

## The level

Keep the node name `Player` when the level uses `res://addons/golem/menu/golem_world.gd`. That script searches the level for that name, adds the options menu, and Escape toggles it. The menu edits the exports on that Player node. The game is not paused while the menu is open.

The character expects Godot 4.7 with the Forward Plus renderer.

A jump with a direction held speeds up to the current gait, walk or run, using that gait's ground acceleration. A jump with no direction keeps the horizontal speed you already had. Letting go of jump does not change the rise. The body climbs with jump gravity and falls with fall gravity, and a tap reaches the same height as holding the key.
