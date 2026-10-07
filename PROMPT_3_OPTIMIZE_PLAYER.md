# Prompt 3: Optimize Player.gd & Inventory System

**Use this prompt with ChatGPT to optimize player movement, stamina, and inventory management**

---

## CONTEXT

You are a professional Godot 4.7.2 gameplay programmer. I need you to review and optimize the Player script to ensure smooth movement, proper stamina management, and functional inventory system.

**Project**: Map58 School Horror Game (Godot 4.7.2)  
**Script**: Player.gd (player controller)  
**Current State**: Functional but needs cleanup and optimization  
**Target**: Production-ready player controller with responsive movement and inventory  
**Success Metric**: Smooth 30-60 FPS movement, accurate stamina, inventory pickup working

---

## PLAYER MOVEMENT REQUIREMENTS

### Basic Movement
- **Speed**: 15.0 units/sec (normal walk)
- **Run Speed**: 10.0 units/sec (faster movement)
- **Crouch Speed**: 2.5 units/sec (slow, stealthy)
- **Jump Velocity**: 4.5 units/sec (vertical boost)
- **Gravity**: 9.8 units/sec² (fall acceleration)

### Movement States
- **Normal Walk**: WASD keys, 15.0 u/s
- **Running**: SHIFT + WASD, 10.0 u/s, consumes stamina
- **Crouching**: CTRL + WASD, 2.5 u/s, silent movement
- **Jumping**: SPACE (only when on floor, not while crouch)

### Camera Control
- **Mouse Look**: Free mouse movement rotates camera
- **Mouse Sensitivity**: 0.003 (adjustable)
- **Camera Height (Standing)**: 1.6 units
- **Camera Height (Crouching)**: 0.9 units
- **Camera smoothing**: Lerp between standing/crouch height

### Footsteps
- **Walk**: 0.43 second interval, -7.0 volume, 1.0 pitch
- **Run**: 0.30 second interval, -5.0 volume, 1.04 pitch
- **Crouch**: 0.58 second interval, -9.0 volume, 0.94 pitch
- Footsteps only play when on floor and moving
- Call audio system: `audio.play_footstep(volume, pitch)`

---

## STAMINA SYSTEM

### Stamina Rules
- **Max Stamina**: 5.0 units (adjustable via @export)
- **Initial Stamina**: 5.0 (full at start)
- **Recovery Speed**: 1.0 units/sec (when not running)
- **Drain Speed**: 1.0 units/sec (when running)

### Running Logic
- Can only run if: SHIFT pressed + NOT crouching + moving input active
- Running consumes stamina each frame
- If stamina reaches 0: Enter exhausted state (cannot run)
- Exhausted state continues until stamina fully recovers to max
- Stamina bar shows current / max stamina as percentage

### Stamina UI Display
- Show "STAMINA X%" at bottom center of screen
- Stamina bar visual (ProgressBar node)
- Updates every frame to show current stamina
- Color could change when exhausted (optional enhancement)

---

## INVENTORY SYSTEM

### Inventory Capacity
- **Max items**: 5 items per player
- **Item types**: paper, chalk, key, medkit, flashlight, noise-maker
- **Item display**: Show current inventory in bottom-right HUD
- **Item visibility**: Other players can see what each player carries (optional visual indicator)

### Inventory Pickup Logic
- Player walks over item → automatic pickup (no UI prompt)
- If inventory full (5 items): Cannot pick up, show message
- If inventory has space: Add item, remove from world, play pickup sound
- Dropped items despawn after 60 seconds (game logic, not player logic)

### Inventory Functions (to implement or verify)
- `add_item(item_type: String) -> bool` — Returns true if added, false if full
- `remove_item(item_type: String) -> bool` — Consume item, return true if found
- `has_item(item_type: String) -> bool` — Check if player has item
- `get_inventory() -> Array` — Return list of current items
- `clear_inventory()` — Empty all items

### Inventory Data Structure
- Use Array or Dictionary to store items
- Track: item type, quantity (for stackable items like paper/chalk)
- Or track: individual item instances with unique IDs

---

## PLAYER STATES & MECHANICS

### Player Health/Status
- **Knocked Out**: Can be set via meta `"knocked_out"` = true
  - When KO: Cannot move, cannot input, wait for revive
  - Revive via medkit: Restore to standing position
- **Intro Locked**: During intro exam, player cannot move (seated)
  - Set via meta `"intro_locked"` = true
  - During this phase, movement is frozen but camera can rotate (optional)
- **Intro Sitting**: Player is seated during intro exam (camera position changes)
  - Set via meta `"intro_sitting"` = true
  - Camera height = 0.95 units (seated camera height)

