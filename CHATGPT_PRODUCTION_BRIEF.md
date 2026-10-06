# Map58 School Horror Game — Complete Production Brief for ChatGPT

**Use this prompt with ChatGPT to get full development assistance from scratch.**

---

## PRODUCTION BRIEF

You are a professional game developer assistant. Your task is to help develop a multiplayer cooperative horror game in Godot 4.7.2 called "Map58 School Horror Game".

---

## CORE CONCEPT

**Genre**: Multiplayer Cooperative Horror / Puzzle-Escape  
**Engine**: Godot 4.7.2  
**Players**: 4 (co-op only)  
**Platforms**: PC (Desktop)  
**Target FPS**: 30-60 FPS on mid-range hardware (GTX 1060, Ryzen 5 2600)

---

## OBJECTIVE & WIN/LOSE CONDITIONS

### Primary Objective
Players must **escape the school by solving 10 math questions** on whiteboards scattered across different classrooms.

### Win Condition
- All players must solve all 10 questions
- All players must reach and exit through the main school gate (PintuSekolah_MainEntrance)
- Final grade calculated based on score
- Escape time and efficiency also matter for ranking

### Lose Condition
- ALL players are knocked out simultaneously with no one available to revive
- If even one player remains conscious, the game continues
- Players can be captured and enter a "penalty exam" phase; if they complete it, they escape and return to normal gameplay

---

## GAMEPLAY LOOP (6 PHASES)

### Phase 1: INTRO_EXAM (20 seconds)
- Player sits at classroom desk
- Must answer 5 easy math questions (SD level, difficulty 1-2)
- Teacher is in non-threatening mode
- Classroom lights are normal, door is closed
- Purpose: Establish baseline difficulty for later game scaling
- If player answers correctly: +10 score per question
- If wrong: -5 score per question
- After 20 seconds expire, auto-advances to Phase 2

### Phase 2: TRANSITION (2.5 seconds)
- Teacher transforms from human to supernatural state
- Nearest classroom lights blackout automatically
- Teacher visible as "ghost"
- Teacher enters "ghost" mode (hunting begins)
- Door closes automatically
- Status message: "Teacher is now in supernatural mode. Beware."

### Phase 3: HUNT (Active exploration, variable duration)
- Players explore the school freely
- Teacher actively patrols and hunts using AI (see AI section below)
- Duration depends on intro performance: Base 180 sec + (correct_answers × 30), capped at 300 sec
- **Each player must collect:**
  1. Paper (Question sheet) — needed to approach whiteboard
  2. Chalk — needed to write answer on whiteboard
  3. Key (optional) — unlocks some classroom doors
  
- **Objective**: Find a whiteboard in any classroom and approach with Paper + Chalk in inventory
- Once at whiteboard with required items: Begin board question (Phase 4)

### Phase 4: BOARD_SOLVING (Per question, 120 seconds max)
- Whiteboard displays a single math question
- Difficulty scales: Q1-2 = difficulty 3, Q3-4 = difficulty 4, Q5+ = difficulty 5
- Player enters numeric answer via keyboard
- Time limit: 120 seconds per question

**If CORRECT**:
- +10 score
- Question removed, replaced with new question at random location
- Teacher returns to "teacher" mode for 180 seconds (safe period)
- Solved papers counter increments (now 2/10, 3/10, etc.)
- If solved_papers >= 10: Advance to Phase 6

**If INCORRECT or TIMEOUT**:
- -5 score
- Teacher enters "berserk" mode for 15 seconds (faster, more aggressive)
- Teacher becomes faster (10.0 u/s) and makes aggressive sounds
- Same paper is recycled and respawned at a new location
- Game returns to Phase 3 (Hunt)

### Phase 5: PENALTY_EXAM (Triggered when captured by teacher)
- Captured player is transported to a punishment room
- Must answer 5 easy math questions (SD level, difficulty 1-2)
- Penalty exam clock: Infinite (no time limit)

