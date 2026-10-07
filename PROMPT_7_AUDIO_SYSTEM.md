# Prompt 7: Audio System & Sound Design (WITH SOURCING GUIDE)

**Use this prompt with ChatGPT to create comprehensive audio system + sourcing guide**

---

## CONTEXT

You are a professional Godot 4.7.2 audio programmer and sound designer. I need you to create:
1. An audio system that handles all game sounds with proper pooling and volume management
2. A complete audio sourcing guide showing exactly where to find/create all required sounds safely and legally

**Project**: Map58 School Horror Game (Godot 4.7.2)  
**Current State**: Audio may be playing but unoptimized or incomplete  
**Target**: Production-ready audio system + complete sourcing strategy  
**Success Metric**: All sounds play correctly, no audio overlaps/clipping, all audio sourced safely (zero copyright risk)

---

## PART 1: AUDIO SYSTEM IMPLEMENTATION

### AUDIO CATEGORIES & SOUNDS

#### 1. PLAYER FOOTSTEPS (Spatial Audio)
**Purpose**: Movement feedback + teacher detection cue

**Walk Footsteps**:
- Interval: 0.43 seconds
- Volume: -7.0 dB (medium)
- Pitch: 1.0 (normal)
- Sound type: Soft shoe on floor
- Detectable by teacher: Yes (hearing range 8.0 units)

**Run Footsteps**:
- Interval: 0.30 seconds
- Volume: -5.0 dB (louder)
- Pitch: 1.04 (slightly higher)
- Sound type: Fast shoe on floor
- Detectable by teacher: Yes (hearing range 8.0 units)

**Crouch Footsteps**:
- Interval: 0.58 seconds
- Volume: -9.0 dB (quiet)
- Pitch: 0.94 (slightly lower)
- Sound type: Soft, careful footstep
- Detectable by teacher: No (silent mode)

#### 2. TEACHER SOUNDS (Spatial Audio)
**Purpose**: Teacher presence + threat indication

**Teacher Footsteps (Normal Mode)**:
- Interval: 0.5 seconds
- Volume: -4.0 dB (audible)
- Pitch: 0.9-1.0 (heavy, authoritative)
- Sound type: Heavy shoes, adult movement
- Range: Audible within 15 units

**Teacher Footsteps (Ghost Mode)**:
- Interval: 0.4 seconds
- Volume: -3.0 dB (loud, eerie)
- Pitch: 0.85 (deeper, supernatural)
- Sound type: Floating/gliding sound
- Effect: Reverb + echo (sounds unnatural)

**Teacher Breathing (Ghost Mode)**:
- Interval: 4 seconds (exhale/inhale)
- Volume: -6.0 dB
- Sound type: Heavy, labored breathing
- Range: Close proximity (3 units)

**Teacher Alert/Detection Sound**:
- Type: Sharp, sudden sound (like a gasp or alert)
- Volume: -2.0 dB
- Pitch: 1.2 (high pitch = alert)
- Duration: 0.5 seconds
- Plays when: Teacher spots player

#### 3. DOOR SOUNDS (Spatial Audio)
**Purpose**: Environment interaction + tension building

**Door Opening**:
- Volume: -5.0 dB
- Duration: 1.0 second
- Sound type: Creaky, eerie door open
- Plays when: Teacher or player opens door

**Door Closing**:
- Volume: -5.0 dB
- Duration: 0.8 seconds
- Sound type: Soft close (not violent)
- Plays when: Door auto-closes

**Door Locked**:
- Volume: -6.0 dB
- Duration: 0.3 seconds
- Sound type: Lock click/rattle
- Plays when: Player tries locked door

#### 4. INTERFACE/UI SOUNDS

**Menu Click**:
- Volume: -10.0 dB
- Pitch: 1.0
- Duration: 0.2 seconds

**Question Correct Answer**:
- Volume: -4.0 dB
- Pitch: 1.2 (high, positive)
- Duration: 0.5 seconds
- Sound type: "Ding!" success sound

