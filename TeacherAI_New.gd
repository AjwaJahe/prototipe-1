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
	CHASE,
	SEARCH
}

@export var teacher_speed: float = 3.5
@export var ghost_speed: float = 13.0
@export var detection_distance: float = 22.0
@export var hearing_distance: float = 8.0
@export var capture_distance: float = 1.25

@export var investigation_wait_time: float = 1.5
@export var investigate_room_chance: float = 0.3
@export var investigate_points_count: int = 3
@export var patrol_waypoint_change_timer: float = 15.0
@export var state_timeout: float = 25.0
@export var search_duration: float = 4.0
@export var room_revisit_cooldown: float = 25.0

@export var door_use_distance: float = 2.2
@export var door_cooldown: float = 0.7
@export var door_open_wait_time: float = 0.36

@export var teacher_step_interval: float = 0.52
@export var ghost_step_interval: float = 0.34

@export var nav_max_speed: float = 15.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
var _cached_next_path_position: Vector3 = Vector3.ZERO

var _current_state: State = State.PATROL
var _game: Node
var _current_target: Node3D
var _last_known_target_position: Vector3 = Vector3.ZERO
var _search_remaining: float = 0.0
var _last_room_target: Node3D
var _room_revisit_remaining: float = 0.0
var _startup_room_exit_complete: bool = false
var _room_target: Node3D
var _door_target: Node3D
var _room_waypoints: Array[Vector3] = []
var _current_waypoint_index: int = 0

var _corridor_waypoints: Array[Node3D] = []
var _corridor_waypoint_queue: Array[Node3D] = []
var _current_corridor_waypoint: Node3D
var _arrived_at_waypoint: bool = false

var _state_timer: float = 0.0
var _investigation_timer: float = 0.0
var _door_wait_remaining: float = 0.0
var _door_cooldown_remaining: float = 0.0
var _footstep_remaining: float = 0.0
var _patrol_timer: float = 0.0

# Pemulihan dari furnitur/halangan: lompat setelah 5 detik tanpa progres.
@export var stuck_jump_delay: float = 5.0
@export var stuck_jump_velocity: float = 14.72
@export var stuck_sample_interval: float = 0.5
@export var stuck_min_progress: float = 0.2
var _stuck_timer: float = 0.0
var _stuck_sample_timer: float = 0.0
var _stuck_sample_path_target: Vector2 = Vector2.ZERO
var _stuck_sample_path_distance: float = INF
var _stuck_sample_destination_distance: float = INF
var _stuck_sample_initialized: bool = false
var _stuck_recovery_attempts: int = 0
var _jump_recovery_active: bool = false
var _last_mode: String = ""
var _responding_look_timer: float = 0.0
var _responding_look_at_board: bool = true
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
var _escape_gate_target: Node3D
var _escape_gate_opening := false
var _escape_gate_opened := false


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

	# Map58Game menguasai perpindahan fisik guru selama adegan penyeretan.
	# Jangan hentikan velocity di fase TRANSITION; animasi locomotion membacanya.
	if bool(get_meta("capture_dragging", false)):
		return

	_door_cooldown_remaining = maxf(0.0, _door_cooldown_remaining - delta)
	_door_wait_remaining = maxf(0.0, _door_wait_remaining - delta)
	_update_auto_close_door()
	_room_revisit_remaining = maxf(0.0, _room_revisit_remaining - delta)
	_detection_check_remaining = maxf(0.0, _detection_check_remaining - delta)
	_state_timer += delta
	_patrol_timer += delta

	var phase := str(_game.get("phase"))
	if phase == "TRANSITION" and _intro_departing:
		_process_intro_departure(delta)
		return
	if phase in ["INTRO_BRIEFING", "INTRO_EXAM", "TRANSITION", "FINISHED"]:
		_stop()
		_stop_footstep_timer()
		return

	if phase == "HUNT" and not _startup_room_exit_complete:
		_ensure_startup_room_door_open()

	var mode := str(_game.get("teacher_mode"))
	if mode.is_empty() or mode == "<null>":
		mode = "teacher"
	_handle_mode_change(mode)

	# Saat soal papan dikerjakan, guru tidak memakai target CHASE/NavigationAgent.
	# Ia tetap di tempat dan hanya bergantian memperhatikan papan serta murid.
	if phase == "BOARD_SOLVING" and mode == "responding":
		_process_board_responding(delta)
		return

	# Setelah 10 jawaban benar, jalankan rute keluar khusus memakai NavigationAgent
	# dan gerak CharacterBody normal. Animasi locomotion/collision tetap aktif.
	if phase == "ESCAPE_READY" and _escape_gate_target != null and is_instance_valid(_escape_gate_target):
		_process_escape_gate(delta)
		return

	var target := _get_mode_target(mode)
	if target != null and is_instance_valid(target):
		if _current_state != State.CHASE:
			_current_state = State.CHASE
			_state_timer = 0.0
		_current_target = target
		_last_known_target_position = target.global_position
	elif _current_state == State.CHASE:
		_current_target = null
		if mode == "ghost":
			_search_remaining = search_duration
			_set_state(State.SEARCH)
		else:
			_set_state(State.PATROL)
	elif _current_state not in [State.PATROL, State.SEARCH, State.INVESTIGATE] and _state_timer > state_timeout:
		_set_state(State.PATROL)

	# NavigationAgent3D harus diminta memperbarui titik jalur sekali per physics
	# frame. Semua subsistem di frame ini memakai cache yang sama agar tidak
	# memajukan indeks path beberapa kali sebelum CharacterBody benar-benar bergerak.
	var uses_navigation := _current_state in [
		State.PATROL, State.MOVE_TO_DOOR, State.EXIT_ROOM,
		State.INVESTIGATE, State.CHASE, State.SEARCH
	]
	if uses_navigation:
		var active_destination := _get_active_navigation_destination()
		if nav_agent.target_position.distance_to(active_destination) > 0.5:
			nav_agent.target_position = active_destination
		_cached_next_path_position = nav_agent.get_next_path_position()
	else:
		_cached_next_path_position = nav_agent.target_position

	if uses_navigation and _try_open_door_in_path():
		# Tahan guru selama daun pintu masih bergerak; status is_open() saja
		# belum menjamin celah pintu cukup lebar untuk dilewati.
		_stop()
		_update_footsteps(delta, mode)
		if is_on_floor():
			velocity.y = -0.5
		else:
			velocity.y -= 24.0 * delta
		move_and_slide()
		return

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
		State.SEARCH:
			_on_search(delta, mode)

	_update_footsteps(delta, mode)
	_update_stuck_recovery(delta)
	# Guru harus tetap mengikuti gravitasi. Saat pemulihan lompat aktif, jangan
	# mengunci velocity.y ke lantai pada frame pertama lompatan.
	if _jump_recovery_active:
		velocity.y -= 24.0 * delta
		if is_on_floor() and velocity.y <= 0.0:
			_jump_recovery_active = false
			velocity.y = -0.5
	elif is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 24.0 * delta
	move_and_slide()


