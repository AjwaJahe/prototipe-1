extends CharacterBody3D

## AI guru/hantu Map58.
##
## Pergerakan:
## - Tidak lagi bergerak lurus menembus dinding.
## - Membuat graph berdasarkan semua pintu Map58.
## - Jalur antar-pintu diuji memakai collision sehingga dinding menjadi
##   penghalang nyata.
## - Guru akan menuju pintu keluar ruangan, membuka pintu, lalu melanjutkan.
##
## Mode:
## teacher    = patroli
## ghost      = mengejar murid yang terlihat/terdengar
## berserk    = mengejar target paksa
## responding = menuju murid yang mengerjakan papan


@export var teacher_speed: float = 3.5
@export var ghost_speed: float = 10.0
@export var detection_distance: float = 22.0
@export var hearing_distance: float = 8.0
@export var capture_distance: float = 1.25
@export var waypoint_reach_distance: float = 1.5
@export var waypoint_wait_time: float = 1.5

@export var door_use_distance: float = 2.2
@export var door_close_distance: float = 2.8
@export var door_cooldown: float = 0.7
@export var door_open_wait_time: float = 0.36

@export var teacher_step_interval: float = 0.52
@export var ghost_step_interval: float = 0.34

@export var navigation_width_clearance: float = 0.38
@export var navigation_sample_step: float = 1.25


var _game: Node
var _current_target: Node3D

var _waypoints: Array[Node3D] = []
var _waypoint_index: int = -1
var _wait_remaining: float = 0.0
var _rng := RandomNumberGenerator.new()

var _doors: Array[Node3D] = []
var _door_graph: AStar3D
var _cached_self_exclude_rids: Array[RID] = []
var _cached_door_exclude_rids: Array[RID] = []

var _route_points: Array[Vector3] = []
var _route_doors: Array[Node3D] = []
var _route_index: int = 0
var _route_goal: Node3D
var _route_goal_position := Vector3(INF, INF, INF)
var _route_rebuild_cooldown := 0.0
var _route_built := false

var _last_door: Node3D
var _door_cooldown_remaining := 0.0
var _door_wait_remaining := 0.0

var _footstep_remaining := 0.0
var _last_mode := ""

# Performance cache.
var _detection_check_remaining := 0.0
var _cached_detection_target: Node3D
var _cached_detection_result := false
var _route_collision_check_remaining := 0.0
var _cached_route_segment_clear := true

var _stuck_timer := 0.0
var _stuck_last_pos := Vector3.ZERO
var _unreachable: Array[Node3D] = []

const MAX_NEAREST_DOORS := 6


func _ready() -> void:
	add_to_group("teacher")
	_rng.randomize()
	call_deferred("_initialize")


func _initialize() -> void:
	_game = get_node_or_null("../GameManager")
	_collect_waypoints()
	_collect_doors()
	_cache_collision_rids()
	_build_door_graph()
	_choose_next_waypoint()


func _physics_process(delta: float) -> void:
	if _game == null:
		return

	_door_cooldown_remaining = maxf(
		0.0,
		_door_cooldown_remaining - delta
	)
	_door_wait_remaining = maxf(
		0.0,
		_door_wait_remaining - delta
	)
	_route_rebuild_cooldown = maxf(
		0.0,
		_route_rebuild_cooldown - delta
	)
	_detection_check_remaining = maxf(
		0.0,
		_detection_check_remaining - delta
	)
	_route_collision_check_remaining = maxf(
		0.0,
		_route_collision_check_remaining - delta
	)

	var phase := str(_game.get("phase"))
	if (
		phase == "TRANSITION"
		or phase == "PENALTY_EXAM"
		or phase == "KO"
		or phase == "FINISHED"
	):
		_stop()
		_stop_footstep_timer()
		return

	var mode := String(_game.get("teacher_mode"))
	_handle_mode_change(mode)

	var target := _get_mode_target(mode)

	if _door_wait_remaining > 0.0:
		_stop()
	elif target != null and is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= capture_distance:
			if mode == "berserk" or mode == "ghost":
				_capture_target(target)
			else:
				_stop()
		else:
			_move_toward_target(target, mode)
	else:
		_patrol(delta, mode)

	_try_close_last_door()
	_update_footsteps(delta, mode)
	move_and_slide()


