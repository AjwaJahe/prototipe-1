# Prompt 6: UI/HUD System & Status Display

**Use this prompt with ChatGPT to create the complete UI/HUD system**

---

## CONTEXT

You are a professional Godot 4.7.2 UI/UX programmer. I need you to create a comprehensive HUD system that displays game status, objectives, and player feedback in real-time.

**Project**: Map58 School Horror Game (Godot 4.7.2)  
**Current State**: Basic UI may exist but incomplete or inconsistent  
**Target**: Professional, polished HUD with all necessary information  
**Success Metric**: All HUD elements visible, accurate, and responsive during gameplay

---

## HUD LAYERS & STRUCTURE

### Layer 1: Gameplay HUD (In-Game)
Displays during Phases 1, 3, 4, 5, 6 (active gameplay)

**Top-Left Corner:**
- "OBJECTIVE: Questions X/10" — Shows solved question count
- "HUNT TIME: XX:XX" — Countdown timer (only in Phase 3)
- "MODE: [INTRO/HUNT/SOLVING/ESCAPED]" — Current phase name

**Top-Right Corner:**
- "SCORE: XXX" — Running total score
- "STAMINA: XX%" — Stamina bar + percentage

**Bottom-Left Corner:**
- "INVENTORY [X/5]:" — Item count and list of held items with icons
  - Paper icon × quantity
  - Chalk icon × quantity
  - Key icon (if held)
  - Medkit icon × quantity
  - etc.

**Bottom-Center:**
- **Teacher Proximity Alert** — Red flash/glow when teacher close (< 10 units)
- Audio cue + visual indicator

**Center Screen:**
- **Status Messages** — Temporary messages (3-4 seconds then fade)
  - "Guru meninggalkan kelas dan melayang. Pintu tertutup, lampu padam..."
  - "Kamu menjawab soal dengan benar! +10 poin."
  - "SALAH! Guru masuk mode BERSEK selama 15 detik."
  - "Medkit digunakan. Teman selamat!"
  - etc.

**Right Edge:**
- **Teacher Distance Indicator** — Visual/audio proximity warning
  - Green (safe): > 15 units
  - Yellow (caution): 10-15 units
  - Red (danger): < 10 units

### Layer 2: Board Solving HUD (Phase 4)
Displays during whiteboard question answering

**Center Screen:**
- **Whiteboard Display**:
  - Title: "SOAL KE [X/10]"
  - Question text (large, readable)
  - Time remaining: "WAKTU: XX detik"
  - Input field for answer (big, prominent)
  - "ENTER untuk kirim jawaban" hint

**Bottom:**
- Answer feedback (before submitting):
  - "Ketik angka dan tekan ENTER"

### Layer 3: Intro Exam HUD (Phase 1)
Displays during 20-second intro exam

**Center Screen:**
- **Exam Display**:
  - "KUIS AWAL - 20 DETIK"
  - Question counter: "SOAL [X/5]"
  - Question text
  - Time remaining bar (visual countdown)
  - Multiple choice or input field
  - "OTOMATIS LANJUT KE FASE BERIKUTNYA" message

### Layer 4: Results Screen (Phase 7 & 8)
Displays after game end (win or lose)

**Full Screen:**
- Background (semi-transparent black)
- Large title: "SELESAI!" or "KALAH!"
- **Results Box** (centered):
  ```
  NILAI AKHIR: A
  SKOR TOTAL: 185
  SOAL TERJAWAB: 10/10
  WAKTU ESCAPE: 5 menit 32 detik
  
  RANKING: Luar Biasa!
  
  [ULANGI PERMAINAN]  [MENU UTAMA]  [KELUAR]
  ```

### Layer 5: Pause Menu (Optional)
Can pause game mid-Phase 3 or 4

**Center Screen:**
- "GAME PAUSED"
- Buttons:
  - [LANJUTKAN]
  - [PENGATURAN]
  - [KEMBALI KE MENU]

---

## HUD ELEMENTS DETAILED

### 1. Objective Counter
```
Position: Top-left
Text: "SOAL: 5/10"
Updates: After each correct board answer
Color: White (normal), Green (highlight)
Font size: 24px
```

### 2. Score Display
```
Position: Top-right
Text: "SKOR: 125"
Updates: Every frame (or after answer submission)
Color: Yellow/Gold
Font size: 24px
```

### 3. Hunt Timer
```
Position: Top-center
Text: "WAKTU: 4:32"
Visible: Only in Phase 3 (Hunt)
Updates: Every frame (countdown)
Color: White (normal), Red (< 30 sec warning)
Font size: 28px
```

