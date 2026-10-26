# Prompt 5: Question Database & Difficulty Scaling

**Use this prompt with ChatGPT to create question system with difficulty scaling**

---

## CONTEXT

You are a professional Godot 4.7.2 game systems programmer. I need you to create a question database and difficulty scaling system for math questions in a co-op horror school game.

**Project**: Map58 School Horror Game (Godot 4.7.2)  
**Current State**: Questions may be hardcoded or stored inefficiently  
**Target**: Scalable question database with automatic difficulty progression  
**Success Metric**: Questions pulled from database, difficulty increases as game progresses, all 10 board questions unique and varied

---

## QUESTION STRUCTURE

### Question Types
All questions are **math/logic based with numeric answers**. Examples:
- Basic arithmetic: "5 + 3 = ?"
- Algebra: "2x + 4 = 10, solve for x"
- Geometry: "What is the area of a square with side 4?"
- Logic puzzles: "What number comes next? 2, 4, 8, 16..."

### Difficulty Levels
```
Level 1 (SD - Sekolah Dasar / Elementary): Simple addition/subtraction
  Example: 3 + 5 = ?
  Expected student: Age 7-12
  Estimate time: < 10 seconds

Level 2 (SD Advanced): Multiplication, simple word problems
  Example: 6 × 7 = ?
  Expected student: Age 10-12
  Estimate time: 10-20 seconds

Level 3 (SMP - Sekolah Menengah Pertama / Junior High): Basic algebra, fractions
  Example: 2x + 3 = 11, solve for x (answer: 4)
  Expected student: Age 13-15
  Estimate time: 30-45 seconds

Level 4 (SMA - Sekolah Menengah Atas / Senior High): Quadratic, geometry
  Example: What is √144 + 5² = ? (answer: 37)
  Expected student: Age 16-18
  Estimate time: 45-60 seconds

Level 5 (Advanced/University): Complex algebra, trigonometry
  Example: Solve x² - 5x + 6 = 0 (answers: 2 or 3)
  Expected student: Age 18+
  Estimate time: 60+ seconds
```

### Answer Format
- Numeric only (integer or decimal)
- Always positive unless specified negative
- For multiple valid answers (e.g., x² = 4, answers 2 or -2), accept both
- No unit required (just number)
- Tolerance for decimals: ±0.01

---

## GAME QUESTION FLOW

### Intro Exam (Phase 1)
- **Count**: 5 questions
- **Difficulty**: Level 1-2 (easy)
- **Time per question**: Auto (20 sec total for all 5)
- **Purpose**: Establish baseline, set hunt duration
- **Scoring**: +10 per correct, -5 per wrong

### Board Questions (Phase 4)
- **Count**: 10 questions total (to escape)
- **Difficulty Progression**:
  - Q1-Q2: Level 3
  - Q3-Q4: Level 4
  - Q5-Q10: Level 5
- **Time per question**: 120 seconds
- **Purpose**: Core gameplay challenge
- **Scoring**: +10 per correct, -5 per wrong
- **Difficulty increases** as player progresses (not randomized order)

### Penalty Exam (Phase 5)
- **Count**: 5 questions
- **Difficulty**: Level 1-2 (easy, less stress)
- **Time per question**: Infinite (no timer)
- **Purpose**: Punishment for capture but still solvable
- **Scoring**: +10 per correct, no penalty for wrong (survival mode)

---

## DATABASE STRUCTURE

### Option A: GDScript Dictionary (Recommended)
```gdscript
var questions_db = {
  1: [  # Level 1
    { "question": "3 + 5 = ?", "answer": 8, "id": "L1_001" },
    { "question": "10 - 4 = ?", "answer": 6, "id": "L1_002" },
    # ... more level 1 questions
  ],
  2: [  # Level 2
    { "question": "6 × 7 = ?", "answer": 42, "id": "L2_001" },
    # ... more level 2 questions
  ],
  # ... etc for levels 3, 4, 5
}
```

### Option B: JSON File (More scalable)
```json
{
  "1": [
    { "question": "3 + 5 = ?", "answer": 8, "id": "L1_001" },
    { "question": "10 - 4 = ?", "answer": 6, "id": "L1_002" }
  ],
  "2": [
    { "question": "6 × 7 = ?", "answer": 42, "id": "L2_001" }
  ]
}
```

### Minimum Questions Per Level
- Level 1: At least 20 unique questions
- Level 2: At least 20 unique questions
- Level 3: At least 20 unique questions (Q1-2 use these)
- Level 4: At least 20 unique questions (Q3-4 use these)
- Level 5: At least 40 unique questions (Q5-10 use these)

**Total minimum**: 120 unique questions

---

## QUESTION DATABASE SCRIPT

### Script: QuestionDatabase.gd
Should handle:
- Load questions from JSON or hardcoded dictionary
- Track which questions used (prevent duplicates per session)
- Pull questions by difficulty level
- Handle intro exam vs board questions
- Handle penalty exam questions
- Provide question text and validate answers