func begin_escape_to_gate(gate: Node3D) -> void:
	if gate == null or not is_instance_valid(gate):
		push_warning("TeacherAI: gerbang utama tidak ditemukan; rute membuka gerbang dibatalkan.")
		return
	_escape_gate_target = gate
	_escape_gate_opening = false
	_escape_gate_opened = false
	_current_target = null
	_door_target = gate
	_room_target = null
	_set_state(State.MOVE_TO_DOOR)
	nav_agent.target_position = gate.global_position
	velocity = Vector3.ZERO


func _process_escape_gate(delta: float) -> void:
	if _escape_gate_opened:
		_stop()
		_update_footsteps(delta, "teacher")
		if is_on_floor():
			velocity.y = -0.5
		else:
			velocity.y -= 24.0 * delta
		move_and_slide()
		return

	if _escape_gate_target == null or not is_instance_valid(_escape_gate_target):
		_stop()
		return

	var distance_to_gate := global_position.distance_to(_escape_gate_target.global_position)
	if distance_to_gate <= maxf(door_use_distance, 2.8):
		_stop()
		if _door_is_open(_escape_gate_target):
			if _escape_gate_target.has_method("is_transitioning") and bool(_escape_gate_target.call("is_transitioning")):
				pass
			else:
				_escape_gate_opened = true
				_escape_gate_opening = false
		else:
			_escape_gate_opening = true
			if _door_cooldown_remaining <= 0.0:
				_open_door(_escape_gate_target, false)
		_update_footsteps(delta, "teacher")
		if is_on_floor():
			velocity.y = -0.5
		else:
			velocity.y -= 24.0 * delta
		move_and_slide()
		return

	if nav_agent.target_position.distance_to(_escape_gate_target.global_position) > 0.5:
		nav_agent.target_position = _escape_gate_target.global_position
	_cached_next_path_position = nav_agent.get_next_path_position()
	_move_along_path(_escape_gate_target.global_position, "teacher")
	_update_stuck_recovery(delta)
	_update_footsteps(delta, "teacher")
	if _jump_recovery_active:
		velocity.y -= 24.0 * delta
	elif is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 24.0 * delta
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
	# Jangan bergerak lurus ke tujuan jika NavigationAgent belum memberi titik
	# rute. Tunggu perhitungan rute berikutnya agar guru tidak menembus furnitur
	# saat jalur belum siap atau tujuan berada di luar navmesh.
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
	if new_state != _current_state:
		_stuck_timer = 0.0
		_stuck_sample_timer = 0.0
		_stuck_sample_initialized = false
	_current_state = new_state
	_state_timer = 0.0
	if new_state == State.PATROL:
		_arrived_at_waypoint = false


## Dipanggil hanya oleh host saat menerima voice chat yang cukup keras dan dekat.
## Guru menuju posisi suara terakhir; jika melihat target sungguhan, pengejaran itu tetap prioritas.
func hear_multiplayer_voice(sound_position: Vector3, _peer_id: int, loudness: float = 1.0) -> void:
	if _game == null or str(_game.get("phase")) != "HUNT":
		return
	if str(_game.get("teacher_mode")) != "ghost":
		return
	if global_position.distance_to(sound_position) > hearing_distance:
		return
	if _current_state == State.CHASE and _current_target != null and is_instance_valid(_current_target) and _should_detect(_current_target):
		return
	_last_known_target_position = sound_position
	_search_remaining = maxf(search_duration, 2.0 + clampf(loudness, 0.0, 1.0) * 2.0)
	_current_target = null
	_set_state(State.SEARCH)


func _move_along_path(destination: Vector3, mode: String) -> void:
	# Ubah target hanya ketika tujuan benar-benar berubah; memberi NavigationAgent
	# satu physics tick untuk menghitung rute mencegah status selesai palsu.
	if nav_agent.target_position.distance_to(destination) > 0.5:
		nav_agent.target_position = destination
		_stop()
		return

	if nav_agent.is_navigation_finished():
		_stop()
		if global_position.distance_to(destination) <= 1.35:
			return
		# NavigationAgent dapat menganggap rute selesai di titik akhir parsial.
		# Jangan langsung mengganti waypoint: watchdog akan mencoba arah aman,
		# lompatan pemulihan, lalu fallback state-specific bila tujuan benar-benar gagal.
		return

	var next_pos := _cached_next_path_position
	var direction := next_pos - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		_stop()
		return

	_apply_movement(direction.normalized(), mode)