### Player Meta Fields (set by game controller)
- `"knocked_out"` — bool, player cannot act if true
- `"intro_locked"` — bool, player cannot move if true
- `"intro_sitting"` — bool, player is seated if true
- `"intro_spawn_marker_name"` — string, identifies which classroom spawn
- `"is_hidden"` — bool, teacher cannot detect if true (optional, for future hiding mechanic)

### Player Raycast & Interaction
- Player should be able to detect whiteboards and items for interaction
- Raycasts should be minimal or throttled (do not run per-frame excessively)
- Keep collision detection to essential interactions only

---

## CURRENT ISSUES TO FIX

### Issue 1: Stamina Bar & UI
- Verify stamina bar creates correctly in _build_stamina_ui()
- Verify stamina bar updates every frame in _update_stamina_ui()
- Verify percentage display shows correct value
- Ensure ProgressBar is positioned correctly

### Issue 2: Camera Height Smoothing
- Verify camera height lerps smoothly between standing (1.6) and crouch (0.9)
- Verify crouch input (KEY_CTRL) triggers height change
- Ensure transition is smooth (delta × 10.0 interpolation)

### Issue 3: Jump Logic
- Verify jump only works when on_floor() is true
- Verify jump doesn't work while crouch is active
- Verify jump velocity applied correctly

### Issue 4: Running Stamina Drain
- Verify running only works with SHIFT + input + stamina available
- Verify stamina drains during run
- Verify exhaust state triggers at 0 stamina
- Verify recovery starts when not running
- Verify exhaust clears when stamina fully recovers

### Issue 5: Movement Deceleration
- Verify move_toward() function decelerates velocity when no input
- Verify deceleration is smooth (not instant stop)
- Verify velocity smoothly transitions

### Issue 6: Footstep Audio
- Verify footsteps only play when moving (direction.length_squared() > 0)
- Verify footsteps only play when on floor
- Verify correct intervals per state (walk/run/crouch)
- Verify correct volume/pitch per state
- Verify no overlapping/stacking footstep sounds

### Issue 7: Inventory Integration
- Verify player can pick up items from world
- Verify inventory cap (max 5 items)
- Verify items persist when player moves between rooms
- Verify dropped items appear in world correctly
- Verify item interaction doesn't cause performance issues

### Issue 8: Player Spawning
- Verify player spawns at correct location (usually Kelas_10_A desk)
- Verify camera starts at correct height
- Verify player starts with empty inventory
- Verify player starts with full stamina

---

## REQUIRED CLEANUP

### Code Quality
1. **Remove dead code** (unused variables, commented-out sections)
2. **Organize functions** logically:
   - Setup: `_ready()`, `_build_stamina_ui()`
   - Input: `_unhandled_input()`
   - Physics: `_physics_process()`
   - Movement: `_update_movement()`, `_apply_movement()`
   - Stamina: `_update_stamina()`, `_update_stamina_ui()`
   - Animation: `_update_footsteps()`
   - Inventory: `add_item()`, `remove_item()`, `has_item()`
   - Status: `heal()`, `is_knocked_out()`, `get_run_stamina()`
3. **Add clear comments** explaining each section
4. **Ensure consistent naming** (use snake_case)

### Variable Organization
- Group input-related variables
- Group movement-related variables
- Group stamina-related variables
- Group UI-related variables
- Group inventory-related variables

### Function Documentation
- Every public function needs docstring
- Movement functions clearly documented
- Stamina logic clearly documented
- Inventory logic clearly documented

---

## REQUIRED OUTPUT

I need you to:

1. **Review the existing Player.gd code**
   - List all current functions and their purpose
   - Identify which features are complete
   - Identify which are incomplete or buggy
   - Check if inventory system exists (if not, outline what's needed)

2. **Clean up the code**
   - Remove dead code
   - Organize functions by category
   - Add clear comments
   - Ensure consistent style

3. **Verify all movement systems work**
   - Normal walking (WASD @ 15.0 u/s)
   - Running (SHIFT @ 10.0 u/s, drains stamina)
   - Crouching (CTRL @ 2.5 u/s, silent)
   - Jumping (SPACE @ 4.5 velocity)
   - Gravity (9.8 acceleration)
   - Deceleration (smooth stop when no input)

4. **Verify stamina system**
   - Max 5.0, drains while running
   - Recovers when walking/standing (1.0/sec)
   - Exhaustion state when 0 stamina
   - Exhaustion clears on full recovery
   - UI shows percentage correctly

5. **Verify camera system**
   - Mouse look works (0.003 sensitivity)
   - Camera height lerps standing (1.6) to crouch (0.9)
   - Height updates smoothly (not instant)
   - Rotation clamped (-1.4 to 1.4 radians X-axis)

6. **Verify footsteps**
   - Walk footsteps: 0.43 interval, -7.0 volume, 1.0 pitch
   - Run footsteps: 0.30 interval, -5.0 volume, 1.04 pitch
   - Crouch footsteps: 0.58 interval, -9.0 volume, 0.94 pitch
   - Only play when moving + on floor
   - Call audio system correctly
   - No stacking/overlapping

7. **Implement inventory system (if missing)**
   - `add_item(item_type: String) -> bool`
   - `remove_item(item_type: String) -> bool`
   - `has_item(item_type: String) -> bool`
   - `get_inventory() -> Array`
   - `clear_inventory()`
   - Max 5 items cap
   - Proper data structure (Array/Dictionary)

8. **Verify status mechanics**
   - Check for `"knocked_out"` meta, freeze if true
   - Check for `"intro_locked"` meta, freeze if true
   - Check for `"intro_sitting"` meta, use seated camera height
   - Properly handle meta-based state changes

9. **Provide optimized Player.gd**
   - All movement systems working
   - All stamina logic correct
   - All inventory functions implemented
   - All UI updates accurate
   - Ready for production

10. **Provide testing checklist**
    - How to test each movement type
    - How to test stamina drain/recovery
    - How to test camera smoothing
    - How to test footsteps
    - How to test inventory pickup
    - How to test status states (KO, intro_locked, etc.)

---

## SPECIFIC REQUIREMENTS

### Must Have:
- ✅ Movement in 4 directions (WASD)
- ✅ Running with stamina drain (SHIFT)
- ✅ Crouch with reduced speed (CTRL)
- ✅ Jump with gravity (SPACE)
- ✅ Mouse look camera control (mouse motion)
- ✅ Stamina bar UI with percentage
- ✅ Footsteps audio with correct timing/volume
- ✅ Inventory system with 5-item cap
- ✅ Status state handling (KO, intro_locked, etc.)

### Should Have:
- ✅ Smooth camera height lerping
- ✅ Deceleration on velocity (move_toward)
- ✅ Footstep audio pooling (no stacking)
- ✅ Clear code comments
- ✅ Organized functions
- ✅ Consistent naming

### Nice to Have:
- ✅ Inventory visual display (HUD icons)
- ✅ Color change on stamina exhaustion
- ✅ Optional hiding mechanic (`is_hidden` meta support)
- ✅ Head bob animation (optional, for immersion)

---

## CONSTRAINTS

- Do NOT modify Map58 geometry
- Do NOT change player physics system (keep CharacterBody3D)
- Do NOT remove any existing public functions (only improve)
- Preserve all existing signals and @export variables
- Keep script name as Player.gd
- Preserve group membership ("players")

---

## REFERENCE IMPLEMENTATION STRUCTURE

```
func _ready():
  Add to "players" group
  Initialize stamina UI
  Set initial stamina to max

func _unhandled_input(event):
  Handle mouse look (InputEventMouseMotion)
  Handle ESC to release mouse (optional)

func _process(delta):
  Update stamina UI

func _physics_process(delta):
  Handle KO state (return if knocked out)
  Handle intro locked state (return if locked)
  Apply gravity
  Handle jump input
  Handle crouch input + camera height lerp
  Get input direction (WASD)
  Determine running state + stamina consumption
  Calculate movement speed based on state
  Apply velocity
  Update footsteps
  move_and_slide()

func _update_footsteps(delta, direction, running):
  Only play when on_floor and moving
  Use correct interval/volume/pitch per state
  Call audio.play_footstep()

func _build_stamina_ui():
  Create CanvasLayer
  Create ProgressBar and Label
  Position at bottom center

func _update_stamina_ui():
  Update bar value and percentage text

func add_item(item_type) -> bool:
  Check if inventory full
  If full: return false
  Else: add to inventory, return true

func remove_item(item_type) -> bool:
  Find item in inventory
  If found: remove and return true
  Else: return false

func has_item(item_type) -> bool:
  Return true if item in inventory

func get_inventory() -> Array:
  Return current items list

func clear_inventory():
  Clear all items

func is_knocked_out() -> bool:
  Return knocked_out meta value

func get_run_stamina() -> float:
  Return current stamina value

func heal(healer):
  For optional medkit healing mechanic
```

---

## TONE & STYLE

- Professional, production-ready
- Clear movement documentation
- Practical testing guidance
- Ready for team collaboration

---

**This is the complete optimization brief for Player.gd. Review the existing code, clean it up, ensure all movement and inventory systems work correctly, and provide the production-ready version.**
