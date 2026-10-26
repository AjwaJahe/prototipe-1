# AUDIO SOURCING WORKFLOW - COMPLETE STEP-BY-STEP GUIDE

**Panduan lengkap: Mana audio yang dicari → Search query yang tepat → Folder struktur Godot**

---

## OVERVIEW

Anda akan mencari **28 audio files** dari 3 sumber aman (BBC, Freesound, Suno AI).
Total waktu: **~2.5 jam**
Total cost: **$0**
Total copyright risk: **ZERO**

---

## WORKFLOW CHECKLIST

Ikuti checklist ini untuk memastikan tidak ada yang terlewat:

```
FASE 1: BBC SOUND EFFECTS (1 hour)
  ☐ 1.1 Footsteps Walk (3 files)
  ☐ 1.2 Footsteps Run (2 files)
  ☐ 1.3 Footsteps Crouch (2 files)
  ☐ 1.4 Teacher Walk Heavy (2 files)
  ☐ 1.5 Door Open Creaky (1 file)
  ☐ 1.6 Door Close Soft (1 file)
  ☐ 1.7 Door Locked (1 file)
  ☐ 1.8 Teacher Breathing (1 file)
  ☐ 1.9 Teacher Alert/Gasp (1 file)

FASE 2: FREESOUND.ORG (30 minutes)
  ☐ 2.1 School Ambience Normal (1 file)
  ☐ 2.2 School Ambience Hunt (1 file)
  ☐ 2.3 School Ambience Supernatural (1 file)
  ☐ 2.4 Board Solving Ambience (1 file)

FASE 3: SUNO AI (30 minutes)
  ☐ 3.1 Teacher Ghost Breathing (1 file → convert to OGG)
  ☐ 3.2 Teacher Detection Alarm (1 file → convert to OGG)
  ☐ 3.3 Phase Transition Stinger (1 file → convert to OGG)
  ☐ 3.4 Success Fanfare (1 file → convert to OGG)
  ☐ 3.5 Defeat Fanfare (1 file → convert to OGG)
  ☐ 3.6 UI Click Sound (1 file → convert to OGG)

FASE 4: AUDACITY CUSTOM SOUNDS (15 minutes)
  ☐ 4.1 Answer Correct Ding (generate + export OGG)
  ☐ 4.2 Answer Wrong Buzzer (generate + export OGG)
  ☐ 4.3 Item Pickup Chime (generate + export OGG)

FASE 5: ORGANIZE & VERIFY (10 minutes)
  ☐ 5.1 Create folder structure
  ☐ 5.2 Move all files to correct folders
  ☐ 5.3 Verify file count: 28 files total
  ☐ 5.4 Test play in Godot
  ☐ 5.5 Create AUDIO_CREDITS.txt
```

---

## FASE 1: BBC SOUND EFFECTS (PUBLIC DOMAIN)

### Setup
1. Go to: **https://sound-effects.bbcrewind.co.uk/**
2. No login needed
3. Search, download, save locally
4. **License**: Public Domain (NO CREDIT NEEDED)
5. **Copyright risk**: ZERO

---

### 1.1 FOOTSTEPS - WALK (3 files)

**Location to save**: `res://assets/audio/footsteps/`

**Download #1**:
- Search: `"footstep walking"`
- Pick: Normal shoe on floor, ~1-2 sec duration
- Listen: Should sound natural, crisp
- Download as: `footstep_walk_1.ogg`

**Download #2**:
- Search: `"footsteps shoes floor"`
- Pick: Different texture/surface than #1
- Listen: Variation is good
- Download as: `footstep_walk_2.ogg`

**Download #3**:
- Search: `"person walking concrete"`
- Pick: Outdoor or concrete sound (different)
- Listen: Third variation
- Download as: `footstep_walk_3.ogg`

**Expected**: 3 audio files, ~1-2 sec each, different variations of walking footsteps

---

### 1.2 FOOTSTEPS - RUN (2 files)

**Location to save**: `res://assets/audio/footsteps/`

**Download #1**:
- Search: `"footstep running"`
- Pick: Fast, dynamic footsteps
- Listen: Should be faster than walk
- Download as: `footstep_run_1.ogg`

**Download #2**:
- Search: `"running fast footsteps"`
- Pick: Another running variation
- Listen: Similar speed but different texture
- Download as: `footstep_run_2.ogg`

**Expected**: 2 audio files, faster than walk, dynamic

---