**If player answers all 5 correctly**:
- Player escapes penalty room
- Returns to normal hunt phase (Phase 3)
- No score penalty beyond the capture

**If player fails any question**:
- Player is knocked out
- Requires medkit revive by teammate (Phase 5b)

### Phase 5b: KNOCKOUT & REVIVAL (Optional)
- Knocked out player lies immobilized on ground
- Teammate can carry/use medkit on knocked player
- Medkit restores knocked player to standing position
- Medkit is single-use, limited quantity (3-5 medkits for 4 players)
- Game continues only if at least 1 player is conscious

### Phase 6: ESCAPE_READY
- Triggered after solving all 10 questions successfully
- School main gate (PintuSekolah_MainEntrance) unlocks automatically
- Teacher returns to "teacher" mode (non-threatening)
- Players must physically navigate to the exit gate
- Once all players reach exit: Advance to Phase 7

### Phase 7: FINISHED
- Game concludes
- Final score calculated
- Grade assigned (A, B, C, D) based on score
- Results screen shown
- Option to restart or exit

---

## TEACHER AI BEHAVIOR

### Detection System

**Vision (Line of Sight)**
- Detection distance = **3× teacher's eye height** (approx 5.1 units)
- Requires direct line-of-sight to player (raycasts through walls)
- Line-of-sight check done every 0.12 seconds (throttled, not every frame)
- Vision is omnidirectional (360° around teacher)

**Hearing (Proximity)**
- Hearing distance = **8.0 units**
- Triggers when player makes noise:
  - Running footsteps
  - Colliding with objects
  - Loud door interactions
- Hearing bypasses line-of-sight requirement
- Hearing check done every frame

**Losing Target**
- If player exits detection radius (5.1 units) AND loses line-of-sight
- Teacher stands still at last known position
- Teacher sweeps 360° looking around for 10 seconds
- If target not re-detected: Returns to patrol
- Teacher does NOT move while sweeping

### Movement & Speed

**Base Speed by Mode**:
- **teacher mode**: 3.5 units/sec (normal walking)
- **ghost mode**: 10.0 units/sec (supernatural sprint)
- **berserk mode**: 10.0 units/sec (same as ghost, but with audio cues)

### Patrol System (Teacher Mode)

- Teacher randomly selects from a list of waypoints:
  - All student spawn locations (from SpawnManager → StudentSpawns)
  - Teacher spawn location (from SpawnManager → TeacherSpawn)
  - Other key locations (hallways, exits, storage)
- Teacher walks to waypoint at 3.5 u/s
- Upon reaching waypoint: Waits 1.5 seconds, then selects random next waypoint
- Pathfinding uses AStar with door nodes (see below)

### Door Interaction

- Teacher can open doors automatically when blocked
- Door open distance threshold: 2.2 units
- Door interaction cooldown: 0.7 seconds (prevents spam)
- Teacher waits 0.36 seconds for door to fully open
- After passing through: Teacher automatically closes door at distance 2.8 units
- Closed doors are collision barriers (block both player and teacher equally)

### Pathfinding (AStar Graph)

- Pre-built door graph created at game start
- Graph nodes: All door locations in school
- Edges: Direct line-of-sight paths between doors (verified with raycasts, ignoring other doors)
- Graph used for efficient pathing between distant waypoints
- Graph is cached and only rebuilt at startup (NOT per-frame)

### AI Modes

| Mode | Trigger | Speed | Behavior | Duration | Audio |
|------|---------|-------|----------|----------|-------|
| **teacher** | Startup, after calm phase, after timeout | 3.5 u/s | Patrol random waypoints | Indefinite | Normal footsteps |
| **ghost** | Player detected (vision or hearing) | 10.0 u/s | Chase detected target | Until target lost | Alert tone + ghost loop |
| **berserk** | Wrong board answer or timeout | 10.0 u/s | Chase with increased audio aggression | 15 seconds fixed | Ruler sound + aggressive footsteps |
| **responding** | Player at whiteboard with paper + chalk | 3.5 u/s | Move to player's classroom (slower) | Until question submitted or 120s timeout | Alert tone |

