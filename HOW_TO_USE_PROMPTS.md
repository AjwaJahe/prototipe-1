# HOW TO USE THE 3 OPTIMIZATION PROMPTS

**Quick start guide untuk menggunakan ketiga prompt dengan ChatGPT**

---

## OVERVIEW

Anda memiliki 3 prompt yang dirancang untuk mengoptimalkan dan membersihkan code game Anda:

| Prompt | File | Fokus | Output |
|--------|------|-------|--------|
| **Prompt 1** | `PROMPT_1_OPTIMIZE_TEACHERAI.md` | Fix lag di TeacherAI.gd | Optimized TeacherAI.gd (raycast throttling + caching) |
| **Prompt 2** | `PROMPT_2_CLEAN_MAP58GAME.md` | Formalize 8 phases di Map58Game.gd | Clean Map58Game.gd (semua fase verified) |
| **Prompt 3** | `PROMPT_3_OPTIMIZE_PLAYER.md` | Clean Player.gd + inventory | Optimized Player.gd (movement + stamina + inventory) |

---

## STEP-BY-STEP WORKFLOW

### STEP 1: PREPARE CHATGPT

1. Buka ChatGPT atau Claude (recommend Claude untuk code panjang)
2. Mulai conversation baru
3. Optional: Set system prompt dengan `You are a professional Godot 4.7.2 game developer`

---

### STEP 2: SEND PROMPT 1 (TEACHERAI OPTIMIZATION)

**Waktu estimasi**: 5-10 menit untuk ChatGPT ngerjakan + Anda review

**Langkah**:
1. Buka file `PROMPT_1_OPTIMIZE_TEACHERAI.md`
2. Salin SELURUH isi file
3. Paste ke ChatGPT
4. Tunggu jawaban

**Expected Output**:
- Analisis TeacherAI.gd yang ada
- 5 optimisasi spesifik
- Optimized TeacherAI.gd code yang siap pakai
- Testing checklist

**Setelah dapat output**:
1. Review code yang diberikan
2. Copy code ke `TeacherAI.gd` di Godot
3. Test di Godot: apakah FPS naik saat teacher dekat?
4. Jika OK → lanjut ke Prompt 2

---

### STEP 3: SEND PROMPT 2 (MAP58GAME CLEANUP)

**Waktu estimasi**: 10-15 menit

**Langkah**:
1. Buka file `PROMPT_2_CLEAN_MAP58GAME.md`
2. Salin SELURUH isi file
3. Paste ke ChatGPT (conversation yang sama atau baru)
4. Tunggu jawaban

**Expected Output**:
- Review Map58Game.gd yang ada
- List of issues found
- Cleaned Map58Game.gd dengan:
  - Semua 8 phases implemented
  - All signals firing correctly
  - Scoring logic correct
  - Phase transitions working
- Testing checklist

**Setelah dapat output**:
1. Review code
2. Copy ke `Map58Game.gd` di Godot
3. Test: lakukan full game playthrough
   - Intro exam phase ✓
   - Transition phase ✓
   - Hunt phase ✓
   - Board solving phase ✓
   - Penalty exam (simulate capture) ✓
   - Escape phase ✓
   - Check scoring & grade ✓
4. Jika semua OK → lanjut ke Prompt 3

---

### STEP 4: SEND PROMPT 3 (PLAYER OPTIMIZATION)

**Waktu estimasi**: 10-15 menit

**Langkah**:
1. Buka file `PROMPT_3_OPTIMIZE_PLAYER.md`
2. Salin SELURUH isi file
3. Paste ke ChatGPT
4. Tunggu jawaban

**Expected Output**:
- Review Player.gd yang ada
- List of issues found
- Optimized Player.gd dengan:
  - Movement working (walk/run/crouch/jump)
  - Stamina system correct
  - Inventory system implemented (if missing)
  - Footsteps audio working
  - Status states (KO, intro_locked) handled
- Testing checklist

**Setelah dapat output**:
1. Review code
2. Copy ke `Player.gd` di Godot
3. Test player mechanics:
   - Normal walk (WASD @ 15 u/s) ✓
   - Running (SHIFT @ 10 u/s + stamina drain) ✓
   - Crouching (CTRL @ 2.5 u/s) ✓
   - Jumping (SPACE) ✓
   - Stamina recovery ✓
   - Stamina UI shows % ✓
   - Footsteps audio plays ✓
   - Inventory pickup works ✓