### 1.3 FOOTSTEPS - CROUCH (2 files)

**Location to save**: `res://assets/audio/footsteps/`

**Download #1**:
- Search: `"footstep soft"`
- Pick: Quiet, careful footstep
- Listen: Should be gentle, subdued
- Download as: `footstep_crouch_1.ogg`

**Download #2**:
- Search: `"quiet footsteps sneaking"`
- Pick: Sneaky, stealthy sound
- Listen: Very quiet, careful movement
- Download as: `footstep_crouch_2.ogg`

**Expected**: 2 audio files, quiet and careful sounding

---

### 1.4 TEACHER FOOTSTEPS - HEAVY (2 files)

**Location to save**: `res://assets/audio/teacher/`

**Download #1**:
- Search: `"footsteps heavy"`
- Pick: Heavy, authoritative footstep (adult)
- Listen: Should sound imposing
- Download as: `teacher_walk_heavy_1.ogg`

**Download #2**:
- Search: `"adult footsteps shoes"`
- Pick: Another heavy footstep variation
- Listen: Similar weight/authority
- Download as: `teacher_walk_heavy_2.ogg`

**Expected**: 2 audio files, heavy and imposing

---

### 1.5 DOOR - OPEN CREAKY (1 file)

**Location to save**: `res://assets/audio/doors/`

**Download #1**:
- Search: `"door open creaky"`
- Pick: Creaky wooden door opening
- Listen: Should sound eerie/slow
- Download as: `door_open_creaky.ogg`

**Expected**: 1 audio file, creaky door opening sound

---

### 1.6 DOOR - CLOSE SOFT (1 file)

**Location to save**: `res://assets/audio/doors/`

**Download #1**:
- Search: `"door close soft"`
- Pick: Gentle door closing (not slam)
- Listen: Should be soft, controlled
- Download as: `door_close_soft.ogg`

**Expected**: 1 audio file, soft door closing

---

### 1.7 DOOR - LOCKED (1 file)

**Location to save**: `res://assets/audio/doors/`

**Download #1**:
- Search: `"door locked rattle"`
- Pick: Lock click or door rattle
- Listen: Should sound like locked mechanism
- Download as: `door_locked.ogg`

**Expected**: 1 audio file, locked door sound

---

### 1.8 TEACHER - BREATHING (1 file)

**Location to save**: `res://assets/audio/teacher/`

**Download #1**:
- Search: `"breathing heavy"`
- Pick: Labored, heavy breathing
- Listen: Should sound threatening/supernatural
- Download as: `teacher_breathing.ogg`

**Expected**: 1 audio file, heavy breathing sound

---

### 1.9 TEACHER - ALERT/GASP (1 file)

**Location to save**: `res://assets/audio/teacher/`

**Download #1**:
- Search: `"gasp alert"`
- Pick: Sharp gasp or sudden exclamation
- Listen: Should sound like detection/alert
- Download as: `teacher_alert.ogg`

**Expected**: 1 audio file, alert/gasp sound

---

### ✅ FASE 1 SUMMARY

**Total files from BBC**: 14 files
**Total time**: ~1 hour
**Copyright risk**: ZERO (public domain)
**Credit needed**: NO

**Files downloaded**:
```
res://assets/audio/
├── footsteps/ (7 files)
│   ├── footstep_walk_1.ogg
│   ├── footstep_walk_2.ogg
│   ├── footstep_walk_3.ogg
│   ├── footstep_run_1.ogg
│   ├── footstep_run_2.ogg
│   ├── footstep_crouch_1.ogg
│   └── footstep_crouch_2.ogg
├── teacher/ (4 files)
│   ├── teacher_walk_heavy_1.ogg
│   ├── teacher_walk_heavy_2.ogg
│   ├── teacher_breathing.ogg
│   └── teacher_alert.ogg
└── doors/ (3 files)
    ├── door_open_creaky.ogg
    ├── door_close_soft.ogg
    └── door_locked.ogg
```

---

## FASE 2: FREESOUND.ORG (CREATIVE COMMONS)

### Setup
1. Go to: **https://freesound.org/**
2. Create free account (or login if you have one)
3. Search using queries below
4. **IMPORTANT**: Use filter to show ONLY Creative Commons
5. **License**: CC0 (NO credit) or CC-BY (need credit)
6. **Copyright risk**: ZERO if you follow CC license

---

### HOW TO FILTER FOR CREATIVE COMMONS