---

## ITEM SYSTEM

Items are **single-use** collectibles spawned across the school. Inspired by Devour's resource scarcity mechanics.

### Mandatory Items (Quest-Critical)

| Item | Quantity | Spawn Locations | Purpose | Inventory Impact |
|------|----------|-----------------|---------|-------------------|
| **Paper** (Question) | 10 | Random across all classrooms | Required to approach whiteboard | 1 slot per item |
| **Chalk** | 10 | Random across hallways, storage, classrooms | Required to write answer | 1 slot per item |
| **Key** | 1-2 | Teacher's office, specific classrooms | Unlock restricted doors | 1 slot per item |

### Optional Items (Survival/Strategy)

| Item | Quantity | Spawn Locations | Purpose | Inventory Impact |
|------|----------|-----------------|---------|-------------------|
| **Medkit** | 3-5 | Medical room (UKS), office, hidden corners | Revive knocked-out teammate | 1 slot per item |
| **Flashlight** | 0-1 | Storage or hallway | Light dark areas (if implemented) | 1 slot |
| **Noise-maker** | 0-1 | Hidden room | Distraction (draw teacher away) | 1 slot |

### Inventory Constraints
- **Max 5 items per player** at any time
- Items are visible on player model (backpack/belt for other players to see)
- Dropped items remain in world temporarily (despawn after 60 seconds if not picked up)
- Item pickup is automatic (walk over item to collect)

### Spawn Mechanics
- Items spawn at random valid locations each game session (NOT fixed locations every run)
- Papers spawn in classrooms with whiteboards
- Chalk spawns in hallways, storage, or classrooms
- Keys spawn in classrooms or office
- Medkits spawn rarely and are most valuable resource
- Random spawn + limited quantity = emergent teamwork (players must communicate roles)

---

## ITEM ROLES & PLAYER SPECIALIZATION

Players naturally emerge into roles (not forced by game mechanics):

### 1. **Collector** Role
- Fast runners with good stamina
- Focuses on finding and carrying papers, chalk, keys
- Stays mobile, doesn't solve questions
- Critical for early game success

### 2. **Solver** Role
- Mathematically inclined players
- Focuses on answering questions on whiteboards
- Carries papers + chalk to solution points
- Cooperates with Collector to plan routes

### 3. **Guard** Role
- Watchful players who monitor teacher position
- Uses audio cues and proximity alerts to warn team
- Stays near solver and collector for protection
- May carry medkits for emergency revives

### 4. **Medic** Role
- Defensive, low-mobility players
- Carries and manages medkit inventory
- Ready to revive knocked-out teammates
- Critical for survival in late game

**Important**: Roles emerge organically; no hardcoded role system. Players self-organize based on natural abilities and team needs.

---

## MAP & LOCATIONS