4. If OK → Game is ready to test full flow

---

## FULL TESTING WORKFLOW (AFTER ALL 3 PROMPTS)

After applying all 3 optimized scripts, do this end-to-end test:

### Test Scenario 1: Complete Game Flow
1. **Phase 1 (Intro Exam - 20 sec)**
   - [ ] Player spawns seated
   - [ ] 5 questions appear
   - [ ] Timer counts down
   - [ ] Can submit answers
   - [ ] Score calculated

2. **Phase 2 (Transition - 2.5 sec)**
   - [ ] Teacher becomes ghost
   - [ ] Lights blackout
   - [ ] Door closes
   - [ ] Audio plays

3. **Phase 3 (Hunt)**
   - [ ] Teacher patrols random waypoints
   - [ ] Player can walk/run/crouch
   - [ ] Can collect items (paper, chalk, key)
   - [ ] Stamina drains/recovers
   - [ ] Footsteps audible
   - [ ] No lag (FPS 30-60)

4. **Phase 4 (Board Solving)**
   - [ ] Whiteboard appears with question
   - [ ] 120s timer
   - [ ] Can enter answer
   - [ ] Correct answer: +10 score, question respawns elsewhere
   - [ ] Wrong answer: teacher goes berserk, -5 score

5. **Repeat Phase 3-4 until 10 questions solved**
   - [ ] Difficulty scales (Q1-2 easier, Q5+ harder)
   - [ ] Solved counter shows 1/10, 2/10, ... 10/10

6. **Phase 6 (Escape Ready)**
   - [ ] After 10 questions: gate unlocks
   - [ ] Teacher calm
   - [ ] Players can navigate to exit

7. **Phase 7 (Finished)**
   - [ ] Exit reached
   - [ ] Final score calculated
   - [ ] Grade displayed (A/B/C/D)

### Test Scenario 2: Teacher AI
- [ ] Teacher detects player (vision + hearing)
- [ ] Teacher chases at correct speed
- [ ] Teacher loses target and scans
- [ ] Teacher opens/closes doors
- [ ] Teacher doesn't clip walls
- [ ] No lag during chase (FPS 30-60)

### Test Scenario 3: Player Mechanics
- [ ] Walk smooth, no stuttering
- [ ] Run drains stamina correctly
- [ ] Crouch silences footsteps
- [ ] Jump works on ground only
- [ ] Stamina recovers when not running
- [ ] Camera height lerps smoothly (stand/crouch)
- [ ] Inventory holds max 5 items
- [ ] Item pickup works (walk over item)

### Test Scenario 4: Multiplayer (4 players)
- [ ] All 4 players spawn correctly
- [ ] Teacher targets all players correctly
- [ ] Inventory separate per player
- [ ] Medkit revive works
- [ ] Score shared
- [ ] All players must escape to win
- [ ] All players KO = lose

### Test Scenario 5: Performance
- [ ] Intro phase: 60 FPS
- [ ] Hunt phase (no teacher nearby): 60 FPS
- [ ] Hunt phase (teacher chasing): 30-60 FPS (never drop below 30)
- [ ] Transition phase: 60 FPS
- [ ] Escape phase: 60 FPS
- [ ] No lag spikes

---

## TROUBLESHOOTING

### If Prompt 1 Output Doesn't Compile
**Problem**: TeacherAI.gd has syntax errors  
**Solution**: 
1. Check Godot version (must be 4.7.2)
2. Ask ChatGPT: "Fix these Godot 4.7.2 syntax errors: [paste error messages]"
3. Apply fixes manually in Godot (red squiggly lines show errors)

### If Prompt 2 Output Breaks Game
**Problem**: Map58Game.gd causes crashes  
**Solution**:
1. Check for null references (players/teacher not found)
2. Ask ChatGPT: "Why is Map58Game.gd getting null reference when accessing teacher?"
3. Verify nodes exist in scene tree
4. Rollback to previous version if needed (Git can help)

### If Prompt 3 Output Has Movement Issues
**Problem**: Player walks but feels slow/fast  
**Solution**:
1. Verify speed constants (15.0, 10.0, 2.5)
2. Ask ChatGPT: "Movement speed feels [too slow/too fast], should be [target speed]"
3. Adjust @export variables in Godot editor
4. Test with different values