func _try_open_door_in_path() -> bool:
	# Jangan membuka pintu hanya karena pintu dekat dan berada di depan.
	# Buka hanya jika ray fisika pada jalur gerak benar-benar mengenai collider
	# milik pintu tertutup. Ini mencegah guru membuka pintu kelas saat melintas
	# di koridor yang tidak terhalang.
	var route_direction := _cached_next_path_position - global_position
	route_direction.y = 0.0
	if route_direction.length_squared() < 0.01:
		route_direction = Vector3(velocity.x, 0.0, velocity.z)
	if route_direction.length_squared() < 0.01:
		return false
	route_direction = route_direction.normalized()

	var ray_origin := global_position + Vector3.UP * 1.35
	var ray_end := ray_origin + route_direction * 2.8
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# Raycast bisa meleset dari daun pintu karena tinggi collider atau offset
	# jalur. Tetap lakukan pemeriksaan geometris terhadap pintu di koridor.
	var hit_node: Node = hit.get("collider") as Node if not hit.is_empty() else null
	var hit_position: Vector3 = hit.get("position", ray_end) if not hit.is_empty() else ray_end

	var door_to_open: Node3D = null
	for candidate in get_tree().get_nodes_in_group("doors"):
		var candidate_door := candidate as Node3D
		if candidate_door == null or not is_instance_valid(candidate_door) or not candidate_door.has_method("interact"):
			continue
		if not _is_node_within_door(hit_node, candidate_door):
			continue
		# Collider pintu benar-benar terkena ray pada jalur gerak; jangan
		# menolak pintu hanya karena sumbu basis modelnya berbeda orientasi.
		door_to_open = candidate_door
		break

	# Sebagian doorway memiliki collision dinding/ambang sedikit di depan daun
	# pintu. Jika raycast pertama mengenai collider itu, tetap kenali pintu hanya
	# bila pusat pintu berada tepat di depan jalur dan dekat titik tabrakan.
	if door_to_open == null:
		var best_hit_distance := INF
		for candidate in get_tree().get_nodes_in_group("doors"):
			var candidate_door := candidate as Node3D
			if candidate_door == null or not is_instance_valid(candidate_door) or not candidate_door.has_method("interact"):
				continue
			if _door_is_locked(candidate_door):
				continue
			var to_door := candidate_door.global_position - ray_origin
			to_door.y = 0.0
			var forward_distance := to_door.dot(route_direction)
			if forward_distance <= 0.0 or forward_distance > 2.8:
				continue
			var lateral_offset := to_door - route_direction * forward_distance
			lateral_offset.y = 0.0
			if lateral_offset.length() > 1.35:
				continue
			var hit_offset := candidate_door.global_position - hit_position
			hit_offset.y = 0.0
			var hit_distance := hit_offset.length()
			# Jika ray mengenai dinding/ambang, pintu harus dekat titik benturan.
			# Jika ray meleset, proyeksi ke jalur dan offset samping sudah menjadi filter.
			if (hit.is_empty() or hit_distance <= 1.6) and hit_distance < best_hit_distance:
				best_hit_distance = hit_distance
				door_to_open = candidate_door

	if door_to_open == null:
		return false
	if _door_is_locked(door_to_open):
		return false

	if _door_is_open(door_to_open):
		# Pintu sudah menerima perintah buka, tetapi animasinya belum selesai.
		# Hormati status transisi pada semua jenis pintu yang menyediakan API itu.
		if door_to_open.has_method("is_transitioning") and bool(door_to_open.call("is_transitioning")):
			return true
		if door_to_open.has_method("is_fully_open") and not bool(door_to_open.call("is_fully_open")):
			return true
		return false

	if _door_cooldown_remaining > 0.0:
		return false
	# Pintu transit dibiarkan terbuka. Auto-close berbasis jarak/arah dapat
	# menutup pintu saat guru masih di ambang dan memicu siklus buka-tutup.
	# Pintu ruang yang benar-benar diinvestigasi tetap ditutup di _on_exit_room().
	_open_door(door_to_open, false)
	if _door_is_open(door_to_open):
		print("TeacherAI: membuka pintu yang menghalangi rute: ", door_to_open.get_path())
		return true
	return false


func _is_node_within_door(node: Node, door: Node) -> bool:
	# Collider pintu biasanya berada pada DoorPivot/CollisionShape3D di bawah
	# root pintu. Telusuri parent agar semua jenis pintu dikenali konsisten.
	var current: Node = node
	while current != null:
		if current == door:
			return true
		current = current.get_parent()
	return false


func _on_patrol(_delta: float, mode: String) -> void:
	if mode != "teacher" and mode != "ghost":
		_stop()
		return

	if _current_corridor_waypoint == null:
		_choose_next_corridor_waypoint()
		_stop()
		return

	# Jangan membatalkan rute hanya karena waktu berlalu; selesaikan waypoint dulu.
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
	# Pilih pintu terdekat di depan arah hadap guru, bukan kelas secara acak.
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		_set_state(State.PATROL)
		_choose_next_corridor_waypoint()
		return
	forward = forward.normalized()

	var best_door: Node3D = null
	var best_distance := 18.0
	for candidate in get_tree().get_nodes_in_group("doors"):
		var door := candidate as Node3D
		if door == null or not door.has_method("interact"):
			continue
		if _door_is_locked(door):
			continue
		var matches_classroom := false
		for room in _get_all_classrooms():
			var classroom_marker := room.get_node_or_null("Door") as Node3D
			if classroom_marker != null and classroom_marker.global_position.distance_to(door.global_position) <= 4.5:
				matches_classroom = true
				break
		if not matches_classroom:
			continue
		var offset := door.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < 0.1 or distance > best_distance:
			continue
		# Dot positif berarti pintu berada di belahan depan guru.
		if forward.dot(offset.normalized()) <= 0.25:
			continue
		best_distance = distance
		best_door = door

	if best_door == null:
		# Tidak ada pintu di depan: lanjutkan patroli agar tidak macet.
		_set_state(State.PATROL)
		_choose_next_corridor_waypoint()
		return

	# Cocokkan pintu terpilih dengan penanda kelas terdekat.
	var best_room: Node3D = null
	var marker_distance := 10.0
	for room in _get_all_classrooms():
		var marker := room.get_node_or_null("Door") as Node3D
		if marker == null:
			continue
		var distance_to_marker := marker.global_position.distance_to(best_door.global_position)
		if distance_to_marker < marker_distance:
			marker_distance = distance_to_marker
			best_room = room

	if best_room == null:
		push_warning("TeacherAI_New: pintu di depan tidak cocok dengan penanda ruang kelas.")
		_set_state(State.PATROL)
		_choose_next_corridor_waypoint()
		return

	# Jangan bolak-balik masuk kelas yang baru saja diperiksa.
	if best_room == _last_room_target and _room_revisit_remaining > 0.0:
		_set_state(State.PATROL)
		_choose_next_corridor_waypoint()
		return

	_room_target = best_room
	_door_target = best_door
	_set_state(State.MOVE_TO_DOOR)