### 4. Stamina Bar
```
Position: Top-right (below score)
Type: ProgressBar (horizontal)
Value: 0.0 - 1.0 (0-100%)
Label: "STAMINA 85%"
Color: Green (normal), Orange (low), Red (exhausted)
Font size: 16px
Visible: Always (during gameplay)
```

### 5. Inventory Display
```
Position: Bottom-left
Format: "INVENTORI [3/5]:"
  - Kertas ×2
  - Kapur ×1
Updates: When item picked up
Font size: 18px
Icons: Small sprite per item type
```

### 6. Teacher Proximity Indicator
```
Position: Bottom-center + Screen edges
Type: Visual: Red vignette/glow + screen flash
Audio: Proximity beep (frequency increases as teacher closer)
Triggers: When teacher < 10 units away
Intensity: Scales with distance
```

### 7. Status Messages (Center Screen)
```
Position: Center of screen
Type: Temporary message, 3-4 seconds
Animation: Fade in (0.3s) → Stay (3s) → Fade out (0.5s)
Font size: 28px
Color: Yellow/White
Examples:
  - "✓ BENAR! +10 Poin"
  - "✗ SALAH! -5 Poin. Guru masuk BERSEK!"
  - "🔓 Gerbang Sekolah Terbuka!"
  - "💊 Rekan Diselamatkan"
```

### 8. Phase Indicator
```
Position: Top-left (small, below objective)
Text: Current phase name
Examples: "FASE: Intro Exam", "FASE: Hunt", "FASE: Board Solving"
Font size: 14px
Color: Gray/Dim
```

---

## UI SCENE STRUCTURE (Godot)

```
CanvasLayer (HUD_Layer)
├── MarginContainer (root)
│   ├── HBoxContainer (Top Container)
│   │   ├── VBoxContainer (Top-Left)
│   │   │   ├── Label (Objective)
│   │   │   ├── Label (Phase)
│   │   │   └── Label (Hunt Timer)
│   │   ├── Control (Spacer)
│   │   └── VBoxContainer (Top-Right)
│   │       ├── Label (Score)
│   │       └── ProgressBar (Stamina)
│   │
│   ├── CenterContainer (Center Messages)
│   │   └── Label (Status Message)
│   │
│   ├── VBoxContainer (Bottom Container)
│   │   ├── HBoxContainer (Bottom-Left)
│   │   │   └── Label (Inventory)
│   │   └── HBoxContainer (Bottom-Center)
│   │       └── Control (Proximity Indicator)
│   │
│   └── Panel (Teacher Distance Warning - overlay)

CanvasLayer (Board_Solving_HUD)
├── CenterContainer
│   ├── Panel (Whiteboard Frame)
│   │   ├── VBoxContainer
│   │   │   ├── Label (Question Title)
│   │   │   ├── Label (Question Text)
│   │   │   ├── LineEdit (Answer Input)
│   │   │   ├── Label (Time Remaining)
│   │   │   └── Label (Hint)

CanvasLayer (Results_Screen)
├── ColorRect (Background)
├── CenterContainer
│   └── Panel (Results Box)
│       └── VBoxContainer
│           ├── Label (Title: SELESAI!)
│           ├── VBoxContainer (Results)
│           │   ├── Label (Grade: A)
│           │   ├── Label (Score: 185)
│           │   ├── Label (Questions: 10/10)
│           │   └── Label (Time: 5:32)
│           ├── Label (Ranking)
│           └── HBoxContainer (Buttons)
│               ├── Button (Ulangi)
│               ├── Button (Menu)
│               └── Button (Keluar)
```

---

## HUD SCRIPT STRUCTURE

### Main Script: UIManager.gd
```gdscript
extends CanvasLayer

# References to UI elements
@onready var objective_label = $MarginContainer/Top/TopLeft/ObjectiveLabel
@onready var score_label = $MarginContainer/Top/TopRight/ScoreLabel
@onready var stamina_bar = $MarginContainer/Top/TopRight/StaminaBar
@onready var hunt_timer_label = $MarginContainer/Top/TopCenter/HuntTimerLabel
@onready var inventory_label = $MarginContainer/Bottom/BottomLeft/InventoryLabel
@onready var status_message_label = $MarginContainer/Center/StatusMessageLabel
@onready var proximity_indicator = $MarginContainer/Bottom/ProximityIndicator

func _ready():
  # Connect to game signals
  game_manager.phase_changed.connect(_on_phase_changed)
  game_manager.objective_changed.connect(_on_objective_changed)
  game_manager.game_finished.connect(_on_game_finished)
  
  player.stamina_changed.connect(_on_stamina_changed)
  player.inventory_changed.connect(_on_inventory_changed)

func _process(delta):
  # Update hunt timer if active
  if current_phase == "hunt":
    hunt_timer_label.text = format_time(remaining_hunt_time)

func show_status_message(message: String):
  # Display temporary status message
  status_message_label.text = message
  # Fade in, stay, fade out animation

func update_objective(solved: int, target: int):
  objective_label.text = "SOAL: %d/%d" % [solved, target]

func update_score(score: int):
  score_label.text = "SKOR: %d" % score

func update_stamina(current: float, max: float):
  stamina_bar.value = current / max
  stamina_bar.get_node("Label").text = "STAMINA %.0f%%" % ((current/max) * 100)

func update_inventory(items: Array):
  var inv_text = "INVENTORI [%d/5]:\n" % len(items)
  # Build inventory display text

func show_proximity_warning(distance: float):
  # Show visual/audio warning based on distance

func show_board_question(question_text: String, time_limit: int):
  # Display whiteboard with question

func show_results(grade: String, score: int, questions_solved: int, time_elapsed: int):
  # Display results screen with buttons
```

