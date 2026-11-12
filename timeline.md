# Timeline

Oldest first. Each entry is a group of commits, and it only says what those commits actually changed.

## 2025-05-24 — The repo and a first character

`a02f697` adds the MIT license and a Godot gitignore.

`a02c0d3` ("a doll is born") adds a player scene, a world scene, and the start of a state machine: idle, walk, crouch, jump, and sprint. Most of those state scripts are empty. The real movement at this point lives in `player_old.gd`. A sky texture and a glasses model come along.

`17baef9` moves the scripts into a `state_machine` folder and adds a state machine that can change state. `scripts/utils/stairs.gd` is a `Stairs` class whose `check_step` does nothing.

`4d434bb` gives the player a speed, a gravity, and a jump impulse, and rewrites the state machine and the idle state. The commit message says it is not really a feature.

## 2025-05-25 — The plush first-person character

`e7a63da` brings in the Godot plush model, its shader, footstep sounds, the debug HUD, and the player character that the rest of the project grows from. The old world scene is no longer the center of the game.

## 2025-05-26 — First person and a jump tweak

`b890f14` adds a way to switch into first person. The commit message names the F key. The current input map uses V for `first_person`.

`ea1cc5f` is a small edit to the player scene and the particle manager.

## 2025-05-27 to 2025-05-28 — Camera modes and speed-based head bob

`d5d9f9e`, `6967f67`, `bbc0405`, and `15e7c47` build the switch between first person, third person, and the over-the-shoulder aim views.

`53910d2` ties head bob to how fast the body is moving.

## 2025-06-02 to 2025-06-09 — Camera, gravity, and the folder move

`87e8620` continues the head bob.

`1bfc831` adds field-of-view control on I and K.

`596a15b` edits the orbit camera and the test map, widens the window, and names the 3D physics layers: Player, Environment, and Camera. Default gravity in the project is 16.

`073b0ae` fixes the spring arm and keeps head bob working in the air.

`ee0ea47` moves the project to Godot 4.5 dev 5.

`5d74329` stops the movement particles while the camera is in first person.

`00b8167` moves the character out of `addons/` into `player/`, moves art into `arts/`, and renames the test map to `scenes/test_level.tscn`. Older player scenes go under `scenes/deprecated/`.

`446f7fa` and `64627cb` split jump gravity from fall gravity and rename the gravity functions.

`6780ef2` turns head bob off while idle.

## 2025-06-15 to 2025-06-21 — Crouch

`29f98e3` changes speed while crouched.

`38f80bc` is a code cleanup in the same area.

`701e3fe` continues the crouch work. The commit message is "croucho marx".

## 2025-06-29 — Tilt, field of view, and landing shake

`0e9d4d3` adds camera tilt.

`e99ce93` widens the field of view while walking and running.

`960198e` limits tilt to first person.

`4ad3fcc` shakes the camera when a jump or a fall lands.

## 2025-07-01 to 2025-07-02 — Camera script

`d77a39a` reworks the camera holder. The message calls it a performance pass and marks it work in progress.

`08bcf56` shortens that same camera script.

## 2025-08-07 — Jump defaults

`f1b7f5a` sets extra mid-air jumps to 0 and gives coyote time a default of 0.2 seconds. The soft part of the landing uses a quarter of fall gravity instead of a sixth. The project feature tag is set to Godot 4.4. A commented shake check is left in the camera script.

## 2026-11-07 — Head bob fade

`7ccfe79` adds fade-in and fade-out times for head bob, updates the Godot feature tag again, refreshes some texture import settings, and adds a VS Code settings file.

## 2026-11-08 — Tests, the options menu, and stairs

`0cdcf16` vendors gdUnit4 and points the test lookup folder at `test/`.

`cfedd76` adds the Escape options menu. `scenes/golem_world.gd` attaches it to the test level.

`2cf372c` adds stair stepping. Before each slide, a short motion test climbs a low step and settles down a low drop. The camera eases over the snap. The test level gets a short flight of steps and a wall that is too tall to climb. A gdUnit scene test checks the step, the wall, and a jump. The same commit ignores gdUnit's `reports/` folder.

## 2026-11-08 — Timeline, guide, and rules

`timeline.md` records the history above. `README.md` explains the test level, and `docs/adding-to-a-game.md` explains how to copy the character into another Godot project. Cursor rules now ask for a timeline entry when behavior changes, a doc update when the setup changes, and a green player test suite for a behavior change.

## 2026-11-08 — A directed jump carries the gait speed

Air speed no longer comes from curves sampled off the current horizontal speed. Those curves were zero at rest, so a jump at the start of a step stayed short. Holding a direction in the air now steers toward walk speed or run speed, using that gait's ground acceleration. No direction leaves horizontal speed alone. The air-curve test is replaced by one that checks both cases.

## 2026-11-09 — One jump arc

Releasing jump no longer doubles the rise gravity or switches to the fall pose while the body is still going up. The rise uses jump gravity and the fall uses fall gravity, including the first meter per second of the drop, which used a quarter of fall gravity. A tap and a held press reach the same height.

## 2026-11-09 — Crouch blocks sprint

The run key does nothing while crouched, and crouching clears a run that was already toggled on. A jump that starts crouched stands the body up at takeoff, camera included, so the view is already standing before the landing.

## 2026-11-09 — Jump ledge climb

A jump that reaches a low ledge hops onto it. Pressing jump, or moving away from the face, leaves that climb. Walking into the face still stops. Escape can turn Ledges off. Stair-sized rises stay with the stairs, and a ramp no longer counts as a step.

## 2026-11-09 — Ledge hop has more room

The hop starts when the lip is still up to the Ledges max height above the feet, so a jump that gets near the ledge climbs without having to brush it. The default max height is 1.5 m. Turning Ledges off stops the hop.

## 2026-11-09 — Checkbox labels start with Can

Every checkbox in the Escape menu starts with Can. The stair and ledge checks read Can Climb Stairs and Can Climb Ledges.

## 2026-11-09 — Inspector checks start with Can

The same checks use those names in the Godot inspector. A stair check is can_climb_stairs, shown as Can Climb Stairs. A ledge check is can_climb_ledges, shown as Can Climb Ledges. The other checks were renamed the same way, so the inspector and the Escape menu match.

## 2026-11-09 — Decaying wall climb

A jump into a wall climbs for a short time, then the lift fades. That extra height can bring a lip into reach for the ledge hop. Walking into a wall does not climb. Escape can turn off Can Climb Walls.

## 2026-11-12 — Golem is an addon

The character, its sounds and font, and the Escape menu scripts live in `addons/golem`. Another game tracks `main` as a submodule at `vendor/golem` and updates it with `sh addons/golem/update.sh`. The debug HUD starts hidden. Global state class names are prefixed with Golem. The state node names are unchanged.

## 2026-11-12 — Head bob follows the step

The first-person step uses a walk, run, or crouch rate and distance, and the view eases toward that step. Letting go freezes the step and eases the view home. A strength scale quiets every gait.

## 2026-11-12 — Slide, wall run, vault, and a speed-based view

The first-person view can widen with speed, lean when the mouse turns, and pick up a little noise. Crouching during a fast run slides. A side wall can be run and jumped off, and the head-on climb stays. A run into a mid-height block vaults onto the far top. Each of those has a Can check. The head bob, this view, the slide, the wall run, and the vault are adapted from the NOSHOT controller by theRealUnd3rdog (MIT, https://github.com/theRealUnd3rdog/Godot_Noshot_Controller).
