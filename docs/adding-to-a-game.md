# Adding Golem to another game

Drag the `addons/golem` folder into the game's `addons/` directory. It has to end up as `res://addons/golem`. Leave `test/` and this repo's gdUnit4 behind. A game that already has gdUnit4 does not need this repo's copy.

There is no `plugin.cfg`. Do not enable Golem under Project Settings, Plugins.

Drag `res://addons/golem/player/player.tscn` into a level. The player adds any missing input actions when it enters the tree, using the keys listed below. An action the project already has keeps its binding. Nothing is written back to the project. To use a different key, add that action in the game's input map before running.

A floor the body should stand on is physics layer 2. In this project that layer is named Environment. A floor on another layer is a floor the character will fall through.

For the Escape menu, attach `res://addons/golem/menu/golem_world.gd` to the level and name the player node `Player`. That script searches the level for that name, adds the options menu, and Escape toggles it. The menu edits the exports on that Player node. The game is not paused while the menu is open.

## Actions

The player needs input actions with these names. The keys can be whatever the game wants. The names cannot, unless you change the player too.

The player adds any of these names that the project does not already have, using the key listed here.

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

The map also has `pan_up`, `pan_down`, `pan_left`, `pan_right`, `aim_cam`, and `aim_cam_side`. No current player script reads those names. The player does not add them.

The Escape menu reads `options_menu` (Escape).

## The level

The debug HUD is part of the scene and starts hidden. The camera captures the mouse in its `_ready`.

The body and the camera spring arm collide with physics layer 2 unless the instance overrides them. Can Climb Ledges, Can Climb Walls, Can Wall Run, Can Vault, Can Slide, Can Speed Fov, Can Turn Lean, and Can View Noise can be turned off on the player.

The head bob, the speed-based view, the slide, the side wall run, and the vault are adapted from the [NOSHOT first-person controller](https://github.com/theRealUnd3rdog/Godot_Noshot_Controller) by [theRealUnd3rdog](https://github.com/theRealUnd3rdog). That project is MIT, Copyright (c) 2023 theRealUnd3rdog. Keep this credit with the player when you copy Golem into another game.

The character expects Godot 4.7 with the Forward Plus renderer, which is what `project.godot` asks for.

A jump with a direction held speeds up to the current gait, walk or run, using that gait's ground acceleration. A jump with no direction keeps the horizontal speed you already had. Letting go of jump does not change the rise. The body climbs with jump gravity and falls with fall gravity, and a tap reaches the same height as holding the key.

Crouching during a walk ignores the run key. Crouching during a sprint that is already at slide speed starts a slide. Letting go of `run` does not stop that slide. It ends crouched, in the walk. Can Slide turns this off, and a crouch during a run then cancels the run. A jump straight into a wall still does the short climb. Running along a side wall starts a wall run, and `jump` pushes off that wall. Can Wall Run turns the side run off. Running into a block taller than a step and no taller than the vault height carries the body onto the far top. Walking into that block stops. Can Vault turns the vault off. Can Speed Fov, Can Turn Lean, and Can View Noise turn off the speed widen, the mouse-turn roll, and the small speed noise. The I and K field-of-view keys stay either way.

## Tests

The player tests live in `test/player/` and use gdUnit4. They are how this repo checks the camera, the landing shake, the ragdoll, and the stairs. They are not part of the folder you drag into another game.
