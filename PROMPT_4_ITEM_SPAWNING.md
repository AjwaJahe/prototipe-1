# Prompt 4: Item Spawning System & Management

**Use this prompt with ChatGPT to implement random item spawning and management**

---

## CONTEXT

You are a professional Godot 4.7.2 gameplay systems programmer. I need you to create an item spawning and management system that handles random item distribution across the school map.

**Project**: Map58 School Horror Game (Godot 4.7.2)  
**Current State**: Items may be spawning at fixed locations or not spawning at all  
**Target**: Dynamic, randomized item spawning system  
**Success Metric**: All item types spawn correctly at random locations each game session

---

## ITEM TYPES & QUANTITIES

### Mandatory Items (Quest-Critical)
- **Paper** (Question sheets): 10 total
  - Spawn locations: Classrooms (Kelas_10_A, Kelas_10_B, Kelas_10_C)
  - Required to approach whiteboard and start question
  - Single-use per question (respawns at new location when question respawns)

- **Chalk**: 10 total
  - Spawn locations: Hallways, classrooms, storage (Gudang)
  - Required to write answer on whiteboard
  - Used to answer board question

- **Key**: 1-2 total
  - Spawn locations: Teacher's office (Ruang Guru), specific classrooms
  - Unlocks restricted classroom doors
  - Can be reused (doesn't consume)

### Optional Items (Survival/Strategy)
- **Medkit**: 3-5 total
  - Spawn locations: Medical office (UKS), teacher's office, hidden corners
  - Revives knocked-out teammate
  - Single-use per teammate

- **Flashlight**: 0-1 total
  - Spawn locations: Storage (Gudang) or hallway
  - Lights dark areas (future enhancement)
  - Can be reused

- **Noise-maker**: 0-1 total
  - Spawn locations: Hidden room or storage
  - Distracts teacher (high-risk item)
  - Single-use (breaks after use)

---

## SPAWN LOCATION SYSTEM

### Spawn Marker Strategy
- School map has predefined spawn marker locations (Vector3 positions)
- Spawn markers grouped by room/type:
  - `classroom_spawns`: 6 locations (2 per classroom)
  - `hallway_spawns`: 4 locations (scattered hallways)
  - `storage_spawns`: 2 locations (storage room areas)
  - `office_spawns`: 2 locations (teacher office, guest office)
  - `medical_spawns`: 2 locations (UKS room)

### Randomization Logic
- Each game session: Shuffle spawn locations
- Assign items to random available spawns
- Ensure no two items spawn at same location
- Papers always spawn in classrooms
- Chalk can spawn anywhere except medical office
- Keys spawn in offices/classrooms
- Medkits spawn in medical/office areas
- Rare items (flashlight, noise-maker) spawn at hidden locations

### Despawn Logic
- Items on ground despawn after 60 seconds if not picked up
- Item respawns at new location when picked up or question answered
- Game maintains item count (always 10 papers, 10 chalk, etc.)

---

## SPAWNING SCRIPT REQUIREMENTS

### Script: ItemSpawner.gd
Should handle:
- Load spawn marker locations from scene
- Initialize item distribution algorithm
- Spawn items at startup
- Handle item pickup callbacks
- Handle item respawn (when paper used in board solving)
- Track item locations in real-time

### Main Functions
- `_ready()` — Initialize spawn locations, spawn initial items
- `spawn_initial_items()` — Distribute items randomly at startup
- `spawn_item_at_location(item_type: String, location: Vector3)` — Instantiate item
- `request_item_respawn(item_type: String)` — Called when paper used
- `on_item_picked_up(item: Node3D)` — Called when player collects item
- `get_spawn_location_for(item_type: String) -> Vector3` — Find valid spawn point
- `clear_all_items()` — Remove all items from world (for phase transitions)

### Item Properties (per item type)
```
paper:
  quantity: 10
  spawn_locations: classroom_spawns
  respawns: yes (when board question answered)
  player_visible: yes
  stackable: yes

chalk:
  quantity: 10
  spawn_locations: all (except medical)
  respawns: no (stays in world until picked up)
  player_visible: yes
  stackable: yes

key:
  quantity: 1-2
  spawn_locations: office_spawns + some classrooms
  respawns: no
  player_visible: yes
  stackable: no

medkit:
  quantity: 3-5
  spawn_locations: medical_spawns + office_spawns
  respawns: no
  player_visible: yes
  stackable: no

flashlight:
  quantity: 0-1
  spawn_locations: storage_spawns
  respawns: no
  player_visible: yes
  stackable: no

noise_maker:
  quantity: 0-1
  spawn_locations: hidden locations
  respawns: no
  player_visible: yes
  stackable: no
```

---

## ITEM SCENE STRUCTURE

### Pickup Item Scene (PickupItem.tscn or similar)
Each item should be a scene with:
- **Root**: Area3D node (for collision detection)
- **Mesh**: MeshInstance3D (visual representation)
- **Collision**: CollisionShape3D (sphere, 0.3 radius)
- **Script**: PickupItem.gd or similar

### PickupItem.gd Script
```gdscript
extends Area3D

@export var item_type: String = "paper"
@export var item_name: String = "Question Paper"

func _ready():
  area_entered.connect(_on_area_entered)

func _on_area_entered(area):
  if area is Player or area.name.contains("Player"):
    if player.add_item(item_type):
      queue_free()  # Item consumed
    else:
      pass  # Inventory full, stay in world

func get_item_type() -> String:
  return item_type
```

---

## INTEGRATION WITH OTHER SYSTEMS

### Integration with Map58Game.gd
- ItemSpawner listens to game phase changes
- When board question answered: `paper_respawn_requested()` signal
- When Phase 3 (Hunt) starts: Spawn initial items
- When Phase 7 (Finished) starts: Clear all items

### Integration with Player.gd
- Player calls `add_item(item_type)` when picking up
- Player inventory tracks items (max 5)
- Player can drop items (optional feature)

### Integration with QuestionDatabase.gd (Prompt 5)
- When player answers question correctly
- ItemSpawner respawns paper at new random location

---

## CURRENT ISSUES TO FIX

### Issue 1: Fixed vs Random Spawns
- Problem: Items spawn at fixed locations every run
- Solution: Implement shuffle algorithm to randomize spawns each session

### Issue 2: Item Quantity Tracking
- Problem: Unknown how many items active in world
- Solution: Track total items, respawn if missing

### Issue 3: Spawn Location List
- Problem: Spawn markers may not exist in scene
- Solution: Either create spawn markers in Map58.tscn or define locations as code constants

### Issue 4: Item Despawn Timing
- Problem: Items stay forever if not picked up
- Solution: Implement 60-second despawn timer

### Issue 5: Respawn Logic
- Problem: New papers don't appear when old ones used
- Solution: Listen to paper_respawn_requested signal from Map58Game

---

## REQUIRED OUTPUT

I need you to:

1. **Create ItemSpawner.gd script**
   - Load spawn locations (either from scene markers or code)
   - Implement randomized spawn distribution algorithm
   - Handle item instantiation
   - Track active items in world
   - Implement respawn logic
   - Handle despawn timer

2. **Create or verify PickupItem.gd**
   - Area3D collision detection
   - Call player.add_item() on collision
   - Handle inventory full scenario
   - Despawn after 60 seconds if not picked

3. **Provide integration points**
   - What signals to send/listen to from Map58Game
   - What functions Player.gd needs to call
   - How to initialize ItemSpawner

4. **Provide spawn location definition**
   - Either export locations as @export variables
   - Or provide code to auto-detect spawn markers from scene

5. **Provide testing checklist**
   - How to verify random spawning
   - How to test item pickup
   - How to test respawn logic

---

## CONSTRAINTS

- Do NOT modify Map58 geometry
- Do NOT hardcode spawn locations (use flexible system)
- Keep item spawning separate from player/game logic
- Preserve existing scenes (PickupItem.tscn if exists)
- Ensure items visible and accessible to players

---

**This is the item spawning system brief. Proceed with implementation. Output the complete ItemSpawner.gd and PickupItem.gd scripts ready for production.**
