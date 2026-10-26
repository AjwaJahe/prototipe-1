# Prompt 2: Clean & Formalize Map58Game.gd

**Use this prompt with ChatGPT to clean up and formalize the main game controller**

---

## CONTEXT

You are a professional Godot 4.7.2 game architect. I need you to review and clean the main game controller script to ensure all 8 gameplay phases work correctly and follow best practices.

**Project**: Map58 School Horror Game (Godot 4.7.2)  
**Script**: Map58Game.gd (main game state machine)  
**Current State**: Functional but needs cleanup and formalization  
**Target**: Production-ready game controller with all phases verified  
**Success Metric**: All 8 phases transition correctly, score/grade accurate, no missing signals

---

## GAME FLOW (8 PHASES)

### Phase 1: INTRO_EXAM (20 seconds)
- Player spawns seated at classroom desk
- Must answer 5 easy math questions (SD level, difficulty 1-2)
- Timer: 20 seconds
- Teacher mode: "teacher" (non-threatening)
- Door: closed
- Lights: normal
- On timeout: Auto-advance to Phase 2
- On submit: Store intro scores, advance to Phase 2

### Phase 2: TRANSITION (2.5 seconds)
- Teacher becomes supernatural
- Nearby classroom lights blackout
- Teacher enters "ghost" mode
- Door closes automatically
- Timer: 2.5 seconds
- On timeout: Advance to Phase 3

### Phase 3: HUNT (variable duration, 180-300 seconds)
- Player explores school freely
- Teacher patrols and hunts actively
- Teacher can detect and chase players
- Players search for: paper, chalk, key, medkit
- Teacher mode: "teacher" (patrol) or "ghost" (chase) or "berserk" (if wrong answer)
- Calm periods: After correct answer, teacher mode = "teacher" for 180 seconds
- Hunt duration: Base 180 + (intro_correct × 30), capped at 300 seconds
- On player approaches whiteboard with paper+chalk: Advance to Phase 4
- On player caught: Advance to Phase 5

### Phase 4: BOARD_SOLVING (per question, 120 seconds max)
- Whiteboard displays a math question
- Player enters numeric answer
- Timer: 120 seconds per question
- Difficulty scales: Q1-2 = 3, Q3-4 = 4, Q5+ = 5
- If correct: +10 score, solved_papers++, question respawns elsewhere, teacher enters calm (180s "teacher" mode)
- If wrong/timeout: -5 score, teacher enters "berserk" mode for 15s, question respawns, return to Phase 3
- If solved_papers >= 10: Advance to Phase 6
- If solved_papers < 10: Return to Phase 3 (Hunt continues)

### Phase 5: PENALTY_EXAM (triggered when caught)
- Captured player enters punishment room
- Must answer 5 easy questions (SD level)
- No time limit
- If all correct: Player escapes, returns to Phase 3
- If any wrong: Player KO, advance to Phase 5b

### Phase 5b: KNOCKOUT & REVIVAL
- KO player cannot move
- Teammate can use medkit to revive
- If revived: Return to Phase 3
- If all players KO: Advance to Phase 8 (FINISHED - LOSE)

### Phase 6: ESCAPE_READY
- All 10 questions solved
- School gate unlocks
- Teacher enters "teacher" mode (non-threatening)
- Players must reach and exit through PintuSekolah_MainEntrance
- On all players reach exit: Advance to Phase 7

### Phase 7: FINISHED (WIN)
- Game completes successfully
- Final score calculated
- Final grade assigned (A/B/C/D)
- Results screen shown

---

## CURRENT ISSUES TO FIX

### Issue 1: Missing Signals or Incomplete Signals
- Ensure these signals exist and fire at correct times:
  - `phase_changed(phase: String)`
  - `objective_changed(solved: int, target: int)`
  - `teacher_mode_changed(mode: String, target: Node)`
  - `player_knocked_out(player: Node)`
  - `player_revived(player: Node)`
  - `game_finished()`
  - `paper_respawn_requested()`

### Issue 2: Score & Grade Logic
- Verify score calculation:
  - Intro: +10 per correct, -5 per wrong
  - Board: +10 per correct, -5 per wrong
  - Penalty: +10 per correct, no penalty for wrong
  - Revive: -2 per revive
- Verify grade calculation (must be based on final score)

### Issue 3: Phase Transition Edge Cases
- What happens if player gets caught during board solving?
- What happens if all players KO mid-hunt?
- What happens if time expires in intro exam?
- Ensure all transitions are clean with no orphaned timers

### Issue 4: Teacher Mode Management
- Ensure teacher mode changes trigger correctly:
  - Phase 1-2: "teacher" (calm)
  - Phase 3: "teacher" or "ghost" or "berserk" depending on player action
  - Phase 4: "responding" (move to whiteboard room)
  - After correct answer: "teacher" for 180s calm period
  - After wrong answer: "berserk" for 15s
  - Phase 5-7: "teacher" (calm)

### Issue 5: Revive System
- Verify medkit revive works:
  - Only works if medkit available
  - Only works if teammate near KO player
  - Only works if KO player exists
  - After revive: Player returns to Phase 3 (hunt)

### Issue 6: Objective Counter
- Ensure "Questions: X/10" counter:
  - Updates after each correct board answer
  - Visible in HUD during hunt
  - Accurate when board question respawns

