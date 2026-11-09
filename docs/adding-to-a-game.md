# Adding Golem to another game

Golem is the player scene and the scripts next to it. The test level is only a place to try the character. Leave that level, the `test/` folder, and `reports/` behind.

## What to copy

Copy the whole `player/` folder. Then copy every file the player scene points at that lives outside that folder. Those are the footstep and landing sounds in `arts/sounds/` and the label font in `arts/fonts/`. Follow the scene's external resources rather than guessing folders. If a copied scene asks for a texture or a sound, that file comes too.

Also copy these two scripts if you want the Escape menu:

- `scenes/golem_world.gd`
- `scenes/options_menu.gd`

gdUnit4, under `addons/gdUnit4/`, is the test runner. Copy it only when the other project should run Golem's tests.

Godot will import the files and keep their ids. Do not hand-edit those ids.

## Actions

The other project needs input actions with the same names the player asks for. The keys can be whatever that game wants. The names cannot, unless you change the player too.

Set on the player scene:

- `move_forward`, `move_backward`, `move_left`, `move_right`
- `jump`
- `run`

Written as those exact strings in the state scripts:

- `crouch`
- `ragdoll`

Written as those exact strings in the camera script:

- `first_person`, `third_person`, `third_aim_left`, `third_aim_right`

Defaults on the player script, used when the scene does not override them:

- `zoom_in`, `zoom_out`
- `fov_decrease`, `fov_increase`
- `toggle_mouse_mode`

This project's map does define `toggle_mouse_mode` (Y). It also defines a different action named `mouse_mode` (left bracket). The player reads `toggle_mouse_mode`, not `mouse_mode`.

The map also has `pan_up`, `pan_down`, `pan_left`, `pan_right`, `aim_cam`, and `aim_cam_side`. No current player script reads those names.

## The level

Instance `player/player.tscn` and keep the node name `Player`. The options menu searches the level for that name.

Attach `scenes/golem_world.gd` to the level root. When the level enters the tree it adds the options menu, and Escape toggles it. The menu edits the exports on that Player node. The game is not paused while the menu is open.

The player scene includes the debug HUD, so the readout shows up in the other game too. The camera captures the mouse in its `_ready`.

Put floors, walls, and stairs on physics layer 2. In this project that layer is named Environment. The body and the camera spring arm only collide with layer 2. A floor on another layer is a floor the character will fall through. Can Climb Ledges can be turned off on the player.

The character expects Godot 4.7 with the Forward Plus renderer, which is what `project.godot` asks for.

A jump with a direction held speeds up to the current gait, walk or run, using that gait's ground acceleration. A jump with no direction keeps the horizontal speed you already had. Letting go of jump does not change the rise. The body climbs with jump gravity and falls with fall gravity, and a tap reaches the same height as holding the key.

## Tests

The player tests live in `test/player/` and use gdUnit4. They are how this repo checks the camera, the landing shake, the ragdoll, and the stairs. A game that does not copy gdUnit4 does not need them.
