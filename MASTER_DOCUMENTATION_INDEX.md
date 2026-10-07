# MASTER DOCUMENTATION INDEX

**Complete reference for all 14 production-ready documentation files**

---

## 📋 QUICK REFERENCE

| # | File | Type | Purpose | Time | Status |
|---|------|------|---------|------|--------|
| 1 | GAME_DESIGN_DOCUMENT.md | Design | Complete game vision & specs | Reference | ✅ |
| 2 | COMPARATIVE_GAME_REFERENCE.md | Reference | Learn from 10 proven games | Reference | ✅ |
| 3 | CHATGPT_PRODUCTION_BRIEF.md | Prompt | Build game from scratch (comprehensive) | ~6 hrs | ✅ |
| 4 | PROMPT_1_OPTIMIZE_TEACHERAI.md | ChatGPT | Fix teacher AI lag | ~1 hr | ✅ |
| 5 | PROMPT_2_CLEAN_MAP58GAME.md | ChatGPT | Formalize 8 game phases | ~1.5 hrs | ✅ |
| 6 | PROMPT_3_OPTIMIZE_PLAYER.md | ChatGPT | Movement + stamina + inventory | ~1.5 hrs | ✅ |
| 7 | PROMPT_4_ITEM_SPAWNING.md | ChatGPT | Random item spawning system | ~1 hr | ✅ |
| 8 | PROMPT_5_QUESTION_DATABASE.md | ChatGPT | Question system + difficulty | ~1 hr | ✅ |
| 9 | PROMPT_6_UI_HUD_SYSTEM.md | ChatGPT | Complete UI/HUD | ~1.5 hrs | ✅ |
| 10 | PROMPT_7_AUDIO_SYSTEM.md | ChatGPT | Audio system + sourcing | ~1 hr | ✅ |
| 11 | HOW_TO_USE_PROMPTS.md | Guide | Step-by-step usage workflow | Reference | ✅ |
| 12 | CHATGPT_READY_PROMPTS.md | Quick | All 7 prompts copy-paste ready | Reference | ✅ |
| 13 | AUDIO_SOURCING_WORKFLOW.md | Guide | Audio files: where + how + folder structure | ~2.5 hrs | ✅ |
| 14 | MASTER_DOCUMENTATION_INDEX.md | Index | This file - complete reference | Reference | ✅ |

---

## 🎯 EXECUTION WORKFLOW

### PHASE 1: PREPARATION (30 min)
Read these to understand the full picture:
- [ ] Read: GAME_DESIGN_DOCUMENT.md (overview)
- [ ] Read: HOW_TO_USE_PROMPTS.md (workflow guide)
- [ ] Prepare: ChatGPT (new conversation or Claude)

**Time: ~30 minutes**

---

### PHASE 2: AUDIO SOURCING (2.5 hours)
Get all audio files before implementing audio code:
- [ ] Follow: AUDIO_SOURCING_WORKFLOW.md
  - Fase 1: BBC Download (1 hour, 14 files)
  - Fase 2: Freesound Download (30 min, 4 files)
  - Fase 3: Suno AI Generate (30 min, 6 files)
  - Fase 4: Audacity Create (15 min, 3 files)
  - Fase 5: Organize & Verify (10 min)
- [ ] Result: 28 audio files organized in `res://assets/audio/`

**Time: ~2.5 hours**
**Output: res://assets/audio/ (28 files ready)**

---

### PHASE 3: IMPLEMENT SYSTEMS (7-8 hours)

Use ChatGPT prompts in this order:

#### A. PROMPT 1: TeacherAI Optimization (1 hour)
- [ ] Paste: PROMPT_1_OPTIMIZE_TEACHERAI.md to ChatGPT
- [ ] Wait: ChatGPT provides optimized TeacherAI.gd
- [ ] Copy: Code to your TeacherAI.gd
- [ ] Test: Run game, verify no lag during teacher chase
- [ ] Expected: FPS 30-60 during hunt phase

**Checklist**:
- [ ] Copy code to TeacherAI.gd
- [ ] Save
- [ ] Run game (F5)
- [ ] Chase scene with teacher
- [ ] Verify: FPS stays above 30