### Main Functions
```gdscript
func _ready():
  # Load questions from JSON or init dictionary
  _load_questions()

func get_intro_question(index: int) -> Dictionary:
  # Return intro exam question (index 0-4, level 1-2)
  # Return: { "question": "...", "answer": 8, "id": "..." }

func get_board_question(question_number: int) -> Dictionary:
  # Return board question based on number (1-10)
  # Q1-2 = Level 3, Q3-4 = Level 4, Q5-10 = Level 5
  # Ensure no repeats in session
  # Return: { "question": "...", "answer": 42, "id": "..." }

func get_penalty_question(index: int) -> Dictionary:
  # Return penalty exam question (index 0-4, level 1-2)

func check_answer(answer: int, correct_answer: int) -> bool:
  # Validate answer (allow ±0.01 tolerance for decimals)
  # Return true if correct, false if wrong

func check_answer_multiple(answer: int, correct_answers: Array) -> bool:
  # For questions with multiple valid answers (e.g., quadratic equations)
  # Example: 2 or 3 both valid for x² - 5x + 6 = 0

func reset_session():
  # Clear used questions for new game session
  # Called at start of game

func get_question_count_by_level(level: int) -> int:
  # Return how many questions available at this level

func get_statistics() -> Dictionary:
  # For debugging: return stats about questions used this session
  # { "intro_used": 5, "board_used": 10, "penalty_used": 5 }
```

---

## DIFFICULTY SCALING LOGIC

### Hunt Duration Scaling (Phase 3)
```
Base hunt time = 180 seconds
Intro correct answers = number of correct answers in Phase 1 (0-5)
Formula: hunt_duration = Base + (correct_answers × 30), capped at 300

Examples:
- 0 correct: 180 sec (3 min)
- 2 correct: 240 sec (4 min)
- 5 correct: 330 sec → capped at 300 sec (5 min max)
```

### Question Difficulty Progression (Phase 4)
```
Q1-2: Level 3 difficulty (SMP level)
Q3-4: Level 4 difficulty (SMA level)
Q5-10: Level 5 difficulty (Advanced level)

No randomization - questions get harder as player solves more
```

### Teacher Behavior Scaling
- Easier questions (intro + penalty): Teacher not threat (calm mode)
- Harder questions (board Q5-10): Teacher more aggressive (berserk after wrong answer)

---

## INTEGRATION POINTS

### Integration with Map58Game.gd
```gdscript
# In Map58Game.gd
var question_db = QuestionDatabase.new()

func _ready():
  question_db.reset_session()

func _handle_intro_exam(delta):
  # Get question from database
  current_question = question_db.get_intro_question(intro_index)
  display_question(current_question["question"])

func submit_intro_answer(answer: int):
  if question_db.check_answer(answer, current_question["answer"]):
    score += 10
    intro_correct += 1
  else:
    score -= 5

func _handle_board_solving(delta):
  current_question = question_db.get_board_question(solved_papers + 1)
  display_on_whiteboard(current_question["question"])

func submit_board_answer(answer: int):
  if question_db.check_answer(answer, current_question["answer"]):
    score += 10
    solved_papers += 1
    paper_respawn_requested.emit()
    teacher.change_mode("teacher")  # Calm period
  else:
    score -= 5
    teacher.change_mode("berserk")  # Punishment
```

### Integration with UI System (Prompt 6)
```gdscript
# In UIManager.gd
func display_question(question_text: String):
  whiteboard_label.text = question_text

func display_answer_input():
  answer_input.text = ""
  answer_input.grab_focus()
```

---

## CURRENT ISSUES TO FIX

### Issue 1: Questions Hardcoded or Missing
- Problem: No centralized question database
- Solution: Create QuestionDatabase.gd with all questions

### Issue 2: No Difficulty Progression
- Problem: Questions same difficulty throughout
- Solution: Implement level-based pulling (Q1-2=Level3, Q3-4=Level4, Q5=Level5)

### Issue 3: Question Repeats
- Problem: Same question appears multiple times per session
- Solution: Track used questions, randomize within level, no duplicates

### Issue 4: Answer Validation
- Problem: Only exact match or loose validation
- Solution: Implement check_answer with tolerance for decimals

### Issue 5: No Multiple Answer Support
- Problem: Questions with multiple correct answers not handled
- Solution: Implement check_answer_multiple for quadratic equations, etc.

---

## REQUIRED OUTPUT

I need you to:

1. **Create QuestionDatabase.gd script**
   - Load questions (either GDScript dict or JSON)
   - All 120+ unique questions across 5 difficulty levels
   - Provide get_intro_question(), get_board_question(), get_penalty_question()
   - Implement check_answer() with tolerance
   - Implement check_answer_multiple() for multiple valid answers
   - Track used questions per session
   - reset_session() function

2. **Provide Question Content (GDScript or JSON)**
   - Minimum 20 per level (preferably 40+ for levels 3-5)
   - Mix of arithmetic, algebra, geometry, logic
   - Appropriate difficulty per level
   - All with numeric answers
   - Varied topics to avoid repetition

3. **Provide Difficulty Scaling Logic**
   - How questions pull by number (Q1=Level3, Q5=Level5, etc.)
   - How to prevent duplicates
   - How to randomize within level

4. **Provide Integration Guide**
   - How Map58Game.gd calls question database
   - What signals to emit
   - How to validate answers
   - How to update score

5. **Provide Testing Checklist**
   - How to verify questions load correctly
   - How to test difficulty progression
   - How to test answer validation
   - How to test no duplicates

---

## CONSTRAINTS

- Do NOT hardcode questions in Map58Game.gd (use separate database)
- Do NOT use external APIs (all questions must be local)
- Keep answers numeric (integers or simple decimals)
- Ensure questions are culturally appropriate and mathematically sound
- Make questions challenging but solvable within time limits

---

## TONE & STYLE

- Professional, scalable system
- Clear difficulty progression
- Practical question variety
- Ready for customization

---

**This is the question database brief. Proceed with implementation. Output the complete QuestionDatabase.gd script with all questions, ready for production.**