**Question Wrong Answer**:
- Volume: -4.0 dB
- Pitch: 0.8 (low, negative)
- Duration: 0.6 seconds
- Sound type: Buzzer/error sound

**Item Pickup**:
- Volume: -7.0 dB
- Pitch: 1.1 (bright)
- Duration: 0.4 seconds
- Sound type: Chime/pickup sound

**Phase Transition**:
- Volume: -3.0 dB
- Duration: 1.5 seconds
- Sound type: Dramatic stinger/chord

**Teacher Berserk Alert**:
- Volume: 0.0 dB (loud!)
- Pitch: 1.3-1.5 (very high)
- Duration: 1.0 second
- Sound type: Alarm/siren sound

**Escape Success**:
- Volume: -2.0 dB
- Duration: 2.0 seconds
- Sound type: Triumphant victory chord

**Defeat Sound**:
- Volume: -2.0 dB
- Duration: 2.0 seconds
- Sound type: Sad/ominous failure chord

#### 5. AMBIENT/BACKGROUND SOUNDS

**School Ambience (Normal)**:
- Volume: -20.0 dB (very subtle background)
- Sound type: Faint school hallway sounds (clock ticking, distant voices)

**School Ambience (Hunt Phase)**:
- Volume: -18.0 dB (slightly louder, more tense)
- Sound type: Eerie hallway sounds (wind, creaks)

**School Ambience (Supernatural)**:
- Volume: -16.0 dB (louder, unsettling)
- Sound type: Disturbing sounds (whispers, strange noises)

**Whiteboard Ambient**:
- Volume: -15.0 dB
- Sound type: Tension/suspense music

---

## AUDIO POOLING STRATEGY

### Problem: Audio Overlap
- Multiple footsteps playing simultaneously can cause clipping
- Solution: Audio pooling (limit concurrent sounds)

### Audio Pool Limits
```
Player footsteps: Max 1 concurrent
Teacher footsteps: Max 1 concurrent
Door sounds: Max 2 concurrent
UI sounds: Max 3 concurrent (clicks, success, error)
Environmental: Max 4 concurrent (separate for each ambience type)
Total: ~15 audio sources active maximum
```

---

## AUDIO SCRIPT STRUCTURE

### Main Script: AudioManager.gd
```gdscript
extends Node

# Audio pools
var player_footstep_pool: Array[AudioStreamPlayer3D] = []
var teacher_footstep_pool: Array[AudioStreamPlayer3D] = []
var door_sound_pool: Array[AudioStreamPlayer3D] = []
var ui_sound_pool: Array[AudioStreamPlayer3D] = []
var ambient_pool: Array[AudioStreamPlayer] = []

# Master volume
@export var master_volume: float = 1.0
@export var effects_volume: float = 0.8
@export var ambience_volume: float = 0.6

# Current ambience track
var current_ambience: AudioStreamPlayer = null
var sound_library: Dictionary = {}

func _ready():
  _initialize_pools()
  _load_sound_library()

func _initialize_pools():
  # Create audio sources for each pool
  _create_pool("player_footsteps", 1)
  _create_pool("teacher_footsteps", 1)
  _create_pool("door_sounds", 2)
  _create_pool("ui_sounds", 3)

func play_player_footstep(volume: float, pitch: float):
  var source = _get_pool_source("player_footsteps")
  source.volume_db = volume + effects_volume
  source.pitch_scale = pitch
  source.play()

func play_teacher_footstep(volume: float, pitch: float, teacher_position: Vector3):
  var source = _get_pool_source("teacher_footsteps")
  source.global_position = teacher_position
  source.volume_db = volume + effects_volume
  source.pitch_scale = pitch
  source.play()

func play_ui_sound(sound_type: String):
  var source = _get_pool_source("ui_sounds")
  if sound_type in sound_library:
    source.stream = sound_library[sound_type]
    source.play()

func set_ambience(ambience_type: String):
  if current_ambience:
    current_ambience.stop()
  
  if ambience_type in sound_library:
    var player = AudioStreamPlayer.new()
    player.stream = sound_library[ambience_type]
    player.volume_db = -15.0 + ambience_volume
    player.bus = "Ambience"
    player.play()
    current_ambience = player

func _load_sound_library():
  # Load all sounds from res://assets/audio/
  var audio_dir = "res://assets/audio/"
  # Implementation: Load all .ogg files from directory

func _get_pool_source(pool_name: String):
  var pool = audio_pool[pool_name]
  for source in pool:
    if not source.playing:
      return source
  return pool[0]  # Override if all busy
```