func _on_move_to_door(mode: String) -> void:
	if _door_target == null or not is_instance_valid(_door_target):
		_set_state(State.PATROL)
		return

	var door_pos := _door_target.global_position

	if global_position.distance_to(door_pos) <= maxf(door_use_distance, 2.8):
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
		_last_room_target = _room_target
		_room_revisit_remaining = room_revisit_cooldown
		_door_target = null
		_room_target = null
		_set_state(State.PATROL)
		_choose_next_corridor_waypoint()
		return

	_move_along_path(door_pos, mode)


func _on_search(delta: float, mode: String) -> void:
	if mode != "ghost":
		_set_state(State.PATROL)
		return
	if global_position.distance_to(_last_known_target_position) > 1.1:
		_move_along_path(_last_known_target_position, mode)
		return
	_stop()
	_search_remaining -= delta
	if _search_remaining <= 0.0:
		_set_state(State.PATROL)
		_choose_next_corridor_waypoint()


func _on_chase(target: Node3D, mode: String) -> void:
	if target == null or not is_instance_valid(target):
		_set_state(State.PATROL)
		_current_target = null
		return

	var target_pos := target.global_position
	# Root CharacterBody murid berada pada offset vertikal dari node Player.
	# Jarak penangkapan harus dihitung horizontal supaya selisih tinggi node
	# tidak membuat guru selalu gagal mencapai capture_distance.
	var flat_to_target := Vector2(target_pos.x - global_position.x, target_pos.z - global_position.z)

	if flat_to_target.length() <= capture_distance:
		# Semua mode yang mengejar harus menyelesaikan penangkapan lewat satu alur,
		# agar mode teacher juga memicu jumpscare dan penalti, bukan hanya berhenti.
		_capture_target(target)
		_stop()
		return

	_move_along_path(target_pos, mode)


func _apply_movement(direction: Vector3, mode: String) -> void:
	var speed := ghost_speed if mode in ["ghost", "berserk"] else teacher_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not _jump_recovery_active:
		velocity.y = 0.0
	_face_direction(direction)


func _get_active_navigation_destination() -> Vector3:
	# Ambil tujuan dari state AI yang sedang aktif, bukan target NavigationAgent
	# yang mungkin tertinggal setelah waypoint/state berubah.
	match _current_state:
		State.PATROL:
			if _current_corridor_waypoint != null and is_instance_valid(_current_corridor_waypoint):
				return _current_corridor_waypoint.global_position
		State.CHASE:
			if _current_target != null and is_instance_valid(_current_target):
				return _current_target.global_position
		State.SEARCH:
			return _last_known_target_position
		State.MOVE_TO_DOOR, State.EXIT_ROOM:
			if _door_target != null and is_instance_valid(_door_target):
				return _door_target.global_position
		State.INVESTIGATE:
			if _current_waypoint_index >= 0 and _current_waypoint_index < _room_waypoints.size():
				return _room_waypoints[_current_waypoint_index]
	return nav_agent.target_position


