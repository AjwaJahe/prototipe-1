extends CharacterBody3D

## AI guru/hantu Map58 berbasis state machine + NavigationAgent3D.
##
## PATROL -> CHOOSE_ROOM -> MOVE_TO_DOOR -> OPEN_DOOR -> INVESTIGATE
## -> EXIT_ROOM -> PATROL. CHASE mengambil alih saat ada target.
##
## Mode (dari GameManager.teacher_mode):
## teacher    = patroli
## ghost      = mengejar murid yang terlihat/terdengar
## berserk    = mengejar target paksa
## responding = menuju murid yang mengerjakan papan

enum State {
	PATROL,
	CHOOSE_ROOM,
	MOVE_TO_DOOR,
	OPEN_DOOR,
	INVESTIGATE,
	EXIT_ROOM,
	CHASE
}

@export var teacher_speed: float = 3.5
@export var ghost_speed: float = 10.0
@export var detection_distance: float = 22.0
@export var hearing_distance: float = 8.0
@export var capture_distance: float = 1.25

@export var investigation_wait_time: float = 1.5
@export var investigate_room_chance: float = 0.3
@export var investigate_points_count: int = 3
@export var patrol_waypoint_change_timer: float = 15.0
@export var state_timeout: float = 25.0

@export var door_use_distance: float = 2.2
@export var door_cooldown: float = 0.7
@export var door_open_wait_time: float = 0.36

@export var teacher_step_interval: float = 0.52
@export var ghost_step_interval: float = 0.34

@export var nav_max_speed: float = 15.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var _current_state: State = State.PATROL
var _game: Node
var _current_target: Node3D
var _room_target: Node3D
var _door_target: Node3D
var _room_waypoints: Array[Vector3] = []
var _current_waypoint_index: int = 0

var _corridor_waypoints: Array[Node3D] = []
var _current_corridor_waypoint: Node3D
var _arrived_at_waypoint: bool = false

var _state_timer: float = 0.0
var _investigation_timer: float = 0.0
var _door_wait_remaining: float = 0.0
var _door_cooldown_remaining: float = 0.0
var _footstep_remaining: float = 0.0
var _patrol_timer: float = 0.0
var _last_mode: String = ""
var _rng := RandomNumberGenerator.new()

var _detection_check_remaining: float = 0.0
var _cached_detection_target: Node3D
var _cached_detection_result: bool = false

var _last_door_opened: Node3D
var _intro_departing := false
var _intro_departure_door: Node3D
var _intro_departure_door_marker: Node3D
var _intro_departure_destination: Node3D
var _intro_departure_stage := 0
var _intro_departure_wait := 0.0
var _intro_departure_stall := 0.0
var _intro_departure_last_position := Vector3.ZERO
var _intro_departure_outward_direction := Vector3.FORWARD
var _intro_float_height := 1.8


func _ready() -> void:
	add_to_group("teacher")
	_rng.randomize()
	call_deferred("_initialize")


func _initialize() -> void:
	_game = get_node_or_null("../GameManager")

	if nav_agent == null:
		push_error("TeacherAI_New: NavigationAgent3D child node not found!")
		return

	nav_agent.max_speed = nav_max_speed
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 0.5

	_collect_corridor_waypoints()
	_choose_next_corridor_waypoint()


func _physics_process(delta: float) -> void:
	if _game == null or nav_agent == null:
		return

	_door_cooldown_remaining = maxf(0.0, _door_cooldown_remaining - delta)
	_door_wait_remaining = maxf(0.0, _door_wait_remaining - delta)
	_detection_check_remaining = maxf(0.0, _detection_check_remaining - delta)
	_state_timer += delta
	_patrol_timer += delta

	var phase := str(_game.get("phase"))
	if phase == "TRANSITION" and _intro_departing:
		_process_intro_departure(delta)
		return
	if phase in ["INTRO_BRIEFING", "INTRO_EXAM", "TRANSITION", "PENALTY_EXAM", "KO", "FINISHED"]:
		_stop()
		_stop_footstep_timer()
		return

	var mode := String(_game.get("teacher_mode"))
	_handle_mode_change(mode)

	var target := _get_mode_target(mode)
	if target != null and is_instance_valid(target):
		if _current_state != State.CHASE:
			_current_state = State.CHASE
			_state_timer = 0.0
		_current_target = target
	elif _current_state == State.CHASE:
		_current_target = null
		_set_state(State.PATROL)
	elif _current_state != State.PATROL and _state_timer > state_timeout:
		_set_state(State.PATROL)

	match _current_state:
		State.PATROL:
			_on_patrol(delta, mode)
		State.CHOOSE_ROOM:
			_on_choose_room(mode)
		State.MOVE_TO_DOOR:
			_on_move_to_door(mode)
		State.OPEN_DOOR:
			_on_open_door(delta, mode)
		State.INVESTIGATE:
			_on_investigate(delta, mode)
		State.EXIT_ROOM:
			_on_exit_room(mode)
		State.CHASE:
			_on_chase(target, mode)

	_update_footsteps(delta, mode)
	move_and_slide()