#### B. PROMPT 2: Map58Game Cleanup (1.5 hours)
- [ ] Paste: PROMPT_2_CLEAN_MAP58GAME.md to ChatGPT
- [ ] Wait: ChatGPT provides cleaned Map58Game.gd
- [ ] Copy: Code to your Map58Game.gd
- [ ] Test: Play through all 8 phases
- [ ] Expected: Smooth phase transitions, accurate scoring

**Checklist**:
- [ ] Copy code to Map58Game.gd
- [ ] Save
- [ ] Run full game playthrough
- [ ] Verify: Phase 1 → Phase 8 works
- [ ] Check: Scoring is correct
- [ ] Check: Grade calculated properly

#### C. PROMPT 3: Player Optimization (1.5 hours)
- [ ] Paste: PROMPT_3_OPTIMIZE_PLAYER.md to ChatGPT
- [ ] Wait: ChatGPT provides optimized Player.gd
- [ ] Copy: Code to your Player.gd
- [ ] Test: Movement, stamina, inventory
- [ ] Expected: Smooth responsive controls, inventory works

**Checklist**:
- [ ] Copy code to Player.gd
- [ ] Save
- [ ] Test: Walk (WASD) - smooth
- [ ] Test: Run (SHIFT) - drains stamina
- [ ] Test: Crouch (CTRL) - quiet
- [ ] Test: Jump (SPACE) - works
- [ ] Test: Pick up item - inventory increases

#### D. PROMPT 4: Item Spawning (1 hour)
- [ ] Paste: PROMPT_4_ITEM_SPAWNING.md to ChatGPT
- [ ] Wait: ChatGPT provides ItemSpawner.gd + PickupItem.gd
- [ ] Copy: Create ItemSpawner.gd and PickupItem.gd
- [ ] Test: Items spawn randomly each game
- [ ] Expected: 28 items total, random locations each run

**Checklist**:
- [ ] Create ItemSpawner.gd (copy from ChatGPT)
- [ ] Create PickupItem.gd (copy from ChatGPT)
- [ ] Add ItemSpawner to Map58 scene
- [ ] Run game
- [ ] Verify: Items appear
- [ ] Verify: Items picked up correctly
- [ ] Verify: Different locations each run

#### E. PROMPT 5: Question Database (1 hour)
- [ ] Paste: PROMPT_5_QUESTION_DATABASE.md to ChatGPT
- [ ] Wait: ChatGPT provides QuestionDatabase.gd + questions
- [ ] Copy: Create QuestionDatabase.gd
- [ ] Test: Questions load, difficulty scales
- [ ] Expected: 10/10 board questions solvable, proper difficulty progression

**Checklist**:
- [ ] Create QuestionDatabase.gd
- [ ] Test: get_board_question(1) returns easy
- [ ] Test: get_board_question(10) returns hard
- [ ] Test: Check answer validation works
- [ ] Test: No duplicate questions in session

#### F. PROMPT 6: UI/HUD System (1.5 hours)
- [ ] Paste: PROMPT_6_UI_HUD_SYSTEM.md to ChatGPT
- [ ] Wait: ChatGPT provides UIManager.gd + HUD.tscn
- [ ] Copy: Create UIManager.gd and HUD scenes
- [ ] Test: All HUD elements display correctly
- [ ] Expected: Score, stamina, objective counter all show live updates

**Checklist**:
- [ ] Create UIManager.gd
- [ ] Create HUD.tscn scene
- [ ] Create ResultsScreen.tscn
- [ ] Run game
- [ ] Verify: Score updates
- [ ] Verify: Stamina bar shows
- [ ] Verify: Objective counter shows X/10
- [ ] Verify: Results screen on finish

#### G. PROMPT 7: Audio System (1 hour)
- [ ] Paste: PROMPT_7_AUDIO_SYSTEM.md to ChatGPT
- [ ] Wait: ChatGPT provides AudioManager.gd + GameAudioManager.gd
- [ ] Copy: Create AudioManager.gd and GameAudioManager.gd
- [ ] Integrate: Audio files from PHASE 2
- [ ] Test: Sounds play on events
- [ ] Expected: All game sounds working, no clipping

**Checklist**:
- [ ] Create AudioManager.gd
- [ ] Create GameAudioManager.gd
- [ ] Create Audio Buses in Godot
- [ ] Verify audio files link correctly
- [ ] Run game
- [ ] Verify: Footsteps play when walking
- [ ] Verify: Phase transition sound plays
- [ ] Verify: Answer feedback sounds work