func _update_stuck_recovery(delta: float) -> void:
	var current_position := global_position
	var current_flat := Vector2(current_position.x, current_position.z)
	var is_trying_to_move := Vector2(velocity.x, velocity.z).length() > 0.5
	var active_destination := _get_active_navigation_destination()
	var target_below := active_destination.y < global_position.y - 0.8
	# Watchdog harus tetap mendeteksi macet walaupun _stop() telah mengosongkan
	# velocity. Jarak tujuan dan progres dihitung horizontal agar beda tinggi node
	# atau lompatan tidak membuat diagnosis macet keliru.
	var destination_distance := global_position.distance_to(active_destination)
	var destination_flat := Vector2(active_destination.x, active_destination.z)
	var destination_distance_flat := current_flat.distance_to(destination_flat)
	var should_be_moving := false
	match _current_state:
		State.PATROL:
			should_be_moving = destination_distance > 1.5
		State.CHASE:
			should_be_moving = destination_distance > capture_distance + 0.5
		State.MOVE_TO_DOOR:
			should_be_moving = destination_distance > maxf(door_use_distance, 2.8)
		State.EXIT_ROOM:
			should_be_moving = destination_distance > door_use_distance
		State.INVESTIGATE, State.SEARCH:
			should_be_moving = destination_distance > 1.1

	# Jangan menganggap perpindahan sembarang arah sebagai kemajuan. Guru yang
	# terdorong menjauh atau bergerak bolak-balik bisa berpindah banyak unit tetapi
	# tidak maju di rute. Ukur progres ke titik jalur NavigationAgent dan ke tujuan.
	var current_path_target := destination_flat
	if not nav_agent.is_navigation_finished():
		current_path_target = Vector2(_cached_next_path_position.x, _cached_next_path_position.z)
	var current_path_distance := current_flat.distance_to(current_path_target)

	if not _stuck_sample_initialized:
		_stuck_sample_path_target = current_path_target
		_stuck_sample_path_distance = current_path_distance
		_stuck_sample_destination_distance = destination_distance_flat
		_stuck_sample_timer = 0.0
		_stuck_sample_initialized = true
	elif should_be_moving or is_trying_to_move or target_below:
		_stuck_sample_timer += delta
		if _stuck_sample_timer >= maxf(stuck_sample_interval, 0.1):
			var path_progress := _stuck_sample_path_distance - current_path_distance
			# Saat agen maju melewati satu titik jalur, titik berikutnya berubah.
			# Itu dihitung sebagai kemajuan hanya bila guru sudah dekat titik lama.
			if current_path_target.distance_to(_stuck_sample_path_target) > 1.0:
				path_progress = 1.0 if current_flat.distance_to(_stuck_sample_path_target) <= 1.5 else -INF
			var destination_progress := _stuck_sample_destination_distance - destination_distance_flat
			if path_progress < stuck_min_progress and destination_progress < stuck_min_progress:
				_stuck_timer += _stuck_sample_timer
			else:
				_stuck_timer = 0.0
			_stuck_sample_path_target = current_path_target
			_stuck_sample_path_distance = current_path_distance
			_stuck_sample_destination_distance = destination_distance_flat
			_stuck_sample_timer = 0.0
	else:
		_stuck_timer = 0.0
		_stuck_sample_timer = 0.0
		_stuck_sample_path_target = current_path_target
		_stuck_sample_path_distance = current_path_distance
		_stuck_sample_destination_distance = destination_distance_flat


	# Jika guru berada di atas furnitur, tetap arahkan gerak ke tujuan yang lebih rendah.
	# Sebelumnya cabang ini mereset timer macet setiap frame dan langsung return saat
	# NavigationAgent menganggap rute selesai; akibatnya guru bisa diam selamanya.
	if target_below:
		if nav_agent.target_position.distance_to(active_destination) > 0.5:
			nav_agent.target_position = active_destination
			_stuck_timer = 0.0
			return

		var move_direction := Vector3.ZERO
		if not nav_agent.is_navigation_finished():
			move_direction = _cached_next_path_position - global_position
		move_direction.y = 0.0

		# Saat tidak ada titik rute yang bisa diikuti, atau guru tidak membuat progres,
		# gunakan arah tujuan sebagai fallback, tetapi baca penghalang sebelum bergerak.
		if nav_agent.is_navigation_finished() or move_direction.length_squared() <= 0.001 or _stuck_timer >= 0.75:
			move_direction = active_destination - global_position
			move_direction.y = 0.0
		if move_direction.length_squared() > 0.001:
			move_direction = _get_obstacle_aware_direction(move_direction.normalized())
		if move_direction.length_squared() > 0.001:
			var move_speed := ghost_speed if String(_game.get("teacher_mode")) in ["ghost", "berserk", "responding"] else teacher_speed
			velocity.x = move_direction.x * move_speed
			velocity.z = move_direction.z * move_speed
			_face_direction(move_direction)
		else:
			velocity.x = 0.0
			velocity.z = 0.0

		# Jika benar-benar terkunci selama 5 detik, lakukan pemulihan terakhir.
		if _stuck_timer >= stuck_jump_delay and is_on_floor() and not _jump_recovery_active:
			_trigger_stuck_recovery()
		return

	# Pemulihan khusus pintu: jika jalur navmesh membuat guru diam tepat di depan
	# pintu kelas, hentikan pendekatan yang gagal dan lanjutkan state buka pintu.
	# _on_open_door memakai API pintu yang sama, lalu AI meneruskan investigasi
	# melalui navmesh setelah pintu terbuka.
	if _stuck_timer >= 1.5 and _current_state == State.MOVE_TO_DOOR and _door_target != null and is_instance_valid(_door_target):
		var door_gap := global_position - _door_target.global_position
		door_gap.y = 0.0
		if door_gap.length() <= 5.0:
			push_warning("TeacherAI: rute macet di depan pintu; beralih ke prosedur buka pintu.")
			_stop()
			_stuck_timer = 0.0
			_stuck_sample_initialized = false
			_set_state(State.OPEN_DOOR)
			return

	# Jika jalur navmesh tidak menghasilkan kemajuan, coba arah aman di sekitar
	# penghalang sebelum melompat. Ini juga memberi kesempatan melewati sudut meja
	# yang tidak tertangani oleh waypoint rute.
	if _stuck_timer >= 1.0 and should_be_moving and not _jump_recovery_active:
		var path_direction := Vector3.ZERO
		if not nav_agent.is_navigation_finished():
			path_direction = _cached_next_path_position - global_position
		path_direction.y = 0.0
		if path_direction.length_squared() <= 0.001:
			path_direction = active_destination - global_position
			path_direction.y = 0.0
		if path_direction.length_squared() > 0.001:
			var recovery_direction := _get_obstacle_aware_direction(path_direction.normalized())
			if recovery_direction.length_squared() > 0.001:
				var recovery_speed := ghost_speed if String(_game.get("teacher_mode")) in ["ghost", "berserk", "responding"] else teacher_speed
				velocity.x = recovery_direction.x * recovery_speed
				velocity.z = recovery_direction.z * recovery_speed
				_face_direction(recovery_direction)

	if _jump_recovery_active or not is_on_floor():
		return

	if _stuck_timer < stuck_jump_delay:
		return

	_trigger_stuck_recovery()


func _trigger_stuck_recovery() -> void:
	# Jangan mengulang lompatan tanpa batas pada tujuan yang gagal dicapai.
	# Patroli memilih waypoint lain; investigasi melewati titik yang terhalang;
	# pendekatan pintu/keluar/search kembali ke patroli. Pengejaran tetap menjaga target.
	if _stuck_recovery_attempts >= 1:
		_stop()
		_stuck_timer = 0.0
		match _current_state:
			State.PATROL:
				push_warning("TeacherAI: waypoint patroli tidak tercapai setelah pemulihan; memilih waypoint berikutnya.")
				_choose_next_corridor_waypoint()
				return
			State.INVESTIGATE:
				push_warning("TeacherAI: titik investigasi terhalang setelah pemulihan; melewati titik itu.")
				_current_waypoint_index += 1
				_state_timer = 0.0
				_stuck_recovery_attempts = 0
				_stuck_sample_initialized = false
				if _current_waypoint_index >= _room_waypoints.size():
					_set_state(State.EXIT_ROOM)
				else:
					nav_agent.target_position = _room_waypoints[_current_waypoint_index]
				return
			State.MOVE_TO_DOOR, State.EXIT_ROOM, State.SEARCH:
				push_warning("TeacherAI: tujuan ruangan/search tidak tercapai setelah pemulihan; kembali ke patroli.")
				_door_target = null
				_room_target = null
				_set_state(State.PATROL)
				_choose_next_corridor_waypoint()
				return

	_stuck_recovery_attempts += 1
	_jump_recovery_active = true
	velocity.y = stuck_jump_velocity
	_stuck_timer = 0.0
	print("TeacherAI: terjebak ", stuck_jump_delay, " detik, melakukan lompatan pemulihan ke-", _stuck_recovery_attempts, ".")