### Integration Script: GameAudioManager.gd
```gdscript
extends Node

@onready var audio = AudioManager

func _ready():
  game_manager.phase_changed.connect(_on_phase_changed)
  game_manager.answer_submitted.connect(_on_answer_submitted)
  player.inventory_changed.connect(_on_item_picked_up)
  teacher_ai.mode_changed.connect(_on_teacher_mode_changed)

func _on_phase_changed(phase: String):
  match phase:
    "intro_exam": audio.set_ambience("ambience_school_normal")
    "transition": audio.play_ui_sound("phase_transition_stinger")
    "hunt": audio.set_ambience("ambience_school_hunt")
    "board_solving": audio.set_ambience("ambience_board_solving")
    "escape_ready": audio.set_ambience("ambience_school_hunt")
    "finished": audio.play_ui_sound("escape_success_fanfare")

func _on_answer_submitted(correct: bool):
  if correct:
    audio.play_ui_sound("answer_correct_ding")
  else:
    audio.play_ui_sound("answer_wrong_buzzer")
    audio.play_ui_sound("teacher_berserk_alarm")

func _on_item_picked_up(item_type: String):
  audio.play_ui_sound("item_pickup")

func _on_teacher_mode_changed(mode: String):
  if mode == "ghost":
    audio.set_ambience("ambience_school_supernatural")
```

---

## AUDIO BUS SETUP (Godot Mixer)

Create audio buses in Godot:
```
Master
├── Effects (for game sounds)
│   ├── Footsteps
│   ├── UI
│   └── Door Sounds
├── Ambience (background)
└── Music (future expansions)
```

---

## PART 2: COMPLETE AUDIO SOURCING GUIDE

**IMPORTANT**: Before implementing audio system, you need to source all audio files. This guide tells you exactly where to find them, what to search for, and how to verify they're safe to use (zero copyright risk).

---

## SOURCING STRATEGY OVERVIEW

### Three Sources (100% Safe):

| Source | Safety | Cost | Time | Best For |
|--------|--------|------|------|----------|
| **BBC Sound Effects** | ✅ Public Domain | $0 | 1 hour | Footsteps, doors, effects |
| **Freesound.org (CC)** | ✅ Creative Commons | $0 | 30 min | Ambience, variations |
| **Suno AI** | ✅ Original Generated | $0 (freemium) | 30 min | Ambience, unique sounds |

**Total time: ~2 hours | Total cost: $0 | Total risk: ZERO**

---

## SECTION 1: BBC SOUND EFFECTS (PUBLIC DOMAIN - SAFEST)

### Platform
- **Website**: https://sound-effects.bbcrewind.co.uk/
- **License**: Public Domain (BBC archives)
- **Cost**: FREE
- **Credit Needed**: NO
- **Commercial Use**: YES (safe for all purposes)
- **Copyright Risk**: ZERO

### Why BBC?
- Broadcast-quality audio
- Professionally recorded
- Public domain (guaranteed safe)
- No attribution needed
- Perfect for game sounds

### Audio Files to Download from BBC

#### A. Player Footsteps (Walk)
**Search queries** (try these in BBC sound effects search):
1. "footstep walking"
2. "footsteps shoes floor"
3. "person walking concrete"

**Download**: Get 3 different variations
**Rename to**:
- `footstep_walk_1.ogg`
- `footstep_walk_2.ogg`
- `footstep_walk_3.ogg`

#### B. Player Footsteps (Run)
**Search queries**:
1. "footstep running"
2. "running fast footsteps"
3. "quick footsteps"

