# Prompt 1: Optimize TeacherAI.gd for Performance

**Use this prompt with ChatGPT to fix lag issues in TeacherAI.gd**

---

## CONTEXT

You are a professional Godot 4.7.2 performance engineer. I need you to optimize an existing TeacherAI script that is causing frame rate drops.

**Project**: Map58 School Horror Game (Godot 4.7.2)  
**Current Issue**: Game lags when teacher is near player (FPS drops from 60 to 30-40)  
**Root Cause**: TeacherAI.gd performs too many raycasts and rebuilds routes every frame  
**Target**: Fix lag while keeping teacher behavior identical  
**Success Metric**: Maintain 30-60 FPS during active teacher chase

---

## GAME CONTEXT (8 PHASES)

Phase 1-2: Intro + Transition (teacher not threat)
Phase 3: HUNT (teacher patrols) ← **Most performance critical**
Phase 4: BOARD_SOLVING (teacher chases) ← **Lag happens here**
Phase 5-8: Penalty/KO/Escape (teacher less active)

---

## CURRENT BEHAVIOR TO PRESERVE

Teacher has 4 modes:
- **teacher**: 3.5 u/s, patrol random waypoints
- **ghost**: 10.0 u/s, chase detected target
- **berserk**: 10.0 u/s, chase aggressively for 15 seconds
- **responding**: 3.5 u/s, move toward player at whiteboard

Teacher detection:
- Vision: 3× eye height (≈5.1 units), requires line-of-sight
- Hearing: 8.0 units, no line-of-sight needed
- If target lost: stand still and scan last known position

Teacher movement:
- Patrol random waypoints when in teacher mode
- Use AStar pathfinding with door nodes
- Open/close doors automatically (cooldown 0.7s)
- Do not clip through walls

---

## PERFORMANCE PROBLEMS (IDENTIFIED)

### Problem 1: Raycasting Every Frame
**Location**: `_should_detect()` and `_has_line_of_sight()`
**Issue**: Line-of-sight raycast happens every frame when near player
**Impact**: Multiple raycasts per frame = major GPU/CPU hit
**Fix**: Throttle to 0.12 seconds (8 checks per second instead of 60)

### Problem 2: Route Rebuilding Every Frame
**Location**: `_move_toward_target()` 
**Issue**: `_build_route()` called whenever target moves slightly
**Impact**: AStar pathfinding + door graph traversal every frame
**Fix**: Only rebuild route when target distance > 4.0 units OR route invalid, with cooldown

### Problem 3: Door Graph Not Cached
**Location**: `_build_door_graph()` in `_initialize()`
**Issue**: Door graph should be built once at startup, not per-frame
**Fix**: Verify graph is cached and only rebuilt if doors change

### Problem 4: Segment Clear Check Every Frame
**Location**: `_segment_clear()` and `_follow_route()`
**Issue**: Multiple raycasts per frame checking if path is blocked
**Fix**: Throttle segment checks to 0.12 seconds like detection

### Problem 5: No Collision Layer Optimization
**Issue**: All raycasts check all objects, no layer filtering
**Fix**: Use collision masks/layers to reduce raycast targets

---

## OPTIMIZATION STRATEGY

### Change 1: Throttle Detection Checks (0.12s)
```
Instead of checking every frame (_physics_process):
- Add _detection_check_remaining timer
- Only call _should_detect() when timer <= 0
- Reset timer to 0.12 after check
- Cache detection result between checks
```

### Change 2: Throttle Segment Clear Checks (0.12s)
```
Instead of checking every frame during route follow:
- Add _route_collision_check_remaining timer
- Only call _segment_clear() when timer <= 0
- Cache result as _cached_route_segment_clear
- Reuse cached result until timer expires
```

### Change 3: Route Rebuild Cooldown
```
Keep existing logic but verify:
- _route_rebuild_cooldown is respected
- Route only rebuilds if target distance > 4.0 units
- Route only rebuilds if previous route invalid
- Between rebuilds, use cached route and move normally
```