func _get_obstacle_aware_direction(desired_direction: Vector3) -> Vector3:
	var direction := desired_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return Vector3.ZERO
	direction = direction.normalized()

	# Sensor dipakai hanya ketika watchdog mendeteksi hambatan; navigasi normal
	# tetap mengikuti NavigationAgent, sedangkan sensor membantu memilih arah aman
	# saat rute tidak menghasilkan kemajuan.
	if not _is_obstacle_ahead(direction, 1.35):
		return direction

	var left_direction := direction.rotated(Vector3.UP, -0.85).normalized()
	var right_direction := direction.rotated(Vector3.UP, 0.85).normalized()
	var left_clear := not _is_obstacle_ahead(left_direction, 1.15)
	var right_clear := not _is_obstacle_ahead(right_direction, 1.15)

	if left_clear:
		return left_direction
	if right_clear:
		return right_direction
	return Vector3.ZERO


func _is_obstacle_ahead(direction: Vector3, distance: float) -> bool:
	if direction.length_squared() <= 0.001:
		return false
	var origin := global_position + Vector3.UP * 1.05
	var destination := origin + direction.normalized() * distance
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _get_xiid_board() -> Node3D:
	# Target pengawasan harus selalu papan Kelas XII D, bukan papan
	# yang kebetulan tersimpan pada board_node dari interaksi sebelumnya.
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	var furniture := scene_root.find_child("Kelas_12_D_Furniture", true, false) as Node3D
	if furniture == null:
		return null
	var board := furniture.get_node_or_null("FurnitureRoot/Whiteboard") as Node3D
	return board


func _get_xiid_room_interior_direction(board: Node3D) -> Vector3:
	# Gunakan RoomPoints XII D untuk menentukan sisi dalam kelas. Ini mencegah
	# posisi pemain di kelas lain membalikkan target guru ke sisi luar dinding.
	var scene_root := get_tree().current_scene
	if scene_root == null or board == null:
		return Vector3.ZERO
	var room := scene_root.find_child("Classroom_12", true, false)
	if room == null:
		return Vector3.ZERO
	var points := room.get_node_or_null("RoomPoints")
	if points == null or points.get_child_count() == 0:
		return Vector3.ZERO
	var center := Vector3.ZERO
	var count := 0
	for point in points.get_children():
		if point is Node3D:
			center += (point as Node3D).global_position
			count += 1
	if count == 0:
		return Vector3.ZERO
	center /= float(count)
	var direction := center - board.global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO


func _process_board_responding(delta: float) -> void:
	# Saat soal dikerjakan, guru menuju papan XII D secara eksplisit dan
	# mengawasi dari sisi dalam kelas, bukan kelas asal board_node.
	var board := _get_xiid_board()
	var player := _game.get("board_player") as Node3D
	if board == null or not is_instance_valid(board) or player == null or not is_instance_valid(player):
		_stop()
		if has_meta("board_monitor_position"):
			remove_meta("board_monitor_position")
		if is_on_floor():
			velocity.y = -0.5
		else:
			velocity.y -= 24.0 * delta
		move_and_slide()
		return

	# Buang target lama bila papan sumber berubah; jangan memakai titik dari kelas sebelumnya.
	if has_meta("board_monitor_board_id") and int(get_meta("board_monitor_board_id")) != board.get_instance_id():
		remove_meta("board_monitor_position")
		remove_meta("board_monitor_board_id")

	# Simpan titik pengawasan saat mulai agar guru tidak ikut bergeser mengikuti pemain.
	if not has_meta("board_monitor_position"):
		var front_direction := _get_xiid_room_interior_direction(board)
		if front_direction.length_squared() <= 0.001:
			# Fallback jika marker RoomPoints tidak tersedia: gunakan sisi pemain hanya
			# ketika pemain memang dekat dengan papan XII D.
			front_direction = player.global_position - board.global_position
			front_direction.y = 0.0
			if front_direction.length_squared() <= 0.01:
				front_direction = board.global_basis.x
			front_direction = front_direction.normalized()
		# Titik pengawasan berada di sisi dalam kelas, sedikit ke kiri papan.
		var board_left := -front_direction.cross(Vector3.UP).normalized()
		var monitor_position := board.global_position + front_direction * 1.8 + board_left * 1.7
		monitor_position.y = global_position.y
		set_meta("board_monitor_position", monitor_position)
		set_meta("board_monitor_board_id", board.get_instance_id())

	var monitor_target: Vector3 = get_meta("board_monitor_position")

	# Arahkan guru ke pintu XII D terlebih dahulu. Menargetkan papan langsung dari
	# kelas lain dapat menghasilkan jalur yang terputus di sisi luar dinding.
	var door_target := Vector3(42.1972, global_position.y, -57.343)
	var approach_target := door_target
	if global_position.distance_to(door_target) <= 1.8:
		approach_target = monitor_target

	var to_monitor := approach_target - global_position
	to_monitor.y = 0.0
	if to_monitor.length() > 0.45:
		# Tahap 1: navigasi ke pintu kelas XII D. Tahap 2: setelah mencapai
		# ambang pintu, lanjutkan ke titik pengawasan di dalam kelas.
		if nav_agent != null:
			if nav_agent.target_position.distance_to(approach_target) > 0.35:
				nav_agent.target_position = approach_target
			_cached_next_path_position = nav_agent.get_next_path_position()
			if _try_open_door_in_path():
				velocity.x = 0.0
				velocity.z = 0.0
				if is_on_floor():
					velocity.y = -0.5
				else:
					velocity.y -= 24.0 * delta
				move_and_slide()
				_update_footsteps(delta, "responding")
				return
			var move_direction := _cached_next_path_position - global_position
			move_direction.y = 0.0
			if move_direction.length_squared() <= 0.001:
				# Jika NavigationAgent belum memberi waypoint (misalnya jalur
				# menuju ruang kelas belum tersambung), jangan membiarkan guru
				# diam selamanya. Coba arah aman menuju titik pengawasan; sensor
				# halangan tetap aktif dan pemeriksaan pintu berjalan tiap tick.
				move_direction = _get_obstacle_aware_direction(to_monitor.normalized())
			if move_direction.length_squared() <= 0.001:
				velocity.x = 0.0
				velocity.z = 0.0
			else:
				move_direction = move_direction.normalized()
				velocity.x = move_direction.x * teacher_speed
				velocity.z = move_direction.z * teacher_speed
		else:
			var move_direction := _get_obstacle_aware_direction(to_monitor.normalized())
			velocity.x = move_direction.x * teacher_speed
			velocity.z = move_direction.z * teacher_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# Guru mengawasi pemain dan sesekali memeriksa papan, tanpa mengejar.
	_responding_look_timer += delta
	if _responding_look_timer >= (1.1 if _responding_look_at_board else 1.4):
		_responding_look_timer = 0.0
		_responding_look_at_board = not _responding_look_at_board
	var look_target: Node3D = board if _responding_look_at_board else player
	var look_direction := look_target.global_position - global_position
	look_direction.y = 0.0
	if look_direction.length_squared() > 0.001:
		var target_yaw := atan2(-look_direction.x, -look_direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 4.0, 0.0, 1.0))

	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 24.0 * delta
	move_and_slide()