After searching:
1. On left side, click **"Filters"**
2. Under **"License"**, check only:
   - ✓ Creative Commons (or CC0, CC-BY options)
3. Uncheck everything else
4. Download ONLY files with CC0 or CC-BY license shown

---

### 2.1 AMBIENCE - SCHOOL NORMAL (1 file)

**Location to save**: `res://assets/audio/ambience/`

**Search on Freesound**: `"school hallway ambience calm"`
**Filter**: Creative Commons ONLY
**Pick**: 
- Looping ambience (important!)
- Calm, normal school sounds
- 2-5 minute duration (preferably looping)
- Listen preview before download
**Download as**: `ambience_school_normal.ogg`

**If CC-BY license**: Note creator name in AUDIO_CREDITS.txt

**Expected**: 1 audio file, looping school ambience, calm

---

### 2.2 AMBIENCE - SCHOOL HUNT (1 file)

**Location to save**: `res://assets/audio/ambience/`

**Search on Freesound**: `"school corridor eerie"` OR `"hallway unsettling"`
**Filter**: Creative Commons ONLY
**Pick**:
- Looping ambience
- Tense, eerie school sounds
- 2-5 minute duration (preferably looping)
- More unsettling than #2.1
**Download as**: `ambience_school_hunt.ogg`

**If CC-BY license**: Note creator name

**Expected**: 1 audio file, looping, eerie/tense

---

### 2.3 AMBIENCE - SUPERNATURAL (1 file)

**Location to save**: `res://assets/audio/ambience/`

**Search on Freesound**: `"horror atmosphere ethereal"` OR `"ghost ambient"`
**Filter**: Creative Commons ONLY
**Pick**:
- Looping ambience
- Supernatural, ghostly, unnatural sounds
- 2-5 minute duration (preferably looping)
- Very different from #2.1 and #2.2
**Download as**: `ambience_school_supernatural.ogg`

**If CC-BY license**: Note creator name

**Expected**: 1 audio file, looping, supernatural/ghostly

---

### 2.4 AMBIENCE - BOARD SOLVING (1 file)

**Location to save**: `res://assets/audio/ambience/`

**Search on Freesound**: `"suspense tension music"` OR `"horror suspense ambient"`
**Filter**: Creative Commons ONLY
**Pick**:
- Looping ambience or instrumental track
- Tension, suspense, concentration feeling
- Preferably instrumental (no vocals)
- 2-3 minute duration
**Download as**: `ambience_board_solving.ogg`

**If CC-BY license**: Note creator name

**Expected**: 1 audio file, looping, tense/suspenseful

---

### ✅ FASE 2 SUMMARY

**Total files from Freesound**: 4 files
**Total time**: ~30 minutes
**Copyright risk**: ZERO if using CC license
**Credit needed**: YES if CC-BY (save creator names!)

**Files downloaded**:
```
res://assets/audio/ambience/
├── ambience_school_normal.ogg
├── ambience_school_hunt.ogg
├── ambience_school_supernatural.ogg
└── ambience_board_solving.ogg
```

**Important**: Keep list of creator names for credits:
```
- ambience_school_normal.ogg by [Creator Name] (CC-BY)
- ambience_school_hunt.ogg by [Creator Name] (CC-BY)
- ambience_school_supernatural.ogg by [Creator Name] (CC-BY)
- ambience_board_solving.ogg by [Creator Name] (CC-BY)
```

---

## FASE 3: SUNO AI (ORIGINAL GENERATED)

