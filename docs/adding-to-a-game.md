# Adding Golem to another game

Golem is the addon in `addons/golem`. The test level is only a place to try the character. The `test/` folder and `reports/` stay in this repo. A game that already has gdUnit4 does not need this repo's copy.

## Install

These steps work after the addon is on `main`. From the game's repository root:

```bash
git submodule add -b main https://github.com/initsense/golem.git vendor/golem
sh vendor/golem/addons/golem/update.sh
```

`git submodule add -b main` writes `branch = main` into `.gitmodules`. The script checks out `addons/golem` only, writes an empty `vendor/.gdignore`, and creates two symlinks:

- `addons/golem` points at `vendor/golem/addons/golem`
- `.cursor/rules/use-golem.mdc` points at the rule in that folder

Commit `.gitmodules`, `vendor/.gdignore`, and both symlinks. Enable Golem under Project Settings, Plugins, then open `res://addons/golem/player/player.tscn`. If that scene is missing, `vendor/.gdignore` is hiding the symlink target. Move `vendor/` outside the Godot project folder and point the symlink at that path.

A later clone that should stay on the recorded commit runs `git submodule update --init` and then `sh addons/golem/update.sh --pin`. `--pin` sparsifies and does not fetch past the commit the game has pinned.

## Update

From the game's repository root, after a change is on `main`:

```bash
sh addons/golem/update.sh
```

That checks out the tip of `origin/main` and re-applies the sparse cone. `scenes/`, `test/`, `arts/`, and `addons/gdUnit4/` stay out of the working tree. The symlinks do not need their own update. Commit the new `vendor/golem` pointer so other clones record it. The script leaves local edits inside `vendor/golem` alone. Clear those before updating.

Godot imports the addon through the symlink. `vendor/.gdignore` keeps it from importing the same files a second time.

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

Instance `res://addons/golem/player/player.tscn`. Keep the node name `Player` when the level uses `res://addons/golem/menu/golem_world.gd`. That script searches the level for that name, adds the options menu, and Escape toggles it. The menu edits the exports on that Player node. The game is not paused while the menu is open.

The debug HUD is part of the scene and starts hidden. The camera captures the mouse in its `_ready`.

The body and the camera spring arm collide with physics layer 2 unless the instance overrides them. In this project that layer is named Environment. A floor on another layer is a floor the character will fall through. Can Climb Ledges and Can Climb Walls can be turned off on the player.

The character expects Godot 4.7 with the Forward Plus renderer, which is what `project.godot` asks for.

A jump with a direction held speeds up to the current gait, walk or run, using that gait's ground acceleration. A jump with no direction keeps the horizontal speed you already had. Letting go of jump does not change the rise. The body climbs with jump gravity and falls with fall gravity, and a tap reaches the same height as holding the key.

## Tests

The player tests live in `test/player/` and use gdUnit4. They are how this repo checks the camera, the landing shake, the ragdoll, and the stairs. They are not part of the addon checkout.