**Total PHASE 3 time: ~7-8 hours**
**Output: 7 optimized scripts, all systems functional**

---

### PHASE 4: INTEGRATION & TESTING (2-3 hours)

Connect all systems together:

#### A. Wire Up Signals (1 hour)
- [ ] Ensure all GameManager signals connected
- [ ] Ensure all Player signals connected
- [ ] Ensure all Teacher signals connected
- [ ] Ensure ItemSpawner connected
- [ ] Ensure QuestionDatabase connected
- [ ] Ensure UIManager connected
- [ ] Ensure AudioManager connected

#### B. Full Game Playthrough (1 hour)
- [ ] Play through entire game 1-2 times
- [ ] Verify all phases work
- [ ] Verify all mechanics work
- [ ] Check for errors in console

**Test Checklist**:
- [ ] Phase 1 (Intro): Spawn seated, answer 5 questions ✓
- [ ] Phase 2 (Transition): 2.5 sec, lights out, teacher ghost ✓
- [ ] Phase 3 (Hunt): Teacher patrols, player can move ✓
- [ ] Phase 4 (Board): Answer questions, scoring works ✓
- [ ] Phase 5 (Penalty): If caught, penalty exam works ✓
- [ ] Phase 6 (Escape): Gate unlocks after 10 solved ✓
- [ ] Phase 7 (Finished): Results show, grade calculated ✓
- [ ] Audio: All sounds play at right times ✓
- [ ] FPS: Game runs 30-60 FPS consistently ✓

#### C. Balance & Polish (30 min - 1 hour)
- [ ] Adjust difficulty if needed
- [ ] Fine-tune sounds volumes
- [ ] Test with 4 players if possible
- [ ] Polish any rough edges

**Total PHASE 4 time: ~2-3 hours**
**Output: Complete working game, fully tested**

---

## 📊 TOTAL TIME ESTIMATE

| Phase | Task | Time |
|-------|------|------|
| 1 | Preparation | 30 min |
| 2 | Audio Sourcing | 2.5 hrs |
| 3 | Implement 7 Systems | 7-8 hrs |
| 4 | Integration & Testing | 2-3 hrs |
| **TOTAL** | | **~12-14 hours** |

**This can be done in 2-3 days of work, or spread over 1-2 weeks.**

---

## 📁 FILE DESCRIPTIONS

### Design & Reference
#### GAME_DESIGN_DOCUMENT.md (20 KB)
- **What**: Complete game design document
- **Contains**: Game concept, all 8 phases, mechanics, AI behavior, scoring system, audio design, performance targets
- **Use**: Reference document, team communication, design validation
- **When to read**: First, to understand full game
- **Keep**: In repo permanently (documentation)

#### COMPARATIVE_GAME_REFERENCE.md (19 KB)
- **What**: Analysis of 10 similar games
- **Contains**: Scary School, Among Us, The Impostor, etc. - mechanics that work, design lessons, best practices
- **Use**: Learning, inspiration, feature validation
- **When to read**: When uncertain about a game mechanic
- **Keep**: In repo permanently (reference)

#### CHATGPT_PRODUCTION_BRIEF.md (22 KB)
- **What**: Complete prompt to build entire game from scratch
- **Contains**: All systems in one mega-prompt
- **Use**: Alternative if starting from zero, or for additional AI help
- **When to read**: If starting fresh or need comprehensive AI guidance
- **Keep**: In repo permanently (backup)

---

### ChatGPT Prompts (Copy-paste to ChatGPT)

#### PROMPT_1_OPTIMIZE_TEACHERAI.md (7 KB)
- **What**: Fix TeacherAI lag
- **Input**: Existing TeacherAI.gd code (you paste to ChatGPT)
- **Output**: Optimized TeacherAI.gd with raycast throttling + caching
- **Time**: 5-10 min ChatGPT + 10 min testing = 15 min total
- **Status**: Performance critical (do this first)

#### PROMPT_2_CLEAN_MAP58GAME.md (10 KB)
- **What**: Formalize 8 game phases
- **Input**: Existing Map58Game.gd code
- **Output**: Cleaned Map58Game.gd with all phases working
- **Time**: 10-15 min ChatGPT + 30 min testing = 45 min total
- **Status**: Core logic (must be working)