### Issue 7: Item Spawning
- Verify item spawning logic:
  - 10 papers spawn at random locations
  - 10 chalk spawn at random locations
  - 1-2 keys spawn at random locations
  - 3-5 medkits spawn at random locations
  - Items DO NOT spawn in fixed locations (should be randomized per session)

---

## REQUIRED CLEANUP

### Code Quality
1. **Remove dead code** (backup logic, commented-out sections)
2. **Organize functions** logically:
   - Setup: `_ready()`, `_initialize()`, `_start_game()`
   - Phase logic: `_handle_phase_NAME()`
   - Transitions: `_transition_to_NAME()`
   - Game events: `player_caught()`, `submit_board_answer()`
   - Utilities: `get_final_grade()`, score calculations
3. **Add clear comments** explaining each phase and transition
4. **Ensure consistent naming** (use snake_case, clear intent)

### Variable Organization
- Group phase-related variables
- Group timer variables
- Group score/objective variables
- Group player/state variables
- Add comments explaining what each variable does

### Function Documentation
- Every public function needs docstring
- Every phase handler needs clear logic flow
- Transition logic should be obvious

---

## REQUIRED OUTPUT

I need you to:

1. **Review the existing Map58Game.gd code**
   - List all current functions and their purpose
   - Identify which phase handlers are complete
   - Identify which are missing or incomplete
   - List all signals and verify they fire correctly

2. **Clean up the code**
   - Remove dead code
   - Organize functions by category
   - Add clear comments
   - Ensure consistent style

3. **Verify all 8 phases work**
   - Phase 1 (Intro): 20s timer, 5 questions, submit logic
   - Phase 2 (Transition): 2.5s timer, lights/teacher/door
   - Phase 3 (Hunt): Variable timer, teacher patrol/detect
   - Phase 4 (Board): 120s timer, question display, scoring
   - Phase 5 (Penalty): No timer, 5 questions, escape or KO
   - Phase 5b (KO): Wait for revive or game over
   - Phase 6 (Escape): Detect players at exit gate
   - Phase 7 (Finished): Show results
   - Phase 8 (Lost): All players KO

4. **Ensure all transitions are clean**
   - Timer expires → next phase
   - Player action → next phase
   - Special event (caught) → specific phase
   - No orphaned state or timers

5. **Verify scoring system**
   - Track correct/wrong answers
   - Calculate final score
   - Assign grade (A/B/C/D)
   - Show on results screen

6. **Verify revive system**
   - Medkit consumption
   - KO player resurrection
   - Game over detection (all KO)
   - Return to hunt after revive

7. **Provide cleaned Map58Game.gd**
   - All 8 phases implemented
   - All signals firing
   - All scoring correct
   - All transitions working
   - Ready for production

8. **Provide testing checklist**
   - How to test each phase
   - What to watch for (timers, transitions, signals)
   - How to verify scoring
   - How to test revive system

---

## SPECIFIC REQUIREMENTS

### Must Have:
- ✅ All 8 phases implemented and distinct
- ✅ Phase transitions automated (timers + player actions)
- ✅ Scoring correct (intro + board + penalty + revive penalties)
- ✅ Grade calculation (A/B/C/D based on score)
- ✅ Revive system working (medkit restores KO player)
- ✅ Objective counter (X/10 questions)
- ✅ Teacher mode changes at correct times
- ✅ All signals firing (phase_changed, player_caught, game_finished, etc.)

### Should Have:
- ✅ Clear code comments
- ✅ Organized function categories
- ✅ Consistent naming
- ✅ Comprehensive docstrings
- ✅ No dead code

### Nice to Have:
- ✅ Phase timing debug mode (show current phase + timers in console)
- ✅ Edge case handling (what if timer expires exactly when player submits?)
- ✅ Graceful error handling (missing question database, etc.)

---

## CONSTRAINTS

- Do NOT modify Map58 geometry
- Do NOT change teacher behavior (that's in TeacherAI.gd)
- Do NOT remove any existing public functions (only add/improve)
- Preserve all existing signals
- Keep script name as Map58Game.gd
- Preserve all @export variables for tweaking in editor

---

## REFERENCE IMPLEMENTATION

The game should follow this structure:

```
func _ready():
  Load question database
  Build UI
  Optionally auto-start game

func _process(delta):
  Update current phase timers
  Check phase transition conditions
  Emit UI updates

func _start_game():
  Reset all variables
  Spawn player at desk
  Set phase to INTRO_EXAM
  Start 20s timer

func _set_phase(new_phase):
  phase = new_phase
  Emit phase_changed signal
  Initialize phase-specific logic

func phase-specific handlers:
  _handle_intro_exam(delta)
  _handle_transition(delta)
  _handle_hunt(delta)
  _handle_board_solving(delta)
  _handle_penalty_exam(delta)
  _handle_ko(delta)
  _handle_escape_ready(delta)
  _handle_finished(delta)

func game-event handlers:
  player_caught(player)
  submit_board_answer(answer)
  revive_player(target, healer)
  complete_escape()
  
func utility functions:
  get_final_grade()
  _calculate_score()
  _update_objective()
```

---

## TONE & STYLE

- Professional, production-ready
- Clear phase flow documentation
- Practical testing guidance
- Ready for team collaboration

---

**This is the complete cleanup brief for Map58Game.gd. Review the existing code, clean it up, ensure all 8 phases work correctly, and provide the production-ready version.**