**Download**: Get 2 variations
**Rename to**:
- `footstep_run_1.ogg`
- `footstep_run_2.ogg`

#### C. Player Footsteps (Crouch)
**Search queries**:
1. "footstep soft"
2. "quiet footsteps"
3. "sneaking footstep"

**Download**: Get 2 variations
**Rename to**:
- `footstep_crouch_1.ogg`
- `footstep_crouch_2.ogg`

#### D. Teacher Footsteps (Heavy)
**Search queries**:
1. "footsteps heavy"
2. "adult footsteps"
3. "footstep thick sole"

**Download**: Get 2 variations
**Rename to**:
- `teacher_walk_heavy_1.ogg`
- `teacher_walk_heavy_2.ogg`

#### E. Door Opening (Creaky)
**Search queries**:
1. "door open creaky"
2. "wooden door opening"
3. "door creak open"

**Download**: Get 1 file
**Rename to**: `door_open_creaky.ogg`

#### F. Door Closing
**Search queries**:
1. "door close soft"
2. "door shut"
3. "door closing gently"

**Download**: Get 1 file
**Rename to**: `door_close_soft.ogg`

#### G. Door Locked/Rattle
**Search queries**:
1. "door locked"
2. "lock click"
3. "door rattle"

**Download**: Get 1 file
**Rename to**: `door_locked.ogg`

#### H. Breathing (Teacher)
**Search queries**:
1. "breathing heavy"
2. "breathing labored"
3. "person breathing"

**Download**: Get 1 file
**Rename to**: `teacher_breathing.ogg`

#### I. Alert/Gasp Sound
**Search queries**:
1. "gasp"
2. "alert sound"
3. "sudden exclamation"

**Download**: Get 1 file
**Rename to**: `teacher_alert.ogg`

### BBC Sourcing Checklist
- [ ] Create folder: `res://assets/audio/`
- [ ] Download all 9 BBC files (footsteps walk × 3, run × 2, crouch × 2, teacher × 2, + doors × 3)
- [ ] Place in `res://assets/audio/`
- [ ] Rename according to guide above
- [ ] Verify files play in Godot (preview in file browser)
- [ ] Create credits note: "BBC Sound Effects used under Public Domain"

**Time: ~1 hour**

---

## SECTION 2: FREESOUND.ORG (CREATIVE COMMONS - SAFE IF CC-BY)

### Platform
- **Website**: https://freesound.org/
- **License**: Creative Commons (various types - CC0, CC-BY, CC-BY-SA)
- **Cost**: FREE
- **Credit Needed**: YES if CC-BY (CC0 = NO credit needed)
- **Commercial Use**: YES (with CC license)
- **Copyright Risk**: ZERO (if you follow licensing)

### Important: Filter by CC License
**ALWAYS filter by "Creative Commons"** when searching to avoid copyright issues.

### How to Search on Freesound.org Safely

1. **Go to**: https://freesound.org/
2. **Search**: Type keyword (e.g., "ambient school")
3. **Filter**: 
   - Click "Filters" on left
   - Under "License", select: ✓ Creative Commons (CC-0 or CC-BY)
   - Deselect all others
4. **Download**: Only download files with CC0 or CC-BY license
5. **If CC-BY**: Note the creator name for credits

### Audio Files to Download from Freesound

#### A. School Ambience (Normal)
**Search on Freesound**: "school hallway ambience calm"
**Filter**: CC license
**Download**: 1-2 variations (pick longest looping one)
**Rename to**: `ambience_school_normal.ogg`
**Credit** (if CC-BY): Note creator name

#### B. School Ambience (Hunt/Tense)
**Search on Freesound**: "school corridor eerie" OR "hallway unsettling"
**Filter**: CC license
**Download**: 1 file (pick most tense version)
**Rename to**: `ambience_school_hunt.ogg`
**Credit** (if CC-BY): Note creator name

#### C. Supernatural Ambience
**Search on Freesound**: "horror atmosphere ethereal" OR "ghost ambient"
**Filter**: CC license
**Download**: 1 file
**Rename to**: `ambience_school_supernatural.ogg`
**Credit** (if CC-BY): Note creator name