### If Performance Still Lags
**Problem**: Game still drops FPS  
**Solution**:
1. Use Godot Profiler (Debug → Profiler)
2. Identify which script uses most CPU
3. Ask ChatGPT: "My [script name] is using X% CPU. How to optimize?"
4. Apply additional optimizations

---

## PROMPT ORDERING

**IMPORTANT**: Use prompts in this order:
1. ✅ Prompt 1 (TeacherAI) FIRST
2. ✅ Prompt 2 (Map58Game) SECOND
3. ✅ Prompt 3 (Player) THIRD

**Why this order?**
- Prompt 1 fixes performance (lag issue)
- Prompt 2 verifies game logic (all phases)
- Prompt 3 polishes player experience (movement + inventory)

If you reverse the order, you might miss performance issues or test broken game logic.

---

## ALTERNATIVE: USE CLAUDE INSTEAD OF CHATGPT

**Claude might be better for long code** because:
- Handles larger context windows
- Better at understanding complex game logic
- Fewer truncation issues

**How to use Claude**:
1. Go to claude.ai
2. Create new conversation
3. Paste entire prompt (same as ChatGPT)
4. Wait for response
5. Copy output code to Godot

---

## ALTERNATIVE: CUSTOM TWEAKS

After getting the optimized code, you might want to customize:

**Ask ChatGPT**:
- "Can you make teacher speed adjustable via @export?"
- "Can you add difficulty selector (Easy/Normal/Hard)?"
- "Can you implement procedural item spawning?"
- "Can you add audio volume controls?"

**Then follow same workflow**: Get code → Test → Verify

---

## CHECKLIST: BEFORE YOU START

Before sending prompts to ChatGPT, verify:

- [ ] You have Godot 4.7.2 installed
- [ ] Project is open and runs
- [ ] Current game is playable (even with lag)
- [ ] You can copy/paste code into Godot
- [ ] You have the 3 prompt files ready
- [ ] You know how to reload scripts in Godot (F5 or Script → Reload Current Script)
- [ ] You have a backup (Git commit or manual backup)

---

## WHAT TO DO WITH THE OPTIMIZED CODE

### Step A: Save Current Code (Backup)
```bash
git add -A
git commit -m "Backup before optimization"
```

### Step B: Apply Optimized Code
1. Copy `TeacherAI.gd` code from ChatGPT
2. Open `TeacherAI.gd` in Godot
3. Select ALL (Ctrl+A)
4. Delete
5. Paste ChatGPT code
6. Save (Ctrl+S)

### Step C: Test in Godot
1. Run game (F5)
2. Check for errors in console
3. If no errors, test game flow

### Step D: Repeat for Map58Game.gd and Player.gd

### Step E: Commit to Git
```bash
git add -A
git commit -m "Apply Prompt 1-3 optimizations"
```

---

## EXPECTED RESULTS

After applying all 3 prompts:

✅ **Performance**
- FPS: 30-60 (consistent, no drops)
- Teacher AI: No lag spikes
- No raycast stutter

✅ **Game Logic**
- All 8 phases work
- Scoring accurate
- Grade calculation correct
- Phase transitions smooth

✅ **Player Experience**
- Movement smooth and responsive
- Stamina system clear and fair
- Inventory intuitive
- Audio feedback satisfying

✅ **Code Quality**
- Clean, readable code
- Well-commented
- Organized functions
- Production-ready

---

## NEXT STEPS AFTER OPTIMIZATION

Once all 3 prompts are applied and tested:

1. **Create 4 remaining prompts** (for other systems):
   - Prompt 4: Item Spawning System
   - Prompt 5: Question Database & Difficulty
   - Prompt 6: UI/HUD System
   - Prompt 7: Audio System

2. **Full game test** with 4 players

3. **Balance & Polish**:
   - Adjust difficulty
   - Fine-tune speeds/values
   - Add visual polish

4. **Release & Deploy**

---

## SUPPORT

If you have issues:

1. **Check error messages** in Godot console
2. **Paste error message into ChatGPT**: "I get this error in Godot: [error]. How to fix?"
3. **Reference this doc**: Share link if ChatGPT needs context
4. **Commit to Git**: Track all changes

---

**You're ready to optimize! Start with Prompt 1 →**

Good luck! 🎮