---

## SIGNAL INTEGRATION

### Signals from GameManager.gd
```gdscript
signal phase_changed(phase: String)
signal objective_changed(solved: int, target: int)
signal score_changed(score: int)
signal game_finished()
signal show_message(message: String, duration: float)
```

### Signals from Player.gd
```gdscript
signal stamina_changed(current: float, max: float)
signal inventory_changed(items: Array)
```

### Signals from TeacherAI.gd
```gdscript
signal proximity_changed(distance: float)
```

---

## INTERNATIONALIZATION (I18N)

All text should be in Indonesian (Bahasa Indonesia) with option for English.

**Common Messages:**
```
Indonesian → English
"SOAL: 5/10" → "QUESTIONS: 5/10"
"SKOR: 125" → "SCORE: 125"
"INVENTORI" → "INVENTORY"
"STAMINA" → "STAMINA"
"BENAR! +10" → "CORRECT! +10"
"SALAH! -5" → "WRONG! -5"
"GURU BERSEK" → "TEACHER BERSERK"
"SELESAI!" → "FINISHED!"
"KALAH!" → "DEFEAT!"
"NILAI: A" → "GRADE: A"
```

---

## CURRENT ISSUES TO FIX

### Issue 1: Missing or Incomplete HUD
- Problem: Some HUD elements missing (stamina bar, proximity warning)
- Solution: Create complete HUD layer with all elements

### Issue 2: Inconsistent Styling
- Problem: Fonts, colors, sizes inconsistent
- Solution: Define UI theme (colors, font sizes, spacing)

### Issue 3: No Status Messages
- Problem: No feedback when actions occur
- Solution: Implement status message system with animations

### Issue 4: Results Screen Missing
- Problem: After game ends, no results displayed
- Solution: Create results screen with grade, score, time

### Issue 5: Proximity Warning Missing
- Problem: No visual/audio warning when teacher near
- Solution: Implement proximity indicator (screen flash + audio beep)

---

## REQUIRED OUTPUT

I need you to:

1. **Create UIManager.gd script**
   - Manage all HUD elements
   - Connect to game/player/teacher signals
   - Update displays every frame
   - Handle status messages (fade in/out)
   - Show/hide elements based on phase

2. **Create HUD Scene (HUD.tscn)**
   - Proper node hierarchy
   - All HUD elements positioned correctly
   - Buttons with signal connections
   - Responsive layout (scales to different resolutions)

3. **Create Results Screen Scene (ResultsScreen.tscn)**
   - Display final grade, score, time
   - Buttons for restart/menu/exit
   - Professional styling

4. **Provide Theming/Styling**
   - Font definitions (size, color, shadow)
   - Color scheme (text, backgrounds, highlights)
   - Spacing and alignment rules
   - Optional: Dark theme vs light theme

5. **Provide Status Message Catalog**
   - All in-game messages
   - When each message triggers
   - Duration and styling per message

6. **Provide Testing Checklist**
   - How to verify all HUD elements visible
   - How to test status messages
   - How to test results screen
   - How to test responsiveness

---

## CONSTRAINTS

- Do NOT hardcode UI strings (use constants or translation file)
- Keep UI responsive (scale to different resolutions)
- Do NOT modify game logic (UI is display-only)
- Preserve existing scene structure
- Ensure all text is readable (good contrast, appropriate size)

---

## TONE & STYLE

- Professional, polished appearance
- Clear information hierarchy
- Responsive and fluid animations
- Consistent with horror/dark theme
- Text primarily in Indonesian

---

**This is the UI/HUD system brief. Proceed with implementation. Output the complete UIManager.gd script, HUD.tscn scene, and ResultsScreen.tscn scene ready for production.**