func _handle_mode_change(mode: String) -> void:
	if mode != "responding" and has_meta("board_monitor_position"):
		remove_meta("board_monitor_position")
	if mode != _last_mode and mode == "responding":
		_responding_look_timer = 0.0
		_responding_look_at_board = true
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
		audio.play_sfx("ghost_whisper")
	elif mode == "responding":
		audio.play_sfx("teacher_alert")
		audio.stop_loop("teacher_ghost_loop")
	else:
		audio.stop_loop("teacher_ghost_loop")


func _get_mode_target(mode: String) -> Node3D:
	if mode in ["berserk", "responding"]:
		# Target paksa tetap tunduk pada pengecualian murid yang sedang dihukum/KO.
		var forced: Variant = null
		if has_meta("teacher_target"):
			forced = get_meta("teacher_target")
		elif is_instance_valid(_game) and _game.has_meta("teacher_target"):
			forced = _game.get_meta("teacher_target")
		var forced_target := forced as Node3D
		if _is_forbidden_player_target(forced_target):
			return null
		# Berserk tetap melacak target valid meski target bersembunyi.
		return forced_target

	if mode != "ghost":
		_current_target = null
		return null

	if _current_target != null and is_instance_valid(_current_target):
		if not _is_forbidden_player_target(_current_target) and _should_detect(_current_target):
			return _current_target
		if _current_target is Node3D:
			_last_known_target_position = _current_target.global_position
		_current_target = null

	for player in get_tree().get_nodes_in_group("players"):
		if not player is CharacterBody3D:
			continue

		var candidate := player as CharacterBody3D
		if _is_forbidden_player_target(candidate):
			continue

		if _should_detect(candidate):
			_current_target = candidate
			return _current_target

	return null


func _is_forbidden_player_target(candidate: Node) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return true
	# Murid sedang fokus mengerjakan soal di papan: guru tidak boleh memilihnya
	# sebagai target tangkapan selama kamera berada dalam mode papan.
	if bool(candidate.get_meta("whiteboard_mode", false)):
		return true
	# Flag ini berlaku di desktop dan HP; whiteboard_mode hanya mengunci kontrol HP.
	if bool(candidate.get_meta("whiteboard_active", false)):
		return true
	if bool(candidate.get_meta("knocked_out", false)):
		return true
	if bool(candidate.get_meta("capture_dragging", false)) or bool(candidate.get_meta("capture_animation", false)):
		return true
	if _game != null:
		var exam_player: Variant = _game.get("penalty_player")
		if exam_player is Node and candidate == exam_player:
			return true
	return false