func begin_intro_departure(class_door: Node3D, destination: Node3D, door_marker: Node3D = null) -> void:
	# Alur baru: dekati sisi dalam pintu -> buka -> lintasi pintu -> pulang.
	_intro_departing = true
	_intro_departure_door = class_door
	_intro_departure_door_marker = door_marker if door_marker != null else class_door
	_intro_departure_destination = destination
	_intro_departure_stage = 0 if class_door != null and _intro_departure_door_marker != null else 2
	_intro_departure_wait = 0.0
	_intro_departure_stall = 0.0
	_intro_departure_last_position = global_position
	if _intro_departure_door_marker != null and is_instance_valid(_intro_departure_door_marker):
		var outward := _intro_departure_door_marker.global_position - global_position
		outward.y = 0.0
		if outward.length_squared() > 0.001:
			_intro_departure_outward_direction = outward.normalized()
	velocity = Vector3.ZERO
	_set_intro_float_animation(true)

	if _intro_departure_stage == 0:
		nav_agent.target_position = _intro_departure_approach_point()
	elif _intro_departure_destination != null and is_instance_valid(_intro_departure_destination):
		nav_agent.target_position = _intro_departure_destination.global_position


func _intro_departure_approach_point() -> Vector3:
	if _intro_departure_door_marker == null or not is_instance_valid(_intro_departure_door_marker):
		return global_position
	return _intro_departure_door_marker.global_position - _intro_departure_outward_direction * 1.25


func _intro_departure_exit_point() -> Vector3:
	if _intro_departure_door_marker == null or not is_instance_valid(_intro_departure_door_marker):
		return global_position
	return _intro_departure_door_marker.global_position + _intro_departure_outward_direction * 2.0


func _process_intro_departure(delta: float) -> void:
	if not _intro_departing:
		return

	_intro_departure_wait += delta
	if global_position.distance_to(_intro_departure_last_position) < 0.025:
		_intro_departure_stall += delta
	else:
		_intro_departure_stall = 0.0
		_intro_departure_last_position = global_position

	if _intro_departure_stage == 0:
		var approach := _intro_departure_approach_point()
		var near_door := global_position.distance_to(_intro_departure_door_marker.global_position) <= 2.0 if _intro_departure_door_marker != null and is_instance_valid(_intro_departure_door_marker) else false
		if global_position.distance_to(approach) <= 0.95 or near_door:
			velocity = Vector3.ZERO
			if not _door_is_open(_intro_departure_door):
				if _door_cooldown_remaining <= 0.0:
					_open_door(_intro_departure_door)
				if not _door_is_open(_intro_departure_door):
					return
			_intro_departure_stage = 1
			_intro_departure_wait = 0.0
			nav_agent.target_position = _intro_departure_exit_point()
			return
		_move_intro_departure_toward(approach, delta)
		if _intro_departure_stall > 2.0:
			# Titik pendekatan bisa berada di luar navmesh; coba target marker pintu.
			nav_agent.target_position = _intro_departure_door_marker.global_position
			_intro_departure_stall = 0.0
		return

	if _intro_departure_stage == 1:
		var exit_point := _intro_departure_exit_point()
		if global_position.distance_to(exit_point) <= 0.95:
			velocity = Vector3.ZERO
			if _door_is_open(_intro_departure_door):
				_close_door(_intro_departure_door)
			_intro_departure_stage = 2
			_intro_departure_wait = 0.0
			if _intro_departure_destination != null and is_instance_valid(_intro_departure_destination):
				nav_agent.target_position = _intro_departure_destination.global_position
			return
		_move_intro_departure_toward(exit_point, delta)
		if _intro_departure_stall > 2.0:
			# Jika titik seberang tidak terjangkau, teruskan ke tujuan agar AI tidak terkunci di pintu.
			_intro_departure_stage = 2
			if _intro_departure_destination != null and is_instance_valid(_intro_departure_destination):
				nav_agent.target_position = _intro_departure_destination.global_position
			_intro_departure_stall = 0.0
		return

	if _intro_departure_destination == null or not is_instance_valid(_intro_departure_destination):
		_finish_intro_departure()
		return
	if global_position.distance_to(_intro_departure_destination.global_position) <= 1.35:
		velocity = Vector3.ZERO
		_finish_intro_departure()
		return

	_move_intro_departure_toward(_intro_departure_destination.global_position, delta)
	if _intro_departure_stall > 3.0:
		nav_agent.target_position = _intro_departure_destination.global_position
		_intro_departure_stall = 0.0
		if _intro_departure_wait > 25.0:
			push_warning("TeacherAI: guru tertahan saat pulang; keberangkatan tetap aktif agar masalah terlihat dan tidak dilewati diam-diam.")