#### PROMPT_3_OPTIMIZE_PLAYER.md (13 KB)
- **What**: Polish player mechanics
- **Input**: Existing Player.gd code
- **Output**: Optimized Player.gd with movement + stamina + inventory
- **Time**: 10-15 min ChatGPT + 30 min testing = 45 min total
- **Status**: UX critical (feel must be good)

#### PROMPT_4_ITEM_SPAWNING.md (8 KB)
- **What**: Random item system
- **Input**: None (new feature)
- **Output**: ItemSpawner.gd + PickupItem.gd
- **Time**: 5-10 min ChatGPT + 20 min testing = 30 min total
- **Status**: Gameplay feature

#### PROMPT_5_QUESTION_DATABASE.md (10 KB)
- **What**: Question system + difficulty scaling
- **Input**: None (new feature)
- **Output**: QuestionDatabase.gd with 120+ questions
- **Time**: 5-10 min ChatGPT + 20 min testing = 30 min total
- **Status**: Core gameplay

#### PROMPT_6_UI_HUD_SYSTEM.md (12 KB)
- **What**: Complete UI/HUD display
- **Input**: None (new feature)
- **Output**: UIManager.gd + HUD.tscn + ResultsScreen.tscn
- **Time**: 10-15 min ChatGPT + 30 min testing = 45 min total
- **Status**: UX feature

#### PROMPT_7_AUDIO_SYSTEM.md (24 KB)
- **What**: Audio system + complete sourcing guide
- **Input**: Audio files (from AUDIO_SOURCING_WORKFLOW)
- **Output**: AudioManager.gd + GameAudioManager.gd
- **Time**: 5-10 min ChatGPT + 20 min testing = 30 min total
- **Status**: Polish/ambiance

---

### Implementation Guides

#### HOW_TO_USE_PROMPTS.md (10 KB)
- **What**: Step-by-step workflow guide
- **Contains**: Which prompts to use, in what order, full testing checklist
- **Use**: Follow this to implement all 7 prompts correctly
- **When**: Before you start with prompts
- **Keep**: Read multiple times as reference

#### CHATGPT_READY_PROMPTS.md (7 KB)
- **What**: All 7 prompts in one copy-paste file
- **Contains**: PROMPT_1 through PROMPT_7, formatted for easy copy
- **Use**: Copy entire prompt, paste to ChatGPT (one at a time)
- **When**: Using prompts
- **Keep**: Easy reference file

#### AUDIO_SOURCING_WORKFLOW.md (21 KB)
- **What**: Complete audio file sourcing guide
- **Contains**: 5 phases, exact search queries, folder structure, verification checklist
- **Phase 1**: BBC Sound Effects (14 files, 1 hour)
- **Phase 2**: Freesound.org (4 files, 30 min)
- **Phase 3**: Suno AI (6 files, 30 min)
- **Phase 4**: Audacity Custom (3 files, 15 min)
- **Phase 5**: Organize & Verify (10 min)
- **Use**: DO THIS BEFORE implementing audio system
- **Time**: ~2.5 hours total
- **Keep**: Follow step-by-step

---

## 🚀 QUICK START (TL;DR)

### If you have 30 minutes:
1. Read: GAME_DESIGN_DOCUMENT.md (understand the game)
2. Read: HOW_TO_USE_PROMPTS.md (understand workflow)
3. Setup ChatGPT

### If you have 3 hours:
1. Read guides above
2. Do: AUDIO_SOURCING_WORKFLOW - Fase 1 (BBC, 1 hour)
3. Start: PROMPT_1 in ChatGPT
4. Start: PROMPT_2 in ChatGPT

### If you have 12+ hours:
1. Follow PHASE 1-4 in EXECUTION WORKFLOW section (above)
2. Do Audio Sourcing (2.5 hours)
3. Run Prompts 1-7 (7-8 hours)
4. Test everything (2-3 hours)
5. **Result: Complete working game!**

---

## ✅ COMPLETION CHECKLIST

### Preparation Phase
- [ ] Read GAME_DESIGN_DOCUMENT.md
- [ ] Read HOW_TO_USE_PROMPTS.md
- [ ] Open ChatGPT
- [ ] Create Godot project or open existing