func _handle_mode_change(mode: String) -> void:
	if mode == _last_mode:
		return

	_last_mode = mode

	var audio := get_tree().get_first_node_in_group("game_audio")
	if (
		audio == null
		or not audio.has_method("play_sfx")
		or not audio.has_method("play_loop")
		or not audio.has_method("stop_loop")
	):
		return

	if mode == "ghost":
		audio.play_sfx("teacher_alert")
		audio.play_loop("teacher_ghost_loop", -2.0)
	elif mode == "berserk":
		audio.play_sfx("teacher_ruler")
		audio.play_loop("teacher_ghost_loop", -2.0)
	elif mode == "responding":
		audio.play_sfx("teacher_alert")
		audio.stop_loop("teacher_ghost_loop")
	else:
		audio.stop_loop("teacher_ghost_loop")


func _get_mode_target(mode: String) -> Node3D:
	if mode == "berserk" or mode == "responding":
		var forced: Variant = _game.get_meta("teacher_target", null)
		var forced_target := forced as Node3D
		if forced_target != null and bool(
			forced_target.get_meta("is_hidden", false)
		):
			return null
		return forced_target

	if mode != "ghost":
		_current_target = null
		return null

	if _current_target != null and is_instance_valid(_current_target):
		if _should_detect(_current_target):
			return _current_target
		_current_target = null

	for value in get_tree().get_nodes_in_group("players"):
		if not value is CharacterBody3D:
			continue

		var candidate := value as CharacterBody3D
		if bool(candidate.get_meta("knocked_out", false)):
			continue

		if _should_detect(candidate):
			_current_target = candidate
			return _current_target

	return null