func _move_intro_departure_toward(target_position: Vector3, delta: float) -> void:
	if nav_agent.target_position.distance_to(target_position) > 0.5:
		nav_agent.target_position = target_position
	var next_position := nav_agent.get_next_path_position()
	var direction := next_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = target_position - global_position
		direction.y = 0.0
	if direction.length_squared() < 0.0001:
		velocity = Vector3.ZERO
		return
	var flat_direction := direction.normalized()
	_face_direction(flat_direction)
	velocity.x = flat_direction.x * teacher_speed
	velocity.z = flat_direction.z * teacher_speed
	velocity.y = 0.0
	move_and_slide()
	# Jangan mengangkat CharacterBody: collision pintu/dinding harus tetap akurat.
	velocity = Vector3.ZERO


func _finish_intro_departure() -> void:
	_intro_departing = false
	velocity = Vector3.ZERO
	_set_intro_float_animation(false)
	_stop()


func _set_intro_float_animation(active: bool) -> void:
	var animation_node := get_node_or_null("TeacherAnimation")
	if animation_node != null and animation_node.has_method("set_intro_floating"):
		animation_node.call("set_intro_floating", active)


func is_intro_departure_complete() -> bool:
	return not _intro_departing


func _set_state(new_state: State) -> void:
	_current_state = new_state
	_state_timer = 0.0
	if new_state == State.PATROL:
		_arrived_at_waypoint = false


func _move_along_path(destination: Vector3, mode: String) -> void:
	nav_agent.target_position = destination

	if nav_agent.is_navigation_finished():
		_stop()
		return

	var next_pos := nav_agent.get_next_path_position()
	var direction := next_pos - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		_stop()
		return

	_apply_movement(direction.normalized(), mode)


func _on_patrol(_delta: float, mode: String) -> void:
	if mode != "teacher" and mode != "ghost":
		_stop()
		return

	if _current_corridor_waypoint == null:
		_choose_next_corridor_waypoint()
		_stop()
		return

	if _patrol_timer >= patrol_waypoint_change_timer:
		_choose_next_corridor_waypoint()
		return

	var waypoint_pos := _current_corridor_waypoint.global_position

	if global_position.distance_to(waypoint_pos) <= 1.5:
		_stop()

		if not _arrived_at_waypoint:
			_arrived_at_waypoint = true
			_state_timer = 0.0
			if _rng.randf() < investigate_room_chance:
				_set_state(State.CHOOSE_ROOM)
				return

		if _state_timer > 2.0:
			_choose_next_corridor_waypoint()
		return

	_move_along_path(waypoint_pos, mode)


func _on_choose_room(_mode: String) -> void:
	var rooms := _get_all_classrooms()
	if rooms.is_empty():
		_set_state(State.PATROL)
		return

	_room_target = rooms[_rng.randi_range(0, rooms.size() - 1)]

	var door_marker := _room_target.get_node_or_null("Door") as Node3D
	if door_marker == null:
		_set_state(State.PATROL)
		return

	var door := _resolve_door(door_marker)
	if door == null or _door_is_locked(door):
		_set_state(State.PATROL)
		return

	_door_target = door
	_set_state(State.MOVE_TO_DOOR)