**School Rooms** (where questions can be solved):
1. Kelas_10_A (Classroom A)
2. Kelas_10_B (Classroom B)
3. Kelas_10_C (Classroom C)
4. Kantin (Cafeteria)
5. Perpustakaan (Library)
6. Ruang Guru (Teacher's Room)
7. UKS (Medical Office)
8. Ruang Tamu (Guest/Office)
9. Gudang (Warehouse)
10. Toilet (Restroom)

**Key Navigation Points**:
- **Player Spawn**: Kelas_10_A (at classroom desk)
- **Teacher Waypoints**: All classrooms + hallways + storage
- **Main Exit**: PintuSekolah_MainEntrance (locked until 10 questions solved)
- **Patrol Routes**: AStar pathfinding through all connected rooms via doors

**Collision & Navigation**:
- All walls block movement equally for players and teacher
- Furniture has collision (desks, chairs, shelves)
- Doors are collision barriers when closed
- Open doors are passable
- No special clipping or shortcuts

---

## DIFFICULTY SCALING

### Intro Exam (Phase 1)
- **Questions**: 5 SD-level
- **Difficulty**: Fixed (1-2 out of 5)
- **Purpose**: Establish baseline for game scaling
- Score: 0-50 points possible

### Hunt Duration (Phase 3 timing)
- **Formula**: 180 + (intro_correct_answers × 30), capped at 300 seconds
- **Examples**:
  - 0 correct on intro → 180 sec hunt (3 min)
  - 5 correct on intro → 330 sec hunt (5.5 min, capped at 300)
- **Purpose**: Reward players who did well on intro with longer hunting time

### Board Questions (Phase 4 difficulty)
- **Base Difficulty**: SMA level (3-4 out of 5)
- **Scaling Formula**: For every 2 questions solved, difficulty increases by +1 (capped at 5)
  - Questions 1-2: Difficulty 3
  - Questions 3-4: Difficulty 4
  - Questions 5-10: Difficulty 5
- **Variance**: Questions pulled randomly from difficulty pool
- **Purpose**: Gradual increase in challenge as players progress

### Penalty Exam (Phase 5)
- **Questions**: 5 SD-level (easier than board questions)
- **Difficulty**: Fixed (1-2)
- **Purpose**: Punishment for capture, but still solvable
- **Why easier**: Captured player is already stressed; make escape achievable

---

## PERFORMANCE TARGETS & OPTIMIZATION

### Frame Rate Target
- **Target**: 30–60 FPS on mid-range PC (GTX 1060, Ryzen 5 2600)
- **Critical minimum**: Never drop below 30 FPS during active teacher chase

### Object Budget
- **Maximum active NPCs**: 1 (teacher only)
- **Maximum simultaneous players**: 4
- **Maximum furniture objects per room**: ~50 (with collision LOD)
- **Maximum active items in world**: 15 total (papers + chalk + keys + medkits)
- **Maximum active lights**: 5 per room (rest culled by distance)
- **Active AI pathfinding calls**: Throttled to 1 per 0.12 seconds (not per-frame)

### Optimization Rules (MUST IMPLEMENT)
1. **Frustum culling**: Only render objects in camera view
2. **LOD (Level of Detail)**: Distant furniture uses simpler collision
3. **Raycast throttling**: Teacher detection checks every 0.12 seconds (NOT every frame)
4. **Door graph caching**: Pre-build AStar graph at startup, NOT per-frame
5. **Audio pooling**: Maximum 3 concurrent footstep sounds
6. **Collision groups**: Separate player/teacher/door/furniture collision layers
7. **Physics tick rate**: Keep at 60 Hz (not higher)

---

## AUDIO DESIGN

### Teacher Sounds
- **Footsteps** (varying): Heavy, creaky when walking; faster pitch in ghost/berserk mode
- **Door opening**: Slow creak (if door is initially closed)
- **Door closing**: Soft slam (after teacher passes through)
- **Breathing**: Heavy breathing when close to player (proximity-based)
- **Alert sound**: Eerie notification tone when entering ghost mode
- **Punishment sound**: Ruler striking when entering berserk mode
- **Taunt/laugh**: Contextual, only when catching player

### Environmental
- **Ambient hallway hum**: Soft background noise in corridors
- **Classroom clock ticking**: In classrooms (faint, atmospheric)
- **Player footsteps**: Vary by speed (walking slow, running fast, crouching silent)
- **Item pickup**: Subtle "ding" sound
- **Question correct**: Positive chime tone
- **Question wrong**: Negative buzzer tone
- **Door knock**: 3 sequential knocks before teacher opens locked door

### Audio Pools & Constraints
- **Max 3 concurrent footsteps**: No overlapping footstep sounds beyond 3
- **Distance attenuation**: Volume decreases with distance to player
- **Proximity alerts**: UI + audio warning when teacher approaches (within 10 units)

---

## MULTIPLAYER MECHANICS

### Co-op Coordination
- **Shared objective**: All players must escape together
- **Shared score**: Points accumulate for entire team
- **Shared teacher**: Only 1 AI teacher hunts all 4 players
- **Communication**: Must use voice chat or text chat to strategize

### Revive Mechanics
- **Downed state**: Player lies on ground, unable to move
- **Revive requirement**: Another player uses medkit on downed player
- **Revive time**: 3 seconds
- **Revive cost**: 1 medkit (consumed)
- **Max revives**: Limited by medkit quantity (3-5 for 4 players)

### Shared Inventory Implications
- Players must divide roles (who carries what)
- Fast players carry items to solvers
- Solvers focus on solving, not collecting
- Guard watches for threats while team solves
- Medic keeps medkits for emergencies

### Win/Lose Conditions (Multiplayer)
- **Win**: ALL 4 players exit the gate after solving 10 questions
- **Lose**: ALL 4 players knocked out with no medkits remaining
- **Partial success**: Some players escape, others don't (affects score ranking)

---

## UI/UX ELEMENTS

### In-Game HUD (Per-Player)
- **Stamina bar** (bottom center): Running energy remaining
- **Objective counter** (top-left): "Questions: 5/10"
- **Timer** (top-left): Hunt duration remaining (in Phase 3)
- **Teacher proximity indicator** (screen edges): Red flash when close (< 10 units)
- **Inventory display** (bottom-right): Currently held items with icons
- **Status messages** (center screen): Mode changes, alerts, feedback
- **Audio proximity cue**: Visual indicator when teacher footsteps detected

### Menu Screens
- **Main menu**: Start game, settings, quit
- **Settings**: Mouse sensitivity, master volume, graphics quality
- **Pause menu** (in-game): Resume, settings, quit to menu
- **Results screen**: Final grade (A/B/C/D), score, escape time, ranking

### Status Messages (Examples)
- "Kertas soal dibagikan. Kamu punya 20 detik untuk mengisi 5 soal." (Intro start)
- "Guru meninggalkan kelas dan melayang. Pintu tertutup, lampu padam..." (Transition to hunt)
- "Cari Kunci Kelas, Kertas Soal, dan Kapur." (Hunt phase start)
- "Guru mengetahui kelasmu. Waktu menjawab: 2 menit." (Board solving start)
- "Jawaban benar. Soal berikutnya akan muncul di lokasi baru." (Correct answer)
- "SALAH. Guru masuk mode BERSEK selama 15 detik." (Wrong answer)
- "Mode bersek berakhir. Guru kembali mengejar secara normal." (Berserk timeout)
- "10 soal selesai. Guru kembali normal. Gerbang sekolah terbuka." (Escape ready)
- "Kamu berhasil keluar dari sekolah. Nilai akhir: A." (Game finished)

---

## SCORE & GRADING SYSTEM

### Score Calculation
- **Intro exam**: +10 per correct question (max +50)
- **Board questions**: +10 per correct (max +100)
- **Wrong answers**: -5 per incorrect (unlimited negative)
- **Penalty exam**: +10 per correct (max +50)
- **Revive penalty**: -2 per player revived
- **Total possible**: ~200+ points (depends on play)

### Grade Tiers (Example)
- **A**: 150+ points
- **B**: 100-149 points
- **C**: 50-99 points
- **D**: Below 50 points

---

## REFERENCE GAMES (PROVEN MECHANICS)

This game design draws from 10 successful reference titles:

1. **Devour** (2021) — Puzzle + items + escalating threat
2. **Lunch Lady** (2022) — School setting + exam answers + AI hunt
3. **Pacify** (2021) — Escalating threat + puzzle solving
4. **Dead by Daylight** (2016) — Asymmetric multiplayer balance
5. **Evil Dead: The Game** (2022) — Revive system + cooperative objectives
6. **Friday the 13th: The Game** (2017) — Jason hunts counselors + escape objectives
7. **Identity V** (2018) — Role-based asymmetric gameplay
8. **Phasmophobia** (2020) — Investigation + equipment management + proximity threat
9. **Forewarned** (2022) — Curse escalation + team roles + inventory limits
10. **Escape the Backrooms** (2022) — Maze navigation + entity avoidance + procedural spawns

These games prove the following mechanics work:
- ✅ Cooperative puzzle-solving + collection
- ✅ Single AI threat vs many players
- ✅ Item scarcity forcing teamwork
- ✅ Threat escalation keeping tension
- ✅ Limited revive system
- ✅ Clear win/lose conditions
- ✅ Audio-based threat detection

---

## FILES & CODE STRUCTURE (GODOT)

### Core Scripts to Create/Modify
- `Map58Game.gd` — Main game logic, phase state machine
- `TeacherAI.gd` — Teacher AI, detection, pathfinding
- `Player.gd` — Player movement, stamina, inventory
- `ItemSpawner.gd` — Random item spawn logic
- `QuestionDatabase.gd` — Question pool management
- `UIManager.gd` — HUD updates, status messages

### Scene Structure
- `main.tscn` — Root scene (teacher, players, map, furniture)
- `map58/Map58.tscn` — School geometry (DO NOT MODIFY)
- Door scripts: `PintuKelas.gd`, `PintuSekolah.gd`
- Inventory system linked to player

### Data Files
- `questions.json` or `QuestionDatabase.gd` — Question pool by difficulty/level

---

## KNOWN ISSUES & OPTIMIZATIONS

### Critical Issues
1. **TeacherAI lag**: Raycasting + route rebuilding every frame → MUST throttle
2. **Door spam**: Teacher opens/closes doors too frequently
3. **Collision LOD**: No distance-based culling for distant furniture

### Optimizations Needed
1. Throttle detection checks to 0.12s
2. Cache AStar graph at startup only
3. Implement collision layer culling
4. Audio pooling (max 3 concurrent footsteps)
5. Frustum culling for distant objects

---

## TESTING CHECKLIST

Before release, verify:
- [ ] Intro exam works (20 sec timer, 5 questions)
- [ ] Transition works (teacher becomes ghost, lights blackout)
- [ ] Hunt phase active (teacher patrols and detects players)
- [ ] Teacher detection at 3× eye height works
- [ ] Line-of-sight raycasts don't cause FPS drops
- [ ] Door opening/closing doesn't stutter
- [ ] Patrol waypoints cycle randomly
- [ ] Board questions display correctly
- [ ] Answer submission + scoring works
- [ ] Grade calculation correct
- [ ] Medkit revive works in multiplayer
- [ ] All 10 papers spawn at random locations
- [ ] Teacher doesn't clip through walls
- [ ] FPS stays 30-60 during active chase
- [ ] Audio proximity cues work
- [ ] Multiplayer item sharing works
- [ ] Escape gate opens after 10 questions solved

---

## SUMMARY

**What you have:**
- Clear objective (solve 10 questions + escape)
- Defined AI threat (teacher with detection + patrol)
- Established mechanics (items, puzzle-solving, revive, phases)
- Reference games (10 proven titles with similar mechanics)
- Performance budget (30-60 FPS, 1 NPC, 4 players max)

**What needs doing:**
- Implement all 7 gameplay phases
- Optimize TeacherAI (throttle raycasts + cache graph)
- Random item spawning (not fixed locations)
- Difficulty tiers (Easy/Normal/Hard)
- Polish audio + UI
- Test multiplayer coordination

**Estimated scope**: Medium-sized indie game (4-6 weeks for experienced team)

---

**This brief is production-ready. Use it with ChatGPT, another AI, or your development team to build the complete game.**