#### D. Board Solving Ambience (Tension)
**Search on Freesound**: "suspense tension music" OR "horror suspense ambient"
**Filter**: CC license
**Download**: 1 file (instrumental, no vocals)
**Rename to**: `ambience_board_solving.ogg`
**Credit** (if CC-BY): Note creator name

### Freesound Sourcing Checklist
- [ ] Find 4 ambience tracks with CC-BY or CC0 license
- [ ] Download all 4 files
- [ ] Place in `res://assets/audio/ambience/`
- [ ] Rename according to guide above
- [ ] Create credits list:
  ```
  Audio from Freesound.org:
  - ambience_school_normal.ogg by [Creator Name] (CC-BY)
  - ambience_school_hunt.ogg by [Creator Name] (CC-BY)
  - ambience_school_supernatural.ogg by [Creator Name] (CC-BY)
  - ambience_board_solving.ogg by [Creator Name] (CC-BY)
  ```

**Time: ~30 minutes**

---

## SECTION 3: SUNO AI (ORIGINAL GENERATED - 100% SAFE)

### Platform
- **Website**: https://suno.ai/
- **License**: Original (You own it)
- **Cost**: FREE (freemium tier)
- **Credit Needed**: NO
- **Commercial Use**: YES
- **Copyright Risk**: ZERO (it's yours!)

### Why Suno AI?
- Generates original audio from text prompts
- No copyright issues (you own the output)
- Can create unique, custom sounds
- Freemium tier has 50 credits/day (more than enough)

### How to Use Suno AI

1. **Go to**: https://suno.ai/
2. **Sign up**: Free account
3. **Click**: "Create" button
4. **Write prompt**: Describe what you want (see examples below)
5. **Generate**: AI creates 2 versions (pick best)
6. **Download**: Save as MP3 (convert to OGG in Godot or Audacity)

### Generated Audio Prompts

#### A. Teacher Ghost Mode Breathing (Eerie)
**Prompt**: "Eerie, supernatural breathing sound, ghostly, haunting, slow heavy breathing, unsettling, 30 seconds, no music, just breathing"

**Generate**: 1 audio file
**Rename to**: `teacher_ghost_breathing_special.ogg`
**License**: 100% yours (no attribution needed)

#### B. Teacher Alert/Detection (Alarm)
**Prompt**: "Sudden alert alarm sound, sharp high-pitched siren, teacher detection, 1 second, intense, attention-grabbing"

**Generate**: 1 audio file
**Rename to**: `teacher_detection_alarm.ogg`
**License**: 100% yours

#### C. Phase Transition Stinger (Dramatic)
**Prompt**: "Dramatic video game stinger, phase transition, ominous chord, supernatural tension, 1.5 seconds, cinematic"

**Generate**: 1 audio file
**Rename to**: `phase_transition_stinger.ogg`
**License**: 100% yours

#### D. Success Fanfare (Triumphant)
**Prompt**: "Triumphant victory fanfare, success chord, game win, positive, celebratory, 2 seconds, orchestral style"

**Generate**: 1 audio file
**Rename to**: `escape_success_fanfare.ogg`
**License**: 100% yours

#### E. Defeat Sound (Sad)
**Prompt**: "Sad defeat sound, failure chord, game over, ominous, dramatic, 2 seconds, melancholic"

**Generate**: 1 audio file
**Rename to**: `defeat_fanfare.ogg`
**License**: 100% yours

#### F. UI Click Sound
**Prompt**: "Soft menu click sound, UI interaction, light beep, pleasant, 0.2 seconds, video game"

**Generate**: 1 audio file
**Rename to**: `ui_click.ogg`
**License**: 100% yours

### Suno AI Sourcing Checklist
- [ ] Create Suno.ai account (free)
- [ ] Generate 6 custom audio files using prompts above
- [ ] Download all files (MP3 format)
- [ ] Convert MP3 to OGG (Godot can handle both, but OGG smaller)
  - Option A: Use Audacity (free) - File → Export → OGG
  - Option B: Use online converter (cloudconvert.com)
- [ ] Place in `res://assets/audio/suno_generated/`
- [ ] Rename according to guide above
- [ ] Create credits note: "Original audio generated with Suno AI"

**Time: ~30 minutes (including generation + download)**

---

## SECTION 4: REMAINING UI SOUNDS (SIMPLE ALTERNATIVES)

For remaining UI sounds (success ding, error buzzer, pickup chime), you have options:

### Option A: Create Simple Sounds in Audacity (Free)
1. Download Audacity: https://www.audacityteam.org/
2. Generate tones:
   - **Success ding**: Generate tone at 800 Hz, 0.5 sec, fade out
   - **Error buzzer**: Generate tone at 400 Hz, 0.6 sec, modulate
   - **Pickup chime**: Generate tone at 1200 Hz, 0.4 sec, fade out
3. Export as OGG

### Option B: Find on Freesound (If you prefer)
**Search** on Freesound.org with CC filter:
- "success ding sound"
- "error buzzer"
- "chime pickup"

Download and rename appropriately.

### Recommended: Option A (Audacity)
- Free, quick (15 minutes)
- Sounds professional
- No copyright concerns
- Easy to customize pitch/duration

---

## SECTION 5: FOLDER STRUCTURE

Organize all audio in Godot project:

```
res://
└── assets/
    └── audio/
        ├── footsteps/
        │   ├── walk_1.ogg
        │   ├── walk_2.ogg
        │   ├── walk_3.ogg
        │   ├── run_1.ogg
        │   ├── run_2.ogg
        │   ├── crouch_1.ogg
        │   └── crouch_2.ogg
        ├── teacher/
        │   ├── walk_heavy_1.ogg
        │   ├── walk_heavy_2.ogg
        │   ├── breathing.ogg
        │   ├── alert.ogg
        │   └── ghost_breathing_special.ogg
        ├── doors/
        │   ├── open_creaky.ogg
        │   ├── close_soft.ogg
        │   └── locked.ogg
        ├── ui/
        │   ├── click.ogg
        │   ├── answer_correct_ding.ogg
        │   ├── answer_wrong_buzzer.ogg
        │   ├── item_pickup.ogg
        │   ├── phase_transition_stinger.ogg
        │   ├── teacher_berserk_alarm.ogg
        │   ├── teacher_detection_alarm.ogg
        │   ├── escape_success_fanfare.ogg
        │   └── defeat_fanfare.ogg
        └── ambience/
            ├── school_normal.ogg
            ├── school_hunt.ogg
            ├── school_supernatural.ogg
            └── board_solving.ogg
```

---

## SECTION 6: AUDIO CREDITS TEMPLATE

Add this to your game credits scene or README:

```
AUDIO CREDITS

Public Domain (BBC Sound Effects):
- Footstep sounds (walk, run, crouch, heavy teacher)
- Door sounds (open, close, locked)
- Teacher breathing and alert sounds
- Source: BBC Sound Effects (https://sound-effects.bbcrewind.co.uk/)
- License: Public Domain

Creative Commons (Freesound.org):
- School ambience (normal, hunt, supernatural, board solving)
- By: [Creator names from CC-BY files]
- License: Creative Commons Attribution (CC-BY)
- Source: https://freesound.org/

Original (Generated with Suno AI):
- Teacher ghost mode sounds
- Phase transition stinger
- Success and defeat fanfares
- UI alert sounds
- Generated with: Suno AI (https://suno.ai/)
- License: Original (Game Developer owned)

Custom (Audacity Generated):
- UI click, success ding, error buzzer, pickup chime
- Generated with: Audacity (Free Software)
```

---

## SECTION 7: VALIDATION CHECKLIST

Before using ANY audio file in your game, verify:

### Safety Checklist (Do NOT skip)
- [ ] **Where did it come from?** (BBC, Freesound, Suno, etc.)
- [ ] **What's the license?** (Public Domain, CC0, CC-BY, Royalty-free, etc.)
- [ ] **Can I use commercially?** (Yes = safe for game)
- [ ] **Do I need to credit?** (Only if CC-BY - already listed above)
- [ ] **Is it safe from copyright strikes?** (Yes = proceed)

### Red Flags (AVOID these):
- ❌ "Free download" from unknown website
- ❌ No license information provided
- ❌ From YouTube without clear attribution
- ❌ Copyrighted music (famous artists, bands)
- ❌ "All rights reserved" without permission
- ❌ Unclear origin or source

### Green Flags (SAFE):
- ✅ BBC Sound Effects (Public Domain)
- ✅ Freesound.org with CC0 or CC-BY license (WITH attribution)
- ✅ Generated with Suno AI (you own it)
- ✅ Created yourself in Audacity
- ✅ Royalty-free licensed from music library
- ✅ Royalty-free music sites (Pixabay, Incompetech)

---

## COMPLETE SOURCING WORKFLOW

### Step 1: BBC Download (1 hour)
1. Go to BBC Sound Effects
2. Search and download 9 files (footsteps, doors, breathing, alert)
3. Place in `res://assets/audio/`
4. Rename files

### Step 2: Freesound Download (30 minutes)
1. Go to Freesound.org
2. Search for 4 ambience tracks with CC filter
3. Download all 4
4. Note creator names (for CC-BY credits)
5. Place in `res://assets/audio/ambience/`
6. Rename files

### Step 3: Suno AI Generation (30 minutes)
1. Go to Suno.ai, create account
2. Use 6 prompts provided above
3. Generate and download 6 files
4. Convert MP3 to OGG in Audacity or online tool
5. Place in `res://assets/audio/ui/`
6. Rename files

### Step 4: Audacity Simple Sounds (15 minutes)
1. Download Audacity (free)
2. Generate 4 UI sounds (ding, buzzer, chime, click)
3. Export as OGG
4. Place in `res://assets/audio/ui/`
5. Rename files

### Step 5: Verify & Organize (10 minutes)
1. Verify folder structure matches template above
2. Create AUDIO_CREDITS.txt file
3. List all sources and licenses
4. Place in project root

**Total Time: ~2.5 hours | Cost: $0 | Copyright Risk: ZERO**

---

## REQUIRED OUTPUT FROM CHATGPT

I need you to provide:

1. **Complete AudioManager.gd script**
   - Audio pooling implementation
   - Sound library loading
   - All play functions for each sound type
   - Volume control system
   - 3D spatial audio support

2. **Complete GameAudioManager.gd script**
   - Signal connections to game events
   - Phase transition audio handling
   - Answer feedback audio
   - Ambience switching logic

3. **Audio Setup Guide for Godot**
   - How to create Audio Buses
   - How to configure AudioStreamPlayer3D nodes
   - How to load audio files into Godot
   - Project structure recommendations

4. **Audio Sourcing Summary**
   - Recap of all 3 safe sources (BBC, Freesound, Suno)
   - Exact files needed from each source
   - Search queries that work
   - Expected results

5. **Credits Template**
   - Ready-to-use text for game credits
   - Proper attribution format
   - Where to place in game

6. **Testing Checklist**
   - How to verify sounds play correctly
   - How to test audio pooling
   - How to test volume balance
   - How to test ambience transitions

---

## CONSTRAINTS

- Do NOT recommend any paid audio libraries yet
- Do NOT provide links to copyrighted content
- Ensure all recommendations are 100% safe legally
- Keep sourcing straightforward (BBC + Freesound + Suno)
- Provide complete code (not partial)

---

## TONE & STYLE

- Professional audio programming
- Horror atmosphere design
- Clear, step-by-step sourcing guide
- Legal safety emphasized
- Production-ready code

---

**This is the complete audio system + sourcing brief. Proceed with implementation. Output the complete AudioManager.gd and GameAudioManager.gd scripts, plus detailed audio sourcing guide, setup instructions, and testing checklist. Ensure all audio recommendations are 100% copyright-safe.**