func _on_move_to_door(mode: String) -> void:
	if _door_target == null or not is_instance_valid(_door_target):
		_set_state(State.PATROL)
		return

	var door_pos := _door_target.global_position

	if global_position.distance_to(door_pos) <= door_use_distance:
		_stop()
		_set_state(State.OPEN_DOOR)
		return

	_move_along_path(door_pos, mode)


func _on_open_door(_delta: float, _mode: String) -> void:
	if _door_target == null or not is_instance_valid(_door_target):
		_set_state(State.PATROL)
		return

	_stop()

	if not _door_is_open(_door_target):
		if _door_cooldown_remaining <= 0.0 and _door_wait_remaining <= 0.0:
			_open_door(_door_target)
			_door_wait_remaining = door_open_wait_time

	if _door_wait_remaining > 0.0:
		return

	if not _door_is_open(_door_target):
		if _state_timer > 3.0:
			_set_state(State.PATROL)
		return

	_collect_room_waypoints(_room_target)
	if not _room_waypoints.is_empty():
		_current_waypoint_index = 0
		_investigation_timer = 0.0
		_set_state(State.INVESTIGATE)
	else:
		_set_state(State.EXIT_ROOM)


func _on_investigate(delta: float, mode: String) -> void:
	if _room_waypoints.is_empty() or _current_waypoint_index >= _room_waypoints.size():
		_set_state(State.EXIT_ROOM)
		return

	var current_point := _room_waypoints[_current_waypoint_index]

	if global_position.distance_to(current_point) <= 1.0:
		_stop()
		_investigation_timer += delta

		if _investigation_timer >= investigation_wait_time:
			_current_waypoint_index += 1
			_investigation_timer = 0.0

			if _current_waypoint_index >= _room_waypoints.size():
				_set_state(State.EXIT_ROOM)
		return

	_move_along_path(current_point, mode)


func _on_exit_room(mode: String) -> void:
	if _door_target == null or not is_instance_valid(_door_target):
		_set_state(State.PATROL)
		return

	var door_pos := _door_target.global_position

	if global_position.distance_to(door_pos) <= door_use_distance:
		_stop()
		if _door_is_open(_door_target) and _door_cooldown_remaining <= 0.0:
			_close_door(_door_target)

		_door_target = null
		_set_state(State.PATROL)
		_choose_next_corridor_waypoint()
		return

	_move_along_path(door_pos, mode)


func _on_chase(target: Node3D, mode: String) -> void:
	if target == null or not is_instance_valid(target):
		_set_state(State.PATROL)
		_current_target = null
		return

	var target_pos := target.global_position

	if global_position.distance_to(target_pos) <= capture_distance:
		if mode in ["berserk", "ghost"]:
			_capture_target(target)
		_stop()
		return

	_move_along_path(target_pos, mode)


func _apply_movement(direction: Vector3, mode: String) -> void:
	var speed := ghost_speed if mode in ["ghost", "berserk"] else teacher_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = 0.0
	_face_direction(direction)


func _handle_mode_change(mode: String) -> void:
	if mode == _last_mode:
		return

	_last_mode = mode

	var audio := get_tree().get_first_node_in_group("game_audio")
	if audio == null:
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
	if mode in ["berserk", "responding"]:
		var forced: Variant = _game.get_meta("teacher_target", null)
		var forced_target := forced as Node3D
		if forced_target != null and bool(forced_target.get_meta("is_hidden", false)):
			return null
		return forced_target

	if mode != "ghost":
		_current_target = null
		return null

	if _current_target != null and is_instance_valid(_current_target):
		if _should_detect(_current_target):
			return _current_target
		_current_target = null

	for player in get_tree().get_nodes_in_group("players"):
		if not player is CharacterBody3D:
			continue

		var candidate := player as CharacterBody3D
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

	if _cached_detection_target != player or _detection_check_remaining <= 0.0:
		_cached_detection_target = player
		_cached_detection_result = _has_line_of_sight(player)
		_detection_check_remaining = 0.12

	return _cached_detection_result