func _should_detect(player: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false

	if bool(player.get_meta("is_hidden", false)):
		return false

	var offset := player.global_position - global_position
	var distance := Vector2(offset.x, offset.z).length()
	if distance > detection_distance:
		return false

	# Jarak dekat tidak boleh otomatis menembus meja/lemari. Deteksi visual tetap
	# membutuhkan raycast yang tidak terhalang; sistem suara dapat ditambahkan terpisah.

	if _cached_detection_target != player or _detection_check_remaining <= 0.0:
		_cached_detection_target = player
		_cached_detection_result = _has_line_of_sight(player)
		_detection_check_remaining = 0.12

	return _cached_detection_result


func _has_line_of_sight(target: Node3D) -> bool:
	# Raycast menggunakan tinggi badan bagian tengah agar meja/lemari dapat memblokir
	# pandangan. Gunakan seluruh layer fisika; furniture tertentu tidak berada di layer 1.
	var origin := global_position + Vector3.UP * 1.55
	var destination := target.global_position + Vector3.UP * 1.0

	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.collision_mask = 0xFFFFFFFF
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


func _ensure_startup_room_door_open() -> void:
	# Cutscene berakhir di ruang guru. Buka pintu ruang guru satu kali agar
	# patroli tidak tertahan menabrak daun pintu yang tertutup.
	var selected_door: Node3D = null
	var selected_distance := INF
	for candidate in get_tree().get_nodes_in_group("doors"):
		var door := candidate as Node3D
		if door == null or not door.has_method("interact"):
			continue
		var normalized_name := String(door.name).to_lower().replace("_", "").replace(" ", "")
		if not (normalized_name.contains("ruangguru") or normalized_name.contains("teacherroom")):
			continue
		var distance: float = global_position.distance_to(door.global_position)
		if distance < selected_distance:
			selected_distance = distance
			selected_door = door

	if selected_door == null:
		return
	if _door_is_locked(selected_door):
		return
	if _door_is_open(selected_door):
		_startup_room_exit_complete = true
		return
	if global_position.distance_to(selected_door.global_position) <= 9.0 and _door_cooldown_remaining <= 0.0:
		_open_door(selected_door)
		if _door_is_open(selected_door):
			_startup_room_exit_complete = true


func _get_scene_root() -> Node:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	return scene_root


func _collect_corridor_waypoints() -> void:
	_corridor_waypoints.clear()

	var corridor_node := _get_scene_root().get_node_or_null("Map58/Rooms/Corridor")
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
	_stuck_timer = 0.0
	_stuck_sample_timer = 0.0
	_stuck_sample_initialized = false
	_stuck_recovery_attempts = 0

	if _corridor_waypoints.is_empty():
		push_warning("TeacherAI_New: tidak ada waypoint koridor untuk patroli.")
		return

	# Gunakan kantong waypoint acak: guru mengunjungi semua titik sebelum
	# mengulang siklus, bukan terus memilih titik terdekat/area yang sama.
	if _corridor_waypoint_queue.is_empty():
		_corridor_waypoint_queue.clear()
		for waypoint in _corridor_waypoints:
			if waypoint != null and is_instance_valid(waypoint) and waypoint != _current_corridor_waypoint:
				_corridor_waypoint_queue.append(waypoint)

		# Acak urutan seluruh titik yang belum dikunjungi pada siklus ini.
		for i in range(_corridor_waypoint_queue.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var temp := _corridor_waypoint_queue[i]
			_corridor_waypoint_queue[i] = _corridor_waypoint_queue[j]
			_corridor_waypoint_queue[j] = temp

	if _corridor_waypoint_queue.is_empty():
		# Jika hanya ada satu waypoint valid, tetap gunakan titik itu.
		for waypoint in _corridor_waypoints:
			if waypoint != null and is_instance_valid(waypoint):
				_current_corridor_waypoint = waypoint
				print("TeacherAI patroli: tujuan ", waypoint.name)
				return
		return

	while not _corridor_waypoint_queue.is_empty():
		var candidate: Node3D = _corridor_waypoint_queue.pop_front()
		if candidate != null and is_instance_valid(candidate) and candidate != _current_corridor_waypoint:
			_current_corridor_waypoint = candidate
			print("TeacherAI patroli: tujuan berikutnya ", candidate.name,
				" | sisa titik siklus: ", _corridor_waypoint_queue.size())
			return

	# Jika antrean berisi node yang sudah dihapus, bangun ulang pada pemanggilan berikutnya.
	_corridor_waypoint_queue.clear()


func _get_all_classrooms() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var rooms_node := _get_scene_root().get_node_or_null("Map58/Rooms")

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
	var best_distance := 10.0
	for door in get_tree().get_nodes_in_group("doors"):
		var door_3d := door as Node3D
		if door_3d == null or not door_3d.has_method("interact"):
			continue

		var distance := marker.global_position.distance_to(door_3d.global_position)
		if distance < best_distance:
			best_distance = distance
			best = door_3d

	return best


func _update_auto_close_door() -> void:
	# Tutup pintu yang dibuka AI setelah seluruh badan guru meninggalkan area pintu.
	# Jangan membalik tween yang masih berjalan atau menutup saat guru masih dekat.
	if _last_door_opened == null or not is_instance_valid(_last_door_opened):
		_last_door_opened = null
		return
	if not _door_is_open(_last_door_opened):
		_last_door_opened = null
		return
	if _last_door_opened.has_method("is_transitioning") and bool(_last_door_opened.call("is_transitioning")):
		return
	var away := global_position - _last_door_opened.global_position
	away.y = 0.0
	if away.length() < 3.4 or _door_cooldown_remaining > 0.0:
		return

	# Jarak saja tidak cukup: guru bisa terdorong menjauh ke sisi asal pintu
	# sebelum berhasil melewatinya. Tutup hanya setelah tujuan aktif berada di
	# sisi yang sama dengan guru, yang menandakan guru sudah melewati ambang.
	var destination_offset := _get_active_navigation_destination() - _last_door_opened.global_position
	destination_offset.y = 0.0
	if destination_offset.length_squared() <= 0.25 or away.normalized().dot(destination_offset.normalized()) <= 0.15:
		return

	_close_door(_last_door_opened)
	_last_door_opened = null


func _open_door(door: Node3D, close_after_passing: bool = true) -> void:
	if door == null or not is_instance_valid(door):
		return

	if _door_cooldown_remaining > 0.0:
		return

	if door.has_method("interact"):
		door.interact(self)
		_last_door_opened = door if close_after_passing else null
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

	if door.has_method("is_locked") and bool(door.is_locked()):
		# Beberapa pintu kelas membutuhkan kunci untuk murid, tetapi AI guru
		# memang diizinkan membukanya melalui interact(self).
		if door.has_method("can_teacher_open") and bool(door.can_teacher_open()):
			return false
		return true

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

	if audio != null:
		var volume := -4.0
		var pitch := 0.90

		if mode in ["ghost", "berserk", "responding"]:
			volume = -2.5
			pitch = 0.86

		if audio.has_method("play_teacher_footstep"):
			audio.play_teacher_footstep(volume, pitch, global_position)
		elif audio.has_method("play_footstep"):
			audio.play_footstep(volume, pitch)

	var base_interval := teacher_step_interval
	if mode in ["ghost", "berserk", "responding"]:
		base_interval = ghost_step_interval
	# Frekuensi langkah mengikuti kecepatan gerak aktual AI, bukan hanya mode-nya.
	var speed_ratio := clampf(horizontal_speed / maxf(nav_max_speed, 0.1), 0.45, 1.15)
	_footstep_remaining = base_interval / speed_ratio


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