### Change 4: Verify Door Graph Caching
```
Ensure in _initialize():
- _door_graph built ONCE at startup
- NOT rebuilt in _physics_process
- Only updated if doors added/removed (should not happen)
```

### Change 5: Collision Mask Optimization
```
For all raycasts (vision, segment clear):
- Only check collision_mask = 1 (walls/collision objects)
- Exclude players, other NPCs, non-critical objects
- Use _get_self_exclude_rids() and _get_door_exclude_rids()
```

---

## REQUIRED OUTPUT

I need you to:

1. **Review the existing TeacherAI.gd code**
   - Identify all raycasts and their frequency
   - Identify all pathfinding calls and frequency
   - List which checks are throttled and which are not

2. **Fix only performance issues, preserve behavior**
   - Teacher detection same
   - Teacher movement same
   - Teacher door logic same
   - Teacher patrol same
   - ONLY change timing/caching, not logic

3. **Provide optimized TeacherAI.gd**
   - Keep all existing variables
   - Keep all existing functions
   - Only add throttling timers where needed
   - Only add caching where needed
   - Ensure Godot 4.7.2 syntax

4. **Document changes**
   - Comment each optimization with why it helps
   - Show before/after for each change
   - Explain impact on FPS

5. **Provide testing checklist**
   - How to verify performance improved
   - What FPS target to hit
   - What to watch for (does teacher still detect? still patrol? still chase?)

---

## SPECIFIC OPTIMIZATION TARGETS

### Must Have:
- ✅ Raycast throttling (every 0.12s, not every frame)
- ✅ Segment check throttling (every 0.12s, not every frame)
- ✅ Route rebuild cooldown verified
- ✅ Door graph cached at startup only

### Should Have:
- ✅ Collision mask filtering (reduce raycast targets)
- ✅ Clear comments explaining throttling
- ✅ Performance metrics (FPS estimate improvement)

### Nice to Have:
- ✅ Audio pooling (max 3 footsteps concurrent)
- ✅ Visual indicators for optimization (debug mode)

---

## CONSTRAINTS

- Do NOT change map geometry
- Do NOT change teacher behavior (only timing/caching)
- Do NOT remove any existing function (only optimize inside)
- Do NOT change script name (stays TeacherAI.gd)
- Preserve all existing signals and exports
- Keep code readable and commented

---

## FINAL DELIVERABLE

Output the complete optimized TeacherAI.gd script with:

1. All throttling timers added
2. All caching logic added
3. Comments explaining each optimization
4. Original behavior preserved
5. Ready to copy-paste into Godot project

Also provide a brief summary:
- List of optimizations applied
- Expected FPS improvement
- How to test
- Any remaining known issues

---

## EXISTING CODE REFERENCE

The current TeacherAI.gd has these key functions:
- `_physics_process(delta)` — Main update loop
- `_should_detect(player)` — Check if teacher detects player (uses raycast)
- `_has_line_of_sight(target)` — Raycast line-of-sight check
- `_move_toward_target(target, mode)` — Path to target
- `_build_route(target)` — AStar pathfinding (expensive)
- `_follow_route(mode)` — Walk along planned route
- `_segment_clear(from, to, ignore_doors, wide_check)` — Raycast path check
- `_patrol(delta, mode)` — Patrol random waypoints
- `_build_door_graph()` — Build AStar graph of doors (startup only)

**Your job**: Optimize the raycasts in `_should_detect()`, `_has_line_of_sight()`, and `_segment_clear()` to use throttling. Keep everything else the same.

---

## TONE & STYLE

- Professional, performance-focused
- Clear before/after explanations
- Practical testing guidance
- Ready for production use

---

**This is the complete optimization brief for TeacherAI.gd. Proceed with the analysis and optimization.**