func _has_line_of_sight(target: Node3D) -> bool:
	var origin := global_position + Vector3.UP * 1.0
	var destination := target.global_position + Vector3.UP * 1.0

	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]

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


func _collect_corridor_waypoints() -> void:
	_corridor_waypoints.clear()

	var corridor_node := get_tree().current_scene.get_node_or_null("Map58/Rooms/Corridor")
	if corridor_node == null:
		push_warning("TeacherAI_New: Corridor node not found")
		return

	for child in corridor_node.get_children():
		if child is Marker3D:
			_corridor_waypoints.append(child)


func _choose_next_corridor_waypoint() -> void:
	_patrol_timer = 0.0
	_state_timer = 0.0
	_arrived_at_waypoint = false

	if _corridor_waypoints.is_empty():
		return

	if _corridor_waypoints.size() == 1:
		_current_corridor_waypoint = _corridor_waypoints[0]
		return

	var next_waypoint := _current_corridor_waypoint
	while next_waypoint == _current_corridor_waypoint:
		next_waypoint = _corridor_waypoints[_rng.randi_range(0, _corridor_waypoints.size() - 1)]
	_current_corridor_waypoint = next_waypoint


func _get_all_classrooms() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var rooms_node := get_tree().current_scene.get_node_or_null("Map58/Rooms")

	if rooms_node == null:
		return result

	for child in rooms_node.get_children():
		if child is Node3D and String(child.name).begins_with("Classroom_"):
			result.append(child as Node3D)

	return result


func _collect_room_waypoints(room: Node3D) -> void:
	_room_waypoints.clear()

	if room == null:
		return

	var room_points_node := room.get_node_or_null("RoomPoints")
	if room_points_node == null:
		return

	var points: Array[Vector3] = []
	for child in room_points_node.get_children():
		if child is Marker3D:
			points.append((child as Marker3D).global_position)

	for i in range(points.size()):
		var j := _rng.randi_range(i, points.size() - 1)
		var temp := points[i]
		points[i] = points[j]
		points[j] = temp

	for i in range(mini(investigate_points_count, points.size())):
		_room_waypoints.append(points[i])


## Marker "Door" pada Rooms hanya menandai posisi; pintu asli (grup "doors")
## yang paling dekat dengan marker dipakai untuk interaksi.
func _resolve_door(marker: Node3D) -> Node3D:
	if marker.has_method("interact"):
		return marker

	var best: Node3D = null
	var best_distance := 3.0
	for door in get_tree().get_nodes_in_group("doors"):
		var door_3d := door as Node3D
		if door_3d == null or not door_3d.has_method("interact"):
			continue

		var distance := marker.global_position.distance_to(door_3d.global_position)
		if distance < best_distance:
			best_distance = distance
			best = door_3d

	return best


func _open_door(door: Node3D) -> void:
	if door == null or not is_instance_valid(door):
		return

	if _door_cooldown_remaining > 0.0:
		return

	if door.has_method("interact"):
		door.interact(self)
		_last_door_opened = door
		_door_cooldown_remaining = door_cooldown


func _close_door(door: Node3D) -> void:
	if door == null or not is_instance_valid(door):
		return

	if _door_is_open(door) and door.has_method("interact"):
		door.interact(self)
		_door_cooldown_remaining = door_cooldown


func _door_is_open(door: Node3D) -> bool:
	if door == null or not is_instance_valid(door):
		return false

	if door.has_method("is_open"):
		return bool(door.is_open())

	return false


func _door_is_locked(door: Node3D) -> bool:
	if door == null or not is_instance_valid(door):
		return true

	if door.has_method("is_locked"):
		return bool(door.is_locked())

	return false


func _capture_target(target: Node3D) -> void:
	if _game != null and _game.has_method("player_caught"):
		_game.player_caught(target)

	_stop()
	_current_target = null


func _update_footsteps(delta: float, mode: String) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()

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

		if mode in ["ghost", "berserk", "responding"]:
			volume = -2.5
			pitch = 0.86

		audio.play_footstep(volume, pitch)

	if mode in ["ghost", "berserk", "responding"]:
		_footstep_remaining = ghost_step_interval
	else:
		_footstep_remaining = teacher_step_interval


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


func _stop_footstep_timer() -> void:
	_footstep_remaining = 0.0