### Setup
1. Go to: **https://suno.ai/**
2. Create free account
3. Freemium tier: 50 credits/day (enough for all 6 sounds)
4. **License**: Original (you own it!)
5. **Copyright risk**: ZERO (it's your audio!)

---

### HOW TO GENERATE

1. Click **"Create"**
2. Copy prompt from below
3. Paste into text field
4. Click **"Generate"**
5. Wait ~1 minute
6. Download best version as MP3
7. Convert MP3 → OGG (see below for how)

---

### CONVERSION: MP3 → OGG

**Option A: Use Audacity (Recommended)**
1. Download Audacity: https://www.audacityteam.org/
2. File → Open → Select MP3 file
3. File → Export → "OGG Vorbis Files"
4. Save as filename.ogg
5. Done!

**Option B: Online Converter**
1. Go to: https://cloudconvert.com/mp3-to-ogg
2. Upload MP3 file
3. Select "OGG" as output format
4. Convert and download

---

### 3.1 TEACHER GHOST BREATHING (1 file)

**Location to save**: `res://assets/audio/teacher/`

**Suno Prompt**:
```
Eerie, supernatural breathing sound, ghostly, haunting, slow heavy breathing, unsettling, 30 seconds, no music, just breathing, horror atmosphere
```

**Steps**:
1. Go to Suno.ai
2. Paste prompt above into "Custom Mode" or description
3. Click Generate
4. Wait for 2 versions to generate
5. Listen to both, pick best one
6. Download as MP3
7. Convert MP3 to OGG using Audacity or online tool
8. Save as: `teacher_ghost_breathing_special.ogg`

**Expected**: 1 audio file, eerie ghostly breathing

---

### 3.2 TEACHER DETECTION ALARM (1 file)

**Location to save**: `res://assets/audio/teacher/`

**Suno Prompt**:
```
Sudden alert alarm sound, sharp high-pitched siren, teacher detection, 1 second, intense, attention-grabbing, horror game alert
```

**Steps**:
1. Go to Suno.ai
2. Paste prompt
3. Generate
4. Download best version as MP3
5. Convert to OGG
6. Save as: `teacher_detection_alarm.ogg`

**Expected**: 1 audio file, sharp alarm/alert sound

---

### 3.3 PHASE TRANSITION STINGER (1 file)

**Location to save**: `res://assets/audio/ui/`

**Suno Prompt**:
```
Dramatic video game stinger, phase transition, ominous chord, supernatural tension, 1.5 seconds, cinematic, intense, horror atmosphere, instrumental
```

**Steps**:
1. Go to Suno.ai
2. Paste prompt
3. Generate
4. Download best version as MP3
5. Convert to OGG
6. Save as: `phase_transition_stinger.ogg`

**Expected**: 1 audio file, dramatic stinger

---

### 3.4 SUCCESS FANFARE (1 file)

**Location to save**: `res://assets/audio/ui/`

**Suno Prompt**:
```
Triumphant victory fanfare, success chord, game win, positive, celebratory, 2 seconds, orchestral style, video game, exciting
```

**Steps**:
1. Go to Suno.ai
2. Paste prompt
3. Generate
4. Download best version as MP3
5. Convert to OGG
6. Save as: `escape_success_fanfare.ogg`

**Expected**: 1 audio file, triumphant fanfare

---

### 3.5 DEFEAT FANFARE (1 file)

**Location to save**: `res://assets/audio/ui/`

**Suno Prompt**:
```
Sad defeat sound, failure chord, game over, ominous, dramatic, 2 seconds, melancholic, orchestral, video game
```

**Steps**:
1. Go to Suno.ai
2. Paste prompt
3. Generate
4. Download best version as MP3
5. Convert to OGG
6. Save as: `defeat_fanfare.ogg`

**Expected**: 1 audio file, sad/defeat fanfare

---

### 3.6 UI CLICK SOUND (1 file)

**Location to save**: `res://assets/audio/ui/`

**Suno Prompt**:
```
Soft menu click sound, UI interaction, light beep, pleasant, 0.2 seconds, video game interface, clear, not annoying
```

**Steps**:
1. Go to Suno.ai
2. Paste prompt
3. Generate
4. Download best version as MP3
5. Convert to OGG
6. Save as: `ui_click.ogg`

**Expected**: 1 audio file, soft UI click

---

### ✅ FASE 3 SUMMARY

**Total files from Suno AI**: 6 files
**Total time**: ~30 minutes (including generation + conversion)
**Copyright risk**: ZERO (you own it!)
**Credit needed**: NO

**Files generated & converted**:
```
res://assets/audio/
├── teacher/ (2 files)
│   ├── teacher_ghost_breathing_special.ogg
│   └── teacher_detection_alarm.ogg
└── ui/ (4 files)
    ├── phase_transition_stinger.ogg
    ├── escape_success_fanfare.ogg
    ├── defeat_fanfare.ogg
    └── ui_click.ogg
```

---

## FASE 4: AUDACITY CUSTOM SOUNDS (GENERATE YOURSELF)

### Setup
1. Download Audacity: https://www.audacityteam.org/ (FREE)
2. Install and open
3. Generate simple tones for UI sounds

---

### 4.1 ANSWER CORRECT - DING (1 file)

**Location to save**: `res://assets/audio/ui/`

**Steps in Audacity**:
1. File → New
2. Generate → Tone
   - Frequency: 800 Hz
   - Amplitude: 0.8
   - Duration: 0.5 seconds
3. Effect → Fade Out (0.2 seconds)
4. File → Export → "OGG Vorbis Files"
5. Save as: `answer_correct_ding.ogg`

**Result**: Bright "ding" sound, success feeling

---

### 4.2 ANSWER WRONG - BUZZER (1 file)

**Location to save**: `res://assets/audio/ui/`

**Steps in Audacity**:
1. File → New
2. Generate → Tone
   - Frequency: 400 Hz
   - Amplitude: 0.8
   - Duration: 0.6 seconds
3. Effect → Fade Out (0.2 seconds)
4. File → Export → "OGG Vorbis Files"
5. Save as: `answer_wrong_buzzer.ogg`

**Result**: Low "buzzer" sound, error feeling

---

### 4.3 ITEM PICKUP - CHIME (1 file)

**Location to save**: `res://assets/audio/ui/`

**Steps in Audacity**:
1. File → New
2. Generate → Tone
   - Frequency: 1200 Hz
   - Amplitude: 0.8
   - Duration: 0.4 seconds
3. Effect → Fade Out (0.15 seconds)
4. File → Export → "OGG Vorbis Files"
5. Save as: `item_pickup_chime.ogg`

**Result**: High "chime" sound, positive feeling

---

### ✅ FASE 4 SUMMARY

**Total files created in Audacity**: 3 files
**Total time**: ~15 minutes
**Copyright risk**: ZERO (you created it!)
**Credit needed**: NO

**Files created**:
```
res://assets/audio/ui/
├── answer_correct_ding.ogg
├── answer_wrong_buzzer.ogg
└── item_pickup_chime.ogg
```

---

## FASE 5: ORGANIZE & VERIFY

### Step 1: Create Folder Structure

Create this exact folder structure in your Godot project:

```
res://assets/audio/
├── footsteps/
├── teacher/
├── doors/
├── ui/
└── ambience/
```

### Step 2: Move All Files

After all downloads/generations, move files to correct folders:

**res://assets/audio/footsteps/**
```
footstep_walk_1.ogg
footstep_walk_2.ogg
footstep_walk_3.ogg
footstep_run_1.ogg
footstep_run_2.ogg
footstep_crouch_1.ogg
footstep_crouch_2.ogg
```

**res://assets/audio/teacher/**
```
teacher_walk_heavy_1.ogg
teacher_walk_heavy_2.ogg
teacher_breathing.ogg
teacher_alert.ogg
teacher_ghost_breathing_special.ogg
teacher_detection_alarm.ogg
```

**res://assets/audio/doors/**
```
door_open_creaky.ogg
door_close_soft.ogg
door_locked.ogg
```

**res://assets/audio/ui/**
```
ui_click.ogg
phase_transition_stinger.ogg
answer_correct_ding.ogg
answer_wrong_buzzer.ogg
item_pickup_chime.ogg
escape_success_fanfare.ogg
defeat_fanfare.ogg
teacher_detection_alarm.ogg (duplicate from teacher/)
```

**res://assets/audio/ambience/**
```
ambience_school_normal.ogg
ambience_school_hunt.ogg
ambience_school_supernatural.ogg
ambience_board_solving.ogg
```

---

### Step 3: Verify File Count

**Expected total: 28 files**

Count:
- Footsteps: 7 files
- Teacher: 6 files
- Doors: 3 files
- UI: 8 files
- Ambience: 4 files

**Total: 28 files** ✓

---

### Step 4: Test Play in Godot

1. Open Godot project
2. Navigate to `res://assets/audio/`
3. Double-click each .ogg file to preview
4. Listen: All files should play without errors
5. If any file doesn't play:
   - Check file format (must be .ogg)
   - Try re-exporting in Audacity or converting online

---

### Step 5: Create AUDIO_CREDITS.txt

Create file: `AUDIO_CREDITS.txt` in project root

**Content**:
```
AUDIO CREDITS & LICENSING
========================

PUBLIC DOMAIN (BBC Sound Effects)
- Source: https://sound-effects.bbcrewind.co.uk/
- License: Public Domain (no attribution required)
- Files:
  * Footsteps (walk, run, crouch variations)
  * Teacher footsteps (heavy)
  * Door sounds (open, close, locked)
  * Teacher breathing and alert sounds

CREATIVE COMMONS (Freesound.org)
- Source: https://freesound.org/
- License: Creative Commons Attribution (CC-BY)
- Attribution Required: YES
- Files:
  * ambience_school_normal.ogg by [CREATOR NAME]
  * ambience_school_hunt.ogg by [CREATOR NAME]
  * ambience_school_supernatural.ogg by [CREATOR NAME]
  * ambience_board_solving.ogg by [CREATOR NAME]

ORIGINAL (Generated with Suno AI)
- Source: https://suno.ai/
- License: Original (game developer owned)
- Attribution Required: NO
- Files:
  * teacher_ghost_breathing_special.ogg
  * teacher_detection_alarm.ogg
  * phase_transition_stinger.ogg
  * escape_success_fanfare.ogg
  * defeat_fanfare.ogg
  * ui_click.ogg (from Suno.ai prompt)

ORIGINAL (Generated with Audacity)
- Source: Audacity (https://www.audacityteam.org/)
- License: Original (game developer owned)
- Attribution Required: NO
- Files:
  * answer_correct_ding.ogg
  * answer_wrong_buzzer.ogg
  * item_pickup_chime.ogg

---

LEGAL NOTICE:
All audio files used in this project are licensed under safe, legal terms.
No copyright infringement. Safe for educational and commercial use.
```

---

### ✅ FASE 5 SUMMARY

**Checklist**:
- [ ] All 28 audio files in correct folders
- [ ] File count verified
- [ ] All files test-play in Godot
- [ ] AUDIO_CREDITS.txt created
- [ ] Creator names filled in for CC-BY files

---

## COMPLETE FOLDER STRUCTURE (FINAL)

```
YourGodotProject/
├── res://assets/audio/
│   ├── footsteps/
│   │   ├── footstep_walk_1.ogg
│   │   ├── footstep_walk_2.ogg
│   │   ├── footstep_walk_3.ogg
│   │   ├── footstep_run_1.ogg
│   │   ├── footstep_run_2.ogg
│   │   ├── footstep_crouch_1.ogg
│   │   └── footstep_crouch_2.ogg
│   ├── teacher/
│   │   ├── teacher_walk_heavy_1.ogg
│   │   ├── teacher_walk_heavy_2.ogg
│   │   ├── teacher_breathing.ogg
│   │   ├── teacher_alert.ogg
│   │   ├── teacher_ghost_breathing_special.ogg
│   │   └── teacher_detection_alarm.ogg
│   ├── doors/
│   │   ├── door_open_creaky.ogg
│   │   ├── door_close_soft.ogg
│   │   └── door_locked.ogg
│   ├── ui/
│   │   ├── ui_click.ogg
│   │   ├── phase_transition_stinger.ogg
│   │   ├── answer_correct_ding.ogg
│   │   ├── answer_wrong_buzzer.ogg
│   │   ├── item_pickup_chime.ogg
│   │   ├── escape_success_fanfare.ogg
│   │   ├── defeat_fanfare.ogg
│   │   └── teacher_detection_alarm.ogg (link/copy)
│   └── ambience/
│       ├── ambience_school_normal.ogg
│       ├── ambience_school_hunt.ogg
│       ├── ambience_school_supernatural.ogg
│       └── ambience_board_solving.ogg
├── AUDIO_CREDITS.txt
└── [other project files...]
```

---

## TIME SUMMARY

| Fase | Task | Time | Files |
|------|------|------|-------|
| 1 | BBC Download | 1 hour | 14 |
| 2 | Freesound Download | 30 min | 4 |
| 3 | Suno AI Generate + Convert | 30 min | 6 |
| 4 | Audacity Create Sounds | 15 min | 3 |
| 5 | Organize + Verify | 10 min | - |
| **TOTAL** | | **~2.5 hours** | **28 files** |

---

## NEXT STEPS (After Completing This Workflow)

1. ✅ All audio files sourced and organized
2. ⬜ Pass PROMPT_7 to ChatGPT for AudioManager.gd code
3. ⬜ Implement AudioManager.gd in Godot
4. ⬜ Test all sounds in game
5. ⬜ Integrate with game logic

---

## HELPFUL LINKS

**Sourcing**:
- BBC Sound Effects: https://sound-effects.bbcrewind.co.uk/
- Freesound.org: https://freesound.org/
- Suno AI: https://suno.ai/

**Tools**:
- Audacity: https://www.audacityteam.org/
- Online MP3→OGG converter: https://cloudconvert.com/mp3-to-ogg
- Godot Engine: https://godotengine.org/

---

**Ready to start? Begin with FASE 1 (BBC Sound Effects). Good luck!** 🎮🎵
