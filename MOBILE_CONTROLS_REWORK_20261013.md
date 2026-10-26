# Mobile Controls Repair — 2026-10-13

## Scope and safety
- Gameplay code changed: `MobileControls.gd` only.
- Safety copy before this repair: `backup/MobileControls_before_precise_button_restore_20261013.gd`.
- Scene files, `Player.gd`, `PlayerInteractionInput.gd`, `ItemInventory.gd`, `UIManager.gd`, teacher AI, and map files were not edited by this repair.
- The previous backup `MobileControls.gd.before_input_debug_fix_20261013.bak` was used as the source for the existing hand-sketched `SketchActionButton` drawing class.

## Changes made
1. Restored `SketchActionButton` and reused it for action buttons, communication buttons, and inventory slots so the hand-drawn button style is preserved.
2. Kept the current HUD anchors/positions and existing button callback connections; this repair did not copy the older layout wholesale.
3. Removed the new standard rounded style backgrounds from the custom-drawn trash, communication, action, and inventory buttons.
4. Set run/crouch captions to match the drawing logic (`LARI`, `LARI: ON/OFF`, `JONGKOK`, `JONGKOK: ON`) so the icons can be drawn consistently.
5. Set the inventory-slot container mouse filter to PASS so it does not unnecessarily suppress input to its child buttons.
6. Kept contextual interaction press/release wiring; it calls `mobile_interact/mobile_stop_interact` and `mobile_heal/mobile_stop_heal`.
7. Kept the real menu and settings owned by `UIManager.gd`; no duplicate menu was added to `MobileControls.gd`.

## Expected behavior
- The project setting `show_touch_hud_on_desktop = true` shows the HUD while running the game from the desktop for preview.
- The original hand-drawn button silhouettes/icons remain; the existing placement is retained.
- Joystick controls movement; LOMPAT requests a jump; LARI/JONGKOK toggle player movement states.
- INTERAKSI and SEMBUHKAN start on press and stop on release; SEMBUNYI uses the mobile hide handler.
- Inventory slots 1 and 2 select the matching item; the bin button calls the existing inventory drop method.
- SPK toggles voice playback mute; MIC and CHAT provide a notice when multiplayer communication is unavailable.
- The separate UIManager menu and SETTING panel continue to be the authoritative pause/settings UI.

## Verification
- Godot 4.7.2 headless editor scan: exit code 0; no GDScript parse errors were found.
- Headless main-scene boot: exit code 0; no GDScript runtime errors were found. Forced headless shutdown printed RID/ObjectDB leak warnings, so this is not treated as a clean visual-runtime test.
- Temporary SceneTree probe: 0 assertion failures. It instantiated `player.tscn`, confirmed HUD and all expected control nodes exist, exercised jump/run/crouch, interaction/heal press-release callbacks, inventory slot selection, SPK/MIC/CHAT responses, and confirmed the UIManager menu and SETTING callbacks open their panels.
- A separate synthetic mouse-position click probe did not activate GUI buttons in the headless SceneTree harness; this is not accepted as proof of a real mouse/touch click test because the harness has no normal interactive game window.
- Physical touchscreen/mouse acceptance is still unverified in a visible game window. Before claiming complete end-to-end success, run the game with F5 and click/tap each visible button, including menu and SETTING; also test move + look simultaneously and release-based interactions.

## Reference principles
- Granny controls reference: https://granny.fandom.com/wiki/Controls_%26_Symbols
- Godot touch input reference: https://docs.godotengine.org/en/4.4/classes/class_touchscreenbutton.html