func _should_detect(player: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false

	if bool(player.get_meta("is_hidden", false)):
		return false

	var distance := global_position.distance_to(player.global_position)
	if distance <= hearing_distance:
		return true

	if distance > detection_distance:
		return false

	if (
		_cached_detection_target != player
		or _detection_check_remaining <= 0.0
	):
		_cached_detection_target = player
		_cached_detection_result = _has_line_of_sight(player)
		_detection_check_remaining = 0.12

	return _cached_detection_result


func _has_line_of_sight(target: Node3D) -> bool:
	var origin := global_position + Vector3.UP * 1.0
	var destination := target.global_position + Vector3.UP * 1.0

	var query := PhysicsRayQueryParameters3D.create(
		origin,
		destination
	)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = _get_self_exclude_rids()

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true

	var collider := hit.get("collider") as Node
	if collider == null:
		return false

	var current: Node = collider
	while current != null:
		if current == target:
			return true
		current = current.get_parent()

	return false


func _move_toward_target(target: Node3D, mode: String) -> void:
	_check_stuck(target)

	if target == null:
		_stop()
		return

	var target_position := target.global_position

	if (
		not _route_built
		or _route_goal != target
		or _route_goal_position.distance_to(target_position) > 4.0
		or _route_is_invalid()
	):
		if _route_rebuild_cooldown <= 0.0:
			_build_route(target)
			_route_rebuild_cooldown = 0.45

	if _route_points.is_empty():
		_move_direct_with_collision_check(target_position, mode)
		return

	# Rute selesai tidak berarti target sudah berhenti. Coba gerak langsung,
	# tetapi jangan melakukan raycast setiap physics tick. Jika jalur langsung
	# terhalang, tandai rute perlu dibangun ulang setelah cooldown.
	if _route_index >= _route_points.size():
		if _route_collision_check_remaining <= 0.0:
			_cached_route_segment_clear = _segment_clear(
				global_position,
				target_position,
				true
			)
			_route_collision_check_remaining = 0.12

		if _cached_route_segment_clear:
			_apply_movement(
				(target_position - global_position).normalized(),
				mode
			)
			return

		_route_built = false
		if _route_rebuild_cooldown <= 0.0:
			_build_route(target)
			_route_rebuild_cooldown = 0.45

		if _route_points.is_empty():
			_stop()
		return

		_follow_route(mode)
		return

	_follow_route(mode)


func _move_direct_with_collision_check(
	target_position: Vector3,
	mode: String
) -> void:
	var flat := target_position - global_position
	flat.y = 0.0

	if flat.length() <= 0.05:
		_stop()
		return

	var direction := flat.normalized()
	if not _segment_clear(global_position, target_position):
		var door := _find_nearby_closed_door(door_use_distance + 0.5)
		if door != null:
			_open_door(door)
		else:
			_stop()
		return

	_apply_movement(direction, mode)


func _follow_route(mode: String) -> void:
	while _route_index < _route_points.size():
		var point := _route_points[_route_index]
		var door := _route_doors[_route_index]

		var distance := global_position.distance_to(point)

		if door != null:
			if not door.is_inside_tree() or not is_instance_valid(door):
				_route_index += 1
				continue

			if _door_is_locked(door):
				# Guru tidak boleh membuka pintu yang terkunci.
				# Lewati titik pintu dan minta route baru tanpa pintu ini.
				_route_index += 1
				_route_built = false
				continue

			if not _door_is_open(door):
				if distance <= door_use_distance:
					_open_door(door)
					if _door_is_open(door):
						_stop()
						return
					# Jika gagal membuka (mis. terkunci), jangan berhenti.
					_route_index += 1
					continue

		if distance <= 0.9:
			_route_index += 1
			continue

		var flat := point - global_position
		flat.y = 0.0

		if flat.length() <= 0.05:
			_route_index += 1
			continue

		var direction := flat.normalized()

		if _route_collision_check_remaining <= 0.0:
			_cached_route_segment_clear = _segment_clear(
				global_position,
				point,
				true
			)
			_route_collision_check_remaining = 0.12

		if not _cached_route_segment_clear:
			if door != null and not _door_is_locked(door) and not _door_is_open(door):
				_open_door(door)
				if _door_is_open(door):
					_stop()
					return

			if _route_rebuild_cooldown <= 0.0:
				var goal := _route_goal
				if goal != null and is_instance_valid(goal):
					_build_route(goal)
					_route_rebuild_cooldown = 0.45

			if _route_points.is_empty():
				velocity.x = 0.0
				velocity.z = 0.0
				velocity.y = 0.0
				return

			_stop()
			return

		_apply_movement(direction, mode)
		return

	_stop()


func _apply_movement(direction: Vector3, mode: String) -> void:
	var current_speed := ghost_speed
	if mode == "teacher" or mode == "responding":
		current_speed = teacher_speed

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	velocity.y = 0.0
	_face_direction(direction)


func _build_route(target: Node3D) -> void:
	_clear_route()

	if target == null or not is_instance_valid(target):
		return

	if _doors.is_empty() or _door_graph == null:
		return

	var start := global_position
	var goal := target.global_position

	if _segment_clear(start, goal):
		_route_points.append(goal)
		_route_doors.append(null)
		_route_goal = target
		_route_goal_position = goal
		_route_built = true
		return

	# The expensive door-to-door graph is built once in _initialize().
	# Only start/goal links are recalculated when the target moves.
	const START_ID := 1000000
	const GOAL_ID := 1000001

	_door_graph.add_point(START_ID, start)
	_door_graph.add_point(GOAL_ID, goal)

	var nearest_to_start := _get_nearest_door_indices(
		start,
		-1,
		MAX_NEAREST_DOORS
	)
	var nearest_to_goal := _get_nearest_door_indices(
		goal,
		-1,
		MAX_NEAREST_DOORS
	)

	for i in nearest_to_start:
		var start_door_position := _doors[i].global_position
		if _segment_clear(
			start,
			start_door_position,
			true,
			false
		):
			_door_graph.connect_points(
				START_ID,
				i,
				true
			)

	for i in nearest_to_goal:
		var goal_door_position := _doors[i].global_position
		if _segment_clear(
			goal,
			goal_door_position,
			true,
			false
		):
			_door_graph.connect_points(
				GOAL_ID,
				i,
				true
			)

	var path := _door_graph.get_point_path(
		START_ID,
		GOAL_ID
	)

	# Remove temporary points immediately so the cached graph stays clean.
	_door_graph.remove_point(START_ID)
	_door_graph.remove_point(GOAL_ID)

	if path.is_empty():
		_route_built = true
		_route_goal = target
		_route_goal_position = goal
		return

	for point in path:
		_route_points.append(point)

		var door_for_point: Node3D = null
		for candidate in _doors:
			if candidate.global_position.distance_to(point) < 0.05:
				door_for_point = candidate
				break

		_route_doors.append(door_for_point)

	if not _route_points.is_empty():
		_route_points[-1] = goal
		_route_doors[-1] = null

	_route_goal = target
	_route_goal_position = goal
	_route_built = true
	_route_index = 0


func _move_to_nearest_escape_door() -> void:
	var best_door: Node3D = null
	var best_distance := INF

	for door in _doors:
		if door == null or not is_instance_valid(door):
			continue

		var distance := global_position.distance_to(door.global_position)
		if distance >= best_distance:
			continue

		if _segment_clear(global_position, door.global_position, true):
			best_distance = distance
			best_door = door

	if best_door == null:
		return

	_route_points = [
		best_door.global_position
	]
	_route_doors = [
		best_door
	]
	_route_index = 0


func _route_is_invalid() -> bool:
	# Route yang sudah selesai bukan berarti rusak. Target yang masih sama
	# tidak perlu membangun ulang AStar/raycast setiap physics tick.
	if _route_points.is_empty():
		return true

	if _route_index >= _route_points.size():
		return false

	return false


func _clear_route() -> void:
	_route_points.clear()
	_route_doors.clear()
	_route_index = 0
	_route_built = false
	_route_goal = null
	_route_goal_position = Vector3(INF, INF, INF)
	_route_collision_check_remaining = 0.0
	_cached_route_segment_clear = true


func _collect_doors() -> void:
	_doors.clear()

	var root := get_tree().current_scene
	if root == null:
		root = get_parent()

	if root == null:
		return

	_scan_for_doors(root)


func _scan_for_doors(node: Node) -> void:
	if node != self and node.has_method("is_open") and node.has_method("interact"):
		if node is Node3D:
			var door := node as Node3D
			if not _doors.has(door):
				_doors.append(door)

	for child in node.get_children():
		_scan_for_doors(child)


func _build_door_graph() -> void:
	_door_graph = AStar3D.new()

	if _doors.is_empty():
		return

	for i in range(_doors.size()):
		_door_graph.add_point(i, _doors[i].global_position)

	for i in range(_doors.size()):
		var nearest := _get_nearest_door_indices(
			_doors[i].global_position,
			i,
			MAX_NEAREST_DOORS
		)

		for j in nearest:
			if j <= i:
				continue

			if _segment_clear(
				_doors[i].global_position,
				_doors[j].global_position,
				true,
				false
			):
				_door_graph.connect_points(i, j, true)


func _get_nearest_door_indices(
	origin: Vector3,
	exclude_index: int,
	max_count: int
) -> Array:
	var candidates: Array = []

	for i in range(_doors.size()):
		if i == exclude_index:
			continue

		candidates.append({
			"index": i,
			"distance": origin.distance_squared_to(
				_doors[i].global_position
			)
		})

	candidates.sort_custom(_sort_door_candidates)

	var result: Array = []
	var count := mini(max_count, candidates.size())

	for i in range(count):
		result.append(int(candidates[i]["index"]))

	return result


func _sort_door_candidates(a: Dictionary, b: Dictionary) -> bool:
	return float(a["distance"]) < float(b["distance"])


func _segment_clear(
	from: Vector3,
	to: Vector3,
	ignore_doors: bool = false,
	wide_check: bool = true
) -> bool:
	var flat := to - from
	flat.y = 0.0

	if flat.length() <= 0.05:
		return true

	var direction := flat.normalized()
	var perpendicular := Vector3(
		-direction.z,
		0.0,
		direction.x
	)

	var offsets: Array = [0.0]
	if wide_check:
		offsets = [
			0.0,
			navigation_width_clearance,
			-navigation_width_clearance
		]

	for offset in offsets:
		var ray_from: Vector3 = from + perpendicular * offset
		var ray_to: Vector3 = to + perpendicular * offset

		ray_from.y = global_position.y + 0.9
		ray_to.y = global_position.y + 0.9

		var query := PhysicsRayQueryParameters3D.create(
			ray_from,
			ray_to
		)
		query.collision_mask = 1
		query.collide_with_bodies = true
		query.collide_with_areas = false

		var exclude := _get_self_exclude_rids()

		if ignore_doors:
			exclude.append_array(_get_door_exclude_rids())

		query.exclude = exclude

		var hit := get_world_3d().direct_space_state.intersect_ray(query)

		if not hit.is_empty():
			var collider := hit.get("collider") as Node

			if collider == null:
				return false

			if ignore_doors and _is_part_of_known_door(collider):
				continue

			return false

	return true


func _cache_collision_rids() -> void:
	_cached_self_exclude_rids.clear()
	_cached_self_exclude_rids.append(get_rid())

	_cached_door_exclude_rids.clear()
	for door in _doors:
		if door == null or not is_instance_valid(door):
			continue
		_collect_collision_rids(door, _cached_door_exclude_rids)


func _get_self_exclude_rids() -> Array[RID]:
	return _cached_self_exclude_rids


func _get_door_exclude_rids() -> Array[RID]:
	return _cached_door_exclude_rids


func _collect_collision_rids(node: Node, result: Array[RID]) -> void:
	if node is CollisionObject3D:
		result.append((node as CollisionObject3D).get_rid())

	for child in node.get_children():
		_collect_collision_rids(child, result)


func _is_part_of_known_door(node: Node) -> bool:
	var current: Node = node

	while current != null:
		if current is Node3D:
			var current_3d := current as Node3D
			if _doors.has(current_3d):
				return true
		current = current.get_parent()

	return false


func _patrol(delta: float, mode: String) -> void:
	if mode != "teacher" and mode != "ghost":
		_stop()
		return

	if _waypoints.is_empty():
		_stop()
		return

	if _waypoint_index < 0 or _waypoint_index >= _waypoints.size():
		_choose_next_waypoint()
		return

	var target := _waypoints[_waypoint_index]

	if target == null or not is_instance_valid(target):
		_choose_next_waypoint()
		return

	if global_position.distance_to(target.global_position) <= waypoint_reach_distance:
		_stop()
		_wait_remaining -= delta

		if _wait_remaining <= 0.0:
			_choose_next_waypoint()

		return

	_move_toward_target(target, "teacher")


func _choose_next_waypoint() -> void:
	if _waypoints.is_empty():
		_waypoint_index = -1
		return

	if _waypoints.size() == 1:
		_waypoint_index = 0
	else:
		var available: Array[int] = []
		for i in range(_waypoints.size()):
			if i != _waypoint_index and not _unreachable.has(_waypoints[i]):
				available.append(i)

		if available.is_empty():
			_unreachable.clear()
			for i in range(_waypoints.size()):
				if i != _waypoint_index:
					available.append(i)

		if available.is_empty():
			_waypoint_index = 0
		else:
			_waypoint_index = available[_rng.randi_range(0, available.size() - 1)]

	_wait_remaining = waypoint_wait_time
	_stuck_timer = 0.0
	_clear_route()


func _check_stuck(target: Node3D) -> void:
	_stuck_timer += get_physics_process_delta_time()
	if _stuck_timer < 2.0:
		return

	var moved := global_position.distance_to(_stuck_last_pos)
	_stuck_timer = 0.0
	_stuck_last_pos = global_position

	if moved >= 0.4 or _door_wait_remaining > 0.0:
		return

	if _waypoints.has(target):
		if not _unreachable.has(target):
			_unreachable.append(target)
		if _unreachable.size() >= maxi(1, _waypoints.size() - 1):
			_unreachable.clear()
		_choose_next_waypoint()
	else:
		_clear_route()
		_route_rebuild_cooldown = 1.0


func _collect_waypoints() -> void:
	_waypoints.clear()

	var spawn_manager := get_node_or_null("../SpawnManager")
	if spawn_manager == null:
		return

	var student_spawns := spawn_manager.get_node_or_null(
        "StudentSpawns"
	)

	if student_spawns != null:
		for child in student_spawns.get_children():
			if child is Marker3D:
				_waypoints.append(child as Marker3D)

	var teacher_spawn := spawn_manager.get_node_or_null(
        "TeacherSpawn"
	) as Marker3D

	if teacher_spawn != null:
		_waypoints.append(teacher_spawn)


func _try_close_last_door() -> void:
	if _last_door == null or not is_instance_valid(_last_door):
		return

	if not _door_is_open(_last_door):
		_last_door = null
		return

	for i in range(_route_index, _route_doors.size()):
		if _route_doors[i] == _last_door:
			return

	if global_position.distance_to(_last_door.global_position) >= door_close_distance:
		_last_door.interact(self)
		_last_door = null
		_door_cooldown_remaining = door_cooldown


func _find_nearby_closed_door(distance_limit: float) -> Node3D:
	var best: Node3D = null
	var best_distance := INF

	for door in _doors:
		if door == null or not is_instance_valid(door):
			continue

		if _door_is_open(door):
			continue

		var distance := global_position.distance_to(door.global_position)
		if distance <= distance_limit and distance < best_distance:
			best_distance = distance
			best = door

	return best


func _open_door(door: Node3D) -> void:
	if door == null or not is_instance_valid(door):
		return

	if _door_is_locked(door):
		return

	if _door_cooldown_remaining > 0.0:
		return

	if _door_is_open(door):
		_last_door = door
		return

	if door.has_method("interact"):
		door.interact(self)
		_last_door = door
		_door_cooldown_remaining = door_cooldown
		_door_wait_remaining = door_open_wait_time


func _door_is_locked(door: Node3D) -> bool:
	if door == null or not is_instance_valid(door):
		return true

	if door.has_method("is_locked"):
		return bool(door.is_locked())

	var required_item: Variant = door.get("required_item_type")
	if required_item != null:
		return not String(required_item).is_empty()

	var meta_required: Variant = door.get_meta("required_item_type", "")
	return not String(meta_required).is_empty()


func _door_is_open(door: Node3D) -> bool:
	if door == null or not is_instance_valid(door):
		return false

	if door.has_method("is_open"):
		return bool(door.is_open())

	return false


func _update_footsteps(delta: float, mode: String) -> void:
	var horizontal_speed := Vector2(
		velocity.x,
		velocity.z
	).length()

	if horizontal_speed < 0.15:
		_footstep_remaining = 0.0
		return

	_footstep_remaining -= delta
	if _footstep_remaining > 0.0:
		return

	var audio := get_tree().get_first_node_in_group("game_audio")

	if audio != null and audio.has_method("play_footstep"):
		var volume := -4.0
		var pitch := 0.90

		if (
			mode == "ghost"
			or mode == "berserk"
			or mode == "responding"
		):
			volume = -2.5
			pitch = 0.86

		audio.play_footstep(volume, pitch)

	if (
		mode == "ghost"
		or mode == "berserk"
		or mode == "responding"
	):
		_footstep_remaining = ghost_step_interval
	else:
		_footstep_remaining = teacher_step_interval


func _stop_footstep_timer() -> void:
	_footstep_remaining = 0.0


func _capture_target(target: Node3D) -> void:
	if _game != null and _game.has_method("player_caught"):
		_game.player_caught(target)

	_stop()
	_current_target = null
	_clear_route()


func _face_direction(direction: Vector3) -> void:
	if direction.length_squared() <= 0.0001:
		return

	var look_position := global_position + direction
	look_position.y = global_position.y
	look_at(look_position, Vector3.UP)


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 0.0