### Audio Phase
- [ ] Download BBC files (14 files)
- [ ] Download Freesound files (4 files) + note creator names
- [ ] Generate Suno AI files (6 files) + convert MP3→OGG
- [ ] Generate Audacity files (3 files)
- [ ] Organize in res://assets/audio/
- [ ] Verify: 28 files total
- [ ] Create AUDIO_CREDITS.txt

### Implementation Phase
- [ ] PROMPT 1: TeacherAI optimized + tested ✓
- [ ] PROMPT 2: Map58Game cleaned + tested ✓
- [ ] PROMPT 3: Player optimized + tested ✓
- [ ] PROMPT 4: ItemSpawner created + tested ✓
- [ ] PROMPT 5: QuestionDatabase created + tested ✓
- [ ] PROMPT 6: UIManager created + tested ✓
- [ ] PROMPT 7: AudioManager created + tested ✓

### Testing Phase
- [ ] Full game playthrough Phase 1-8 ✓
- [ ] Performance check (30-60 FPS) ✓
- [ ] All scoring works ✓
- [ ] All audio plays ✓
- [ ] All UI displays correctly ✓
- [ ] 4-player test (if available) ✓

### Finalization
- [ ] Commit to Git: `git commit -m "Complete game implementation with all 7 systems"`
- [ ] Create game build
- [ ] Test final build
- [ ] Documentation complete ✓

---

## 📞 SUPPORT & TROUBLESHOOTING

### If Prompt Output Doesn't Work
1. Check Godot version (must be 4.7.2)
2. Look at error message in Godot console
3. Paste error to ChatGPT: "I get this error: [error message]. How to fix?"
4. Copy fix from ChatGPT

### If Audio Files Don't Play
1. Verify files are .ogg format (not mp3 or wav)
2. Test file by right-clicking in Godot → "Play in Editor"
3. If doesn't play, file may be corrupted
4. Re-export in Audacity or re-download

### If Game Performance Lags
1. Open Godot Debugger (Debug → Profiler)
2. Identify which script uses most CPU
3. Paste script name to ChatGPT: "How to optimize [script name] for better performance?"

### If Sounds Play Too Loud/Quiet
1. Edit AudioManager.gd
2. Adjust dB values in play functions
3. Example: Change `-7.0` to `-10.0` for quieter

---

## 📚 FILE ORGANIZATION IN REPO

```
prototipe-1/ (your repo root)
├── GAME_DESIGN_DOCUMENT.md (Design)
├── COMPARATIVE_GAME_REFERENCE.md (Reference)
├── CHATGPT_PRODUCTION_BRIEF.md (Backup)
├── PROMPT_1_OPTIMIZE_TEACHERAI.md (→ ChatGPT)
├── PROMPT_2_CLEAN_MAP58GAME.md (→ ChatGPT)
├── PROMPT_3_OPTIMIZE_PLAYER.md (→ ChatGPT)
├── PROMPT_4_ITEM_SPAWNING.md (→ ChatGPT)
├── PROMPT_5_QUESTION_DATABASE.md (→ ChatGPT)
├── PROMPT_6_UI_HUD_SYSTEM.md (→ ChatGPT)
├── PROMPT_7_AUDIO_SYSTEM.md (→ ChatGPT)
├── HOW_TO_USE_PROMPTS.md (Guide)
├── CHATGPT_READY_PROMPTS.md (Quick)
├── AUDIO_SOURCING_WORKFLOW.md (Workflow)
├── MASTER_DOCUMENTATION_INDEX.md (This file)
├── AUDIO_CREDITS.txt (Created after audio sourcing)
└── [Godot project files...]
    ├── res://assets/audio/ (28 files)
    └── src/ (scripts - created from prompts)
```

---

## 🎯 FINAL SUMMARY

**What you have**: 14 complete documentation files, fully production-ready
**What you need to do**: Follow EXECUTION WORKFLOW phase by phase
**Total time**: 12-14 hours (can be done in 2-3 days)
**Result**: Complete, working, polished horror school game

**You're ready to build!** 🚀

---

## 📝 VERSION HISTORY

- **v1.0** (2026-10-07): Initial release
  - 14 files created
  - Complete workflow documented
  - Ready for implementation

---

**Good luck! 🎮**

For questions or updates, refer to specific file sections above.
