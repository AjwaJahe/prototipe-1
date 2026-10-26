extends Node

## Replicates player avatars and provides multiplayer diagnostics/toasts.
const AVATAR_SCENE: PackedScene = preload("res://PlayerCharacter.tscn")
const SEND_INTERVAL := 0.08
const REMOTE_SMOOTHING := 14.0
const HUD_REFRESH_INTERVAL := 0.25
const PING_INTERVAL := 1.0

var _local_body: CharacterBody3D
var _send_timer := 0.0
var _remote_avatars: Dictionary = {}
var _remote_targets: Dictionary = {}
# Server-side movement validation: last accepted position and receive time per peer.
var _accepted_player_positions: Dictionary = {}
var _accepted_player_state_times: Dictionary = {}
var _peer_inventory_types: Dictionary = {}
var _peer_inventory_item_paths: Dictionary = {}
var _last_hiding_visual_states: Dictionary = {}
var _hud_elapsed := 0.0
var _ping_elapsed := 0.0
var _sync_elapsed := 0.0
var _last_sent_world_sections: Dictionary = {}
const WORLD_SYNC_INTERVAL := 0.2
# Host mengosongkan cache delta tiap interval ini sehingga semua pintu/item/rak/tempat
# sembunyi dikirim ulang penuh (pengaman bila paket reliable hilang saat client belum siap).
const WORLD_FULL_RESYNC_INTERVAL := 6.0
var _full_resync_elapsed := WORLD_FULL_RESYNC_INTERVAL
# Sisi client: true setelah host membalas snapshot penuh pertama.
var _world_synced := false
var _world_ready_attempts := 0
var _ping_ms := -1
var _peer_ping_ms: Dictionary = {}
var _network_label: Label
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_timer: Timer


func _ready() -> void:
	if not bool(get_tree().get_meta("kelas_malam_multiplayer_active", false)):
		set_process(false)
		return

	_local_body = get_node_or_null("../Player/CharacterBody3D") as CharacterBody3D
	if _local_body == null:
		push_error("MultiplayerGame: Player/CharacterBody3D tidak ditemukan.")
		set_process(false)
		return

	_build_network_hud()
	# Host mengendalikan AI guru; client mengikuti snapshot jaringan.
	if not multiplayer.is_server():
		var teacher := get_node_or_null("../Teacher")
		if teacher != null:
			teacher.set_process(false)
			teacher.set_physics_process(false)
	var communication := Node.new()
	communication.name = "MultiplayerCommunication"
	communication.set_script(load("res://MultiplayerCommunication.gd"))
	add_child(communication)
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	call_deferred("_announce_after_spawn")
	# Client minta snapshot dunia penuh dari host begitu scene siap.
	if not multiplayer.is_server():
		call_deferred("_request_full_world_sync")
	_refresh_network_hud()


func _build_network_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "MultiplayerNetworkHUD"
	canvas.layer = 40
	add_child(canvas)

	var status_panel := Control.new()
	status_panel.name = "NetworkStatusPanel"
	status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status_panel.offset_left = -285.0
	status_panel.offset_top = 18.0
	status_panel.offset_right = -18.0
	status_panel.offset_bottom = 42.0
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_theme_stylebox_override("panel", _hud_style(Color(0.025, 0.035, 0.05, 0.78), Color(0.35, 0.48, 0.62, 0.75)))
	canvas.add_child(status_panel)

	_network_label = Label.new()
	_network_label.name = "NetworkStats"
	_network_label.text = "FPS: --   PING: --"
	_network_label.add_theme_font_size_override("font_size", 12)
	_network_label.add_theme_color_override("font_color", Color(0.88, 0.93, 0.98))
	_network_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(_network_label)

	_toast_panel = PanelContainer.new()
	_toast_panel.name = "MultiplayerToast"
	# Notifikasi multiplayer berada tepat di bawah tombol menu/setting tengah-atas,
	# bukan melebar di atas minimap atau menutupi HUD lain.
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.offset_left = -240.0
	_toast_panel.offset_top = 66.0
	_toast_panel.offset_right = 240.0
	_toast_panel.offset_bottom = 116.0
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_theme_stylebox_override("panel", _hud_style(Color(0.025, 0.035, 0.05, 0.9), Color(0.82, 0.27, 0.25, 0.9)))
	canvas.add_child(_toast_panel)

	_toast_label = Label.new()
	_toast_label.name = "ToastText"
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_font_size_override("font_size", 17)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.88))
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast_label)

	_toast_timer = Timer.new()
	_toast_timer.name = "ToastTimer"
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 3.2
	_toast_timer.timeout.connect(_hide_toast)
	add_child(_toast_timer)


func _hud_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _show_toast(message: String) -> void:
	if not is_instance_valid(_toast_panel) or not is_instance_valid(_toast_label):
		return
	_toast_label.text = message
	_toast_panel.visible = true
	_toast_timer.start(3.2)


func _hide_toast() -> void:
	if is_instance_valid(_toast_panel):
		_toast_panel.visible = false


func _refresh_network_hud() -> void:
	if not is_instance_valid(_network_label) or not _has_active_multiplayer_peer():
		return
	var fps := Engine.get_frames_per_second()
	var ping_text := _host_ping_text() if multiplayer.is_server() else ("%d ms" % _ping_ms if _ping_ms >= 0 else "--")
	var player_count := multiplayer.get_peers().size() + 1
	_network_label.text = "FPS: %d   PING: %s   PEMAIN: %d" % [fps, ping_text, player_count]


func _process(delta: float) -> void:
	if not _has_active_multiplayer_peer():
		return
	if not is_instance_valid(_local_body):
		return

	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer = SEND_INTERVAL
		_send_local_state()

	for peer_id in _remote_avatars.keys():
		var avatar := _remote_avatars[peer_id] as Node3D
		if not is_instance_valid(avatar):
			_remote_avatars.erase(peer_id)
			_remote_targets.erase(peer_id)
			continue
		var target: Dictionary = _remote_targets.get(peer_id, {})
		if target.is_empty():
			continue
		var blend := clampf(delta * REMOTE_SMOOTHING, 0.0, 1.0)
		avatar.global_position = avatar.global_position.lerp(target["position"], blend)
		avatar.rotation.y = lerp_angle(avatar.rotation.y, float(target["yaw"]), blend)
		_animate_remote_avatar(avatar, bool(target.get("crouching", false)), float(target.get("horizontal_speed", 0.0)), bool(target.get("knocked_out", false)))

	_hud_elapsed -= delta
	if _hud_elapsed <= 0.0:
		_hud_elapsed = HUD_REFRESH_INTERVAL
		_refresh_network_hud()

	if multiplayer.is_server():
		_full_resync_elapsed -= delta
		if _full_resync_elapsed <= 0.0:
			_full_resync_elapsed = WORLD_FULL_RESYNC_INTERVAL
			# Cache kosong = pengiriman berikutnya memuat semua entri, bukan hanya yang berubah.
			_last_sent_world_sections.clear()

	_sync_elapsed -= delta
	if _sync_elapsed <= 0.0:
		_sync_elapsed = WORLD_SYNC_INTERVAL
		if multiplayer.is_server():
			_send_world_snapshot()

	_ping_elapsed -= delta
	if _ping_elapsed <= 0.0:
		_ping_elapsed = PING_INTERVAL
		if multiplayer.is_server():
			# Host mengukur sinyal ke tiap pemain (bukan sekadar menulis HOST).
			if not multiplayer.get_peers().is_empty():
				_host_ping_request.rpc(Time.get_ticks_msec())
		else:
			_ping_probe.rpc_id(1, Time.get_ticks_msec())


func _announce_after_spawn() -> void:
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(_local_body) and multiplayer.multiplayer_peer != null:
		_send_local_state()


func _has_active_multiplayer_peer() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func _send_local_state() -> void:
	if not _has_active_multiplayer_peer() or not is_instance_valid(_local_body):
		return
	var display_name := String(get_tree().get_meta("kelas_malam_player_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = "Pemain %d" % multiplayer.get_unique_id()
	var horizontal_speed := Vector2(_local_body.velocity.x, _local_body.velocity.z).length()
	var crouching := bool(_local_body.get("is_crouching")) or Input.is_key_pressed(KEY_CTRL)
	var knocked_out := bool(_local_body.get_meta("knocked_out", false))
	var is_hidden := bool(_local_body.get_meta("is_hidden", false))
	var inventory_types: Array = []
	var inventory := _local_body.get_node_or_null("ItemInventory")
	if inventory != null and inventory.has_method("get_inventory"):
		inventory_types = inventory.call("get_inventory")
	if multiplayer.is_server():
		# Host publishes its own pose to clients; it does not need a proxy for itself.
		_broadcast_player_state.rpc(1, _local_body.global_position, _local_body.global_rotation.y, display_name, crouching, horizontal_speed, knocked_out, is_hidden, inventory_types)
	else:
		# Clients submit state only to the host. Other clients never trust peer-to-peer state.
		_submit_player_state.rpc_id(1, _local_body.global_position, _local_body.global_rotation.y, display_name, crouching, horizontal_speed, knocked_out, is_hidden, inventory_types)


@rpc("any_peer", "call_remote", "unreliable")
func _submit_player_state(world_position: Vector3, body_yaw: float, display_name: String, crouching: bool, horizontal_speed: float, knocked_out: bool, is_hidden: bool, inventory_types: Array) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not multiplayer.get_peers().has(sender_id):
		return
	if not world_position.is_finite() or not is_finite(body_yaw) or not is_finite(horizontal_speed):
		return
	# Kecepatan hanya untuk animasi remote; batasi agar paket klien tidak dapat
	# memaksa animasi dengan nilai tak masuk akal.
	horizontal_speed = clampf(horizontal_speed, 0.0, 18.0)
	# Inventori adalah state otoritatif host. Jangan menimpa data ini dengan
	# daftar item yang dikirim klien setiap 0,08 detik; perubahan hanya melalui
	# RPC pickup/drop/rak yang divalidasi host.
	inventory_types = (_peer_inventory_types.get(sender_id, []) as Array).duplicate()

	var now_ms := Time.get_ticks_msec()
	var avatar := _remote_avatars.get(sender_id) as CharacterBody3D
	# First packet must start near the deterministic spawn assigned to this peer.
	# Without this, a new client could place its proxy anywhere before validation begins.
	if not is_instance_valid(avatar) and not _accepted_player_positions.has(sender_id):
		var spawn_manager := get_node_or_null("../SpawnManager")
		if spawn_manager != null and spawn_manager.has_method("get_spawn_position_for_peer"):
			var expected_spawn: Vector3 = spawn_manager.call("get_spawn_position_for_peer", sender_id)
			if expected_spawn != Vector3.ZERO and world_position.distance_to(expected_spawn) > 3.0:
				world_position = expected_spawn
				body_yaw = 0.0
				_correct_local_player_position.rpc_id(sender_id, expected_spawn, body_yaw)
	# These gameplay flags are host-owned; client packets cannot hide or unhide a proxy.
	if is_instance_valid(avatar):
		is_hidden = bool(avatar.get_meta("is_hidden", false))
		knocked_out = bool(avatar.get_meta("knocked_out", false))
	else:
		# Initial peer state cannot self-assign host-owned gameplay flags.
		is_hidden = false
		knocked_out = false
	# While the host has approved hiding, keep the server-controlled pose and state;
	# client packets must not pull the proxy out of the hiding spot.
	var host_movement_locked := is_instance_valid(avatar) and (
		is_hidden
		or knocked_out
		or bool(avatar.get_meta("intro_locked", false))
		or bool(avatar.get_meta("capture_dragging", false))
		or bool(avatar.get_meta("capture_pose", false))
	)
	if host_movement_locked:
		# Saat host mengendalikan intro, persembunyian, tangkapan, atau KO,
		# paket posisi klien tidak boleh menggeser avatar proxy.
		world_position = avatar.global_position
		body_yaw = avatar.global_rotation.y
		avatar.velocity = Vector3.ZERO
		# Saat ditangkap, kirim pose otoritatif ke pemain yang sedang ditarik juga.
		# Broadcast biasa hanya memperbarui avatar remote; tanpa RPC ini, POV pemain
		# yang tertangkap tertinggal di posisi awal.
		var capture_animation := bool(avatar.get_meta("capture_animation", false))
		var capture_dragging := bool(avatar.get_meta("capture_dragging", false))
		var intro_sitting := bool(avatar.get_meta("intro_sitting", false))
		if capture_animation or capture_dragging or intro_sitting:
			_sync_captured_local_state.rpc_id(
				sender_id,
				avatar.global_position,
				avatar.global_rotation.y,
				capture_animation,
				capture_dragging,
				intro_sitting,
				bool(avatar.get_meta("intro_locked", false)),
				bool(avatar.get_meta("knocked_out", false))
			)
	if is_instance_valid(avatar) and not host_movement_locked and _accepted_player_positions.has(sender_id):
		var previous_position: Vector3 = _accepted_player_positions[sender_id]
		var previous_ms := int(_accepted_player_state_times.get(sender_id, now_ms))
		var elapsed := clampf(float(now_ms - previous_ms) / 1000.0, 0.05, 0.5)
		var horizontal_delta := Vector2(world_position.x - previous_position.x, world_position.z - previous_position.z).length()
		var vertical_delta := absf(world_position.y - previous_position.y)
		# Allow run speed (15 m/s) plus network jitter and a small packet-loss margin.
		var max_horizontal_delta := 18.0 * elapsed + 1.25
		var max_vertical_delta := 8.0 * elapsed + 0.9
		if horizontal_delta > max_horizontal_delta or vertical_delta > max_vertical_delta:
			# Reject implausible movement and correct the sender to the last accepted pose.
			_correct_local_player_position.rpc_id(sender_id, previous_position, avatar.global_rotation.y)
			return

	_accepted_player_positions[sender_id] = world_position
	_accepted_player_state_times[sender_id] = now_ms
	_apply_player_state(sender_id, world_position, body_yaw, display_name, crouching, horizontal_speed, knocked_out, is_hidden, inventory_types)
	_broadcast_player_state.rpc(sender_id, world_position, body_yaw, display_name, crouching, horizontal_speed, knocked_out, is_hidden, inventory_types)


@rpc("authority", "call_remote", "unreliable")
func _broadcast_player_state(peer_id: int, world_position: Vector3, body_yaw: float, display_name: String, crouching: bool, horizontal_speed: float, knocked_out: bool, is_hidden: bool, inventory_types: Array) -> void:
	if multiplayer.is_server():
		return
	_apply_player_state(peer_id, world_position, body_yaw, display_name, crouching, horizontal_speed, knocked_out, is_hidden, inventory_types)


func _apply_player_state(peer_id: int, world_position: Vector3, body_yaw: float, display_name: String, crouching: bool, horizontal_speed: float, knocked_out: bool, is_hidden: bool, inventory_types: Array) -> void:
	if peer_id <= 0 or peer_id == multiplayer.get_unique_id():
		return
	if not _remote_avatars.has(peer_id) or not is_instance_valid(_remote_avatars.get(peer_id)):
		_create_remote_avatar(peer_id, world_position, body_yaw, display_name)
	var avatar := _remote_avatars.get(peer_id) as Node3D
	if not is_instance_valid(avatar):
		return
	var name_label := avatar.get_node_or_null("PlayerLabel") as Label3D
	if name_label != null:
		name_label.text = display_name if not display_name.is_empty() else "Pemain %d" % peer_id
	# Jangan biarkan paket gerak biasa menimpa state yang sedang dikunci host.
	var host_locked := bool(avatar.get_meta("intro_locked", false))
	var authoritative_knocked_out := bool(avatar.get_meta("knocked_out", false)) if host_locked else knocked_out
	avatar.set_meta("is_crouching", crouching)
	avatar.set_meta("knocked_out", authoritative_knocked_out)
	if not host_locked:
		avatar.set_meta("is_hidden", is_hidden)
	avatar.set_meta("inventory_types", inventory_types.duplicate())
	if is_hidden and avatar is CharacterBody3D:
		(avatar as CharacterBody3D).velocity = Vector3.ZERO

	var authoritative_position := world_position
	var authoritative_yaw := body_yaw
	if bool(avatar.get_meta("intro_locked", false)) or authoritative_knocked_out or bool(avatar.get_meta("is_hidden", false)):
		authoritative_position = avatar.global_position
		authoritative_yaw = avatar.global_rotation.y
	_remote_targets[peer_id] = {
		"position": authoritative_position,
		"yaw": authoritative_yaw,
		"crouching": crouching,
		"horizontal_speed": horizontal_speed,
		"knocked_out": authoritative_knocked_out,
		"is_hidden": is_hidden
	}


@rpc("authority", "call_remote", "unreliable")
func _sync_captured_local_state(world_position: Vector3, body_yaw: float, capture_animation: bool, capture_dragging: bool, intro_sitting: bool, intro_locked: bool, knocked_out: bool) -> void:
	# Hanya host yang boleh mengarahkan posisi pemain lokal selama penangkapan.
	if multiplayer.is_server() or not is_instance_valid(_local_body):
		return
	if not world_position.is_finite() or not is_finite(body_yaw):
		return
	_local_body.global_position = world_position
	_local_body.global_rotation.y = body_yaw
	_local_body.velocity = Vector3.ZERO
	_local_body.set_meta("capture_animation", capture_animation)
	_local_body.set_meta("capture_dragging", capture_dragging)
	_local_body.set_meta("intro_sitting", intro_sitting)
	_local_body.set_meta("intro_locked", intro_locked)
	_local_body.set_meta("knocked_out", knocked_out)
	var camera := _local_body.get_node_or_null("Head/Camera3D") as Camera3D
	if camera != null and intro_sitting:
		camera.position.y = 0.95


@rpc("authority", "call_remote", "reliable")
func _correct_local_player_position(world_position: Vector3, body_yaw: float) -> void:
	if multiplayer.is_server() or not is_instance_valid(_local_body):
		return
	_local_body.global_position = world_position
	_local_body.global_rotation.y = body_yaw
	_local_body.velocity = Vector3.ZERO


func _create_remote_avatar(peer_id: int, world_position: Vector3, body_yaw: float, display_name: String) -> void:
	# Remote peer harus menjadi CharacterBody3D sungguhan pada host, bukan sekadar
	# Node3D visual. AI guru dan logika deteksi hanya menerima grup "players" yang
	# berisi CharacterBody3D; sebelumnya pemain tamu tidak pernah menjadi target AI.
	var avatar := CharacterBody3D.new()
	avatar.name = "RemotePlayer_%d" % peer_id
	avatar.add_to_group("players")
	avatar.set_meta("network_peer_id", peer_id)
	avatar.set_meta("is_network_proxy", true)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collision.shape = capsule
	# Proxy hanya perlu ikut collision di host agar AI/raycast dapat mengenalinya.
	# Pada klien, collider remote dimatikan supaya tidak menghalangi kontrol lokal.
	collision.set_deferred("disabled", not multiplayer.is_server())
	avatar.add_child(collision)
	var visual := AVATAR_SCENE.instantiate()
	visual.name = "PlayerCharacter"

	# Mesh layer 2 hanya untuk culling kepala pemain lokal; avatar remote wajib terlihat.
	_set_remote_visual_layers(visual)
	avatar.add_child(visual)
	# Model visual berawal dari telapak kaki; pusat CharacterBody berada di pinggang.
	visual.position.y = -0.9
	add_child(avatar)
	avatar.global_position = world_position
	avatar.rotation.y = body_yaw

	var label := Label3D.new()
	label.name = "PlayerLabel"
	label.text = display_name if not display_name.is_empty() else "Pemain %d" % peer_id
	label.position = Vector3(0.0, 1.35, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	avatar.add_child(label)

	_remote_avatars[peer_id] = avatar
	_remote_targets[peer_id] = {"position": world_position, "yaw": body_yaw, "crouching": false, "horizontal_speed": 0.0, "knocked_out": false}
	print("MultiplayerGame: avatar remote dibuat untuk peer ", peer_id)


func _set_remote_visual_layers(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 1
	for child in node.get_children():
		_set_remote_visual_layers(child)


func _animate_remote_avatar(avatar: Node3D, crouching: bool, horizontal_speed: float, knocked_out: bool) -> void:
	var visual := avatar.get_node_or_null("PlayerCharacter/world") as Node3D
	if visual == null:
		return
	visual.visible = not bool(avatar.get_meta("is_hidden", false))
	if not visual.has_meta("_net_base_position"):
		visual.set_meta("_net_base_position", visual.position)
		visual.set_meta("_net_base_scale", visual.scale)
	var base_position: Vector3 = visual.get_meta("_net_base_position")
	var base_scale: Vector3 = visual.get_meta("_net_base_scale")
	var crouch_weight := 1.0 if crouching else 0.0
	if knocked_out:
		crouch_weight = 1.0
	var target_position := base_position + Vector3(0.0, -0.38 * crouch_weight, 0.0)
	var target_scale := Vector3(base_scale.x, base_scale.y * (0.78 if crouch_weight > 0.0 else 1.0), base_scale.z)
	visual.position = visual.position.lerp(target_position, 0.22)
	visual.scale = visual.scale.lerp(target_scale, 0.22)
	var torso := visual.get_node_or_null("Torso") as Node3D
	var left_leg := visual.get_node_or_null("Leg_L") as Node3D
	var right_leg := visual.get_node_or_null("Leg_R") as Node3D
	var left_arm := visual.get_node_or_null("Arm_L") as Node3D
	var right_arm := visual.get_node_or_null("Arm_R") as Node3D
	if torso != null and visual.has_meta("_net_torso_base"):
		var base: Vector3 = visual.get_meta("_net_torso_base")
		torso.rotation.x = lerp_angle(torso.rotation.x, base.x + deg_to_rad(12.0 * crouch_weight), 0.22)
	if torso != null and not visual.has_meta("_net_torso_base"):
		visual.set_meta("_net_torso_base", torso.rotation)
	if left_leg != null:
		if not visual.has_meta("_net_left_leg_base"):
			visual.set_meta("_net_left_leg_base", left_leg.rotation)
		var base: Vector3 = visual.get_meta("_net_left_leg_base")
		left_leg.rotation.x = lerp_angle(left_leg.rotation.x, base.x - deg_to_rad(18.0 * crouch_weight), 0.22)
	if right_leg != null:
		if not visual.has_meta("_net_right_leg_base"):
			visual.set_meta("_net_right_leg_base", right_leg.rotation)
		var base: Vector3 = visual.get_meta("_net_right_leg_base")
		right_leg.rotation.x = lerp_angle(right_leg.rotation.x, base.x + deg_to_rad(18.0 * crouch_weight), 0.22)
	if left_arm != null:
		if not visual.has_meta("_net_left_arm_base"):
			visual.set_meta("_net_left_arm_base", left_arm.rotation)
		var base: Vector3 = visual.get_meta("_net_left_arm_base")
		left_arm.rotation.x = lerp_angle(left_arm.rotation.x, base.x - deg_to_rad(8.0 * crouch_weight), 0.22)
	if right_arm != null:
		if not visual.has_meta("_net_right_arm_base"):
			visual.set_meta("_net_right_arm_base", right_arm.rotation)
		var base: Vector3 = visual.get_meta("_net_right_arm_base")
		right_arm.rotation.x = lerp_angle(right_arm.rotation.x, base.x - deg_to_rad(8.0 * crouch_weight), 0.22)
	if horizontal_speed > 0.15 and crouch_weight < 0.5:
		var cycle := Time.get_ticks_msec() * 0.001 * 8.0
		if left_leg != null:
			var base: Vector3 = visual.get_meta("_net_left_leg_base")
			left_leg.rotation.x = base.x + sin(cycle) * deg_to_rad(22.0)
		if right_leg != null:
			var base: Vector3 = visual.get_meta("_net_right_leg_base")
			right_leg.rotation.x = base.x - sin(cycle) * deg_to_rad(22.0)


@rpc("any_peer", "call_remote", "unreliable")
func _ping_probe(client_sent_ms: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id > 0:
		_ping_reply.rpc_id(sender_id, client_sent_ms)


@rpc("authority", "call_remote", "unreliable")
func _ping_reply(client_sent_ms: int) -> void:
	_ping_ms = maxi(0, Time.get_ticks_msec() - client_sent_ms)
	_refresh_network_hud()


# >>> HOST PING
@rpc("authority", "call_remote", "unreliable")
func _host_ping_request(host_sent_ms: int) -> void:
	_host_ping_response.rpc_id(1, host_sent_ms)


@rpc("any_peer", "call_remote", "unreliable")
func _host_ping_response(host_sent_ms: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id > 0:
		_peer_ping_ms[sender_id] = maxi(0, Time.get_ticks_msec() - host_sent_ms)


# Ping yang ditampilkan host = sinyal TERBURUK di antara pemain yang tersambung,
# karena itulah yang dirasakan pemain paling tertinggal.
func _host_ping_text() -> String:
	var peers := multiplayer.get_peers()
	if peers.is_empty():
		return "0 ms"
	for stored_id in _peer_ping_ms.keys():
		if not peers.has(stored_id):
			_peer_ping_ms.erase(stored_id)
	var worst := -1
	for peer_id in peers:
		worst = maxi(worst, int(_peer_ping_ms.get(peer_id, -1)))
	return "%d ms" % worst if worst >= 0 else "--"
# <<< HOST PING

@rpc("any_peer", "call_remote", "reliable")
func request_board_question(relative_path: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var avatar := _remote_avatars.get(sender_id) as Node3D
	var root := get_tree().current_scene
	if sender_id <= 1 or not is_instance_valid(avatar) or root == null:
		return
	var board := root.get_node_or_null(NodePath(relative_path)) as Node3D
	if board == null or avatar.global_position.distance_to(board.global_position) > 5.0:
		return
	var game := get_node_or_null("../GameManager")
	if game == null or not game.has_method("begin_board_question"):
		return
	var question: Dictionary = game.call("begin_board_question", avatar, board)
	if not question.is_empty():
		var controller := get_node_or_null("../WhiteboardController")
		if controller != null and controller.has_method("network_public_board_question"):
			controller.call("network_public_board_question", String(question.get("question", "")))
		_board_question_public.rpc(String(question.get("question", "")))
		_board_question_started.rpc_id(sender_id, question)


@rpc("authority", "call_remote", "reliable")
func _board_question_public(question_text: String) -> void:
	if multiplayer.is_server():
		return
	var controller := get_node_or_null("../WhiteboardController")
	if controller != null and controller.has_method("network_public_board_question"):
		controller.call("network_public_board_question", question_text)


@rpc("any_peer", "call_remote", "unreliable")
func request_board_draw_point(point: Vector2, eraser: bool) -> void:
	if not multiplayer.is_server():
		return
	if not is_finite(point.x) or not is_finite(point.y):
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var avatar := _remote_avatars.get(sender_id) as Node3D
	var game := get_node_or_null("../GameManager")
	var board := game.get("board_node") as Node3D if game != null else null
	if not is_instance_valid(avatar) or game == null or game.get("board_player") != avatar or String(game.get("phase")) != "BOARD_SOLVING":
		return
	if board == null or avatar.global_position.distance_to(board.global_position) > 5.0:
		return
	var controller := get_node_or_null("../WhiteboardController")
	if controller != null and controller.has_method("network_draw_point"):
		controller.call("network_draw_point", point, eraser)
	_board_draw_point.rpc(point, eraser)


@rpc("any_peer", "call_remote", "reliable")
func request_board_clear() -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var avatar := _remote_avatars.get(sender_id) as Node3D
	var game := get_node_or_null("../GameManager")
	if not is_instance_valid(avatar) or game == null or game.get("board_player") != avatar or String(game.get("phase")) != "BOARD_SOLVING":
		return
	var board := game.get("board_node") as Node3D
	if board == null or avatar.global_position.distance_to(board.global_position) > 5.0:
		return
	var controller := get_node_or_null("../WhiteboardController")
	if controller != null and controller.has_method("network_clear_board"):
		controller.call("network_clear_board")
	_board_clear.rpc()


@rpc("authority", "call_remote", "reliable")
func _board_clear() -> void:
	if multiplayer.is_server():
		return
	var controller := get_node_or_null("../WhiteboardController")
	if controller != null and controller.has_method("network_clear_board"):
		controller.call("network_clear_board")


@rpc("authority", "call_remote", "unreliable")
func _board_draw_point(point: Vector2, eraser: bool) -> void:
	if multiplayer.is_server():
		return
	var controller := get_node_or_null("../WhiteboardController")
	if controller != null and controller.has_method("network_draw_point"):
		controller.call("network_draw_point", point, eraser)


@rpc("authority", "call_remote", "reliable")
func _board_question_started(question: Dictionary) -> void:
	if multiplayer.is_server():
		return
	var controller := get_node_or_null("../WhiteboardController")
	if controller != null and controller.has_method("network_start_board_question"):
		controller.call("network_start_board_question", question)


@rpc("any_peer", "call_remote", "reliable")
func request_board_answer(answer_text: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var avatar := _remote_avatars.get(sender_id) as Node3D
	var game := get_node_or_null("../GameManager")
	if not is_instance_valid(avatar) or game == null or game.get("board_player") != avatar or String(game.get("phase")) != "BOARD_SOLVING":
		return
	var board := game.get("board_node") as Node3D
	if board == null or avatar.global_position.distance_to(board.global_position) > 5.0:
		return
	var correct: bool = bool(game.call("submit_board_answer", avatar, answer_text))
	_board_answer_result.rpc_id(sender_id, correct, answer_text.strip_edges())


@rpc("authority", "call_remote", "reliable")
func _board_answer_result(correct: bool, answer_text: String) -> void:
	if multiplayer.is_server():
		return
	var controller := get_node_or_null("../WhiteboardController")
	if controller != null and controller.has_method("network_board_answer_result"):
		controller.call("network_board_answer_result", correct, answer_text)


@rpc("any_peer", "call_remote", "reliable")
func request_penalty_answer(answer_text: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var game := get_node_or_null("../GameManager")
	var avatar := _remote_avatars.get(sender_id) as Node3D
	if game == null or not is_instance_valid(avatar) or game.get("penalty_player") != avatar or not bool(game.get("_penalty_exam_active")):
		return
	game.call("_submit_exam_answer", answer_text)


@rpc("any_peer", "call_remote", "reliable")
func request_item_pickup(relative_path: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not multiplayer.get_peers().has(sender_id):
		return
	var root := get_tree().current_scene
	var avatar := _remote_avatars.get(sender_id) as CharacterBody3D
	if root == null or not is_instance_valid(avatar):
		return
	var item := root.get_node_or_null(NodePath(relative_path)) as Node3D
	if not is_instance_valid(item) or not item.has_meta("item_type") or not item.has_method("interact"):
		_item_pickup_result.rpc_id(sender_id, relative_path, false)
		return
	if not item.visible or bool(item.get_meta("in_inventory", false)) or bool(item.get_meta("stored_in_rack", false)):
		_item_pickup_result.rpc_id(sender_id, relative_path, false)
		return
	if avatar.global_position.distance_to(item.global_position) > 3.5:
		_item_pickup_result.rpc_id(sender_id, relative_path, false)
		return
	var item_type := String(item.get_meta("item_type", ""))
	var inventory_types: Array = (_peer_inventory_types.get(sender_id, []) as Array).duplicate()
	if item_type.is_empty() or inventory_types.size() >= 2:
		_item_pickup_result.rpc_id(sender_id, relative_path, false)
		return
	var inventory_paths: Array = (_peer_inventory_item_paths.get(sender_id, []) as Array).duplicate()
	if inventory_paths.has(relative_path):
		_item_pickup_result.rpc_id(sender_id, relative_path, false)
		return
	inventory_types.append(item_type)
	inventory_paths.append(relative_path)
	_peer_inventory_types[sender_id] = inventory_types
	_peer_inventory_item_paths[sender_id] = inventory_paths
	item.visible = false
	item.set_meta("in_inventory", true)
	item.set_meta("stored_in_rack", false)
	item.set_meta("spawned_at", 0.0)
	_set_network_item_collision(item, true)
	if item.has_method("on_picked_up"):
		item.call("on_picked_up")
	_item_pickup_result.rpc_id(sender_id, relative_path, true)


@rpc("authority", "call_remote", "reliable")
func _item_pickup_result(relative_path: String, accepted: bool) -> void:
	if multiplayer.is_server() or not accepted:
		return
	var root := get_tree().current_scene
	if root == null or not is_instance_valid(_local_body):
		return
	var item := root.get_node_or_null(NodePath(relative_path)) as Node3D
	var inventory := _local_body.get_node_or_null("ItemInventory")
	if not is_instance_valid(item) or inventory == null or not inventory.has_method("try_pickup"):
		return
	if not bool(inventory.call("try_pickup", item)):
		push_warning("MultiplayerGame: host menyetujui pickup tetapi inventori lokal tidak dapat menerima item.")


@rpc("any_peer", "call_remote", "reliable")
func request_drop_item(relative_path: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not multiplayer.get_peers().has(sender_id):
		return
	var root := get_tree().current_scene
	var avatar := _remote_avatars.get(sender_id) as CharacterBody3D
	if root == null or not is_instance_valid(avatar):
		return
	var item := root.get_node_or_null(NodePath(relative_path)) as Node3D
	if not is_instance_valid(item) or not bool(item.get_meta("in_inventory", false)) or bool(item.get_meta("stored_in_rack", false)):
		_item_drop_result.rpc_id(sender_id, relative_path, false, Vector3.ZERO)
		return
	var item_type := String(item.get_meta("item_type", ""))
	var inventory_types: Array = (_peer_inventory_types.get(sender_id, []) as Array).duplicate()
	var inventory_paths: Array = (_peer_inventory_item_paths.get(sender_id, []) as Array).duplicate()
	if item_type.is_empty() or not inventory_types.has(item_type) or not inventory_paths.has(relative_path):
		_item_drop_result.rpc_id(sender_id, relative_path, false, Vector3.ZERO)
		return
	inventory_types.erase(item_type)
	inventory_paths.erase(relative_path)
	_peer_inventory_types[sender_id] = inventory_types
	_peer_inventory_item_paths[sender_id] = inventory_paths

	# Letakkan barang di permukaan terdekat di depan avatar host, bukan memakai
	# posisi kamera/physics klien yang tidak dapat dipercaya.
	var forward := -avatar.global_transform.basis.z
	var candidate := avatar.global_position + forward * 1.5
	var from := candidate + Vector3.UP * 3.0
	var to := candidate + Vector3.DOWN * 6.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [avatar.get_rid(), item.get_rid()]
	var hit: Dictionary = avatar.get_world_3d().direct_space_state.intersect_ray(query)
	var drop_position := candidate + Vector3.UP * 0.05
	if not hit.is_empty():
		var hit_position: Vector3 = hit.get("position", candidate)
		var lowest_local_y := 0.0
		var host_inventory := _local_body.get_node_or_null("ItemInventory") if is_instance_valid(_local_body) else null
		if host_inventory != null and host_inventory.has_method("_get_lowest_mesh_y_in_root"):
			lowest_local_y = float(host_inventory.call("_get_lowest_mesh_y_in_root", item))
		var surface_offset := float(item.call("get_drop_surface_offset")) if item.has_method("get_drop_surface_offset") else 0.0
		drop_position = Vector3(candidate.x, hit_position.y - lowest_local_y + surface_offset, candidate.z)
	item.global_position = drop_position
	item.visible = true
	item.set_meta("in_inventory", false)
	item.set_meta("stored_in_rack", false)
	item.set_meta("spawned_at", Time.get_ticks_msec() / 1000.0)
	_set_network_item_collision(item, false)
	_item_drop_result.rpc_id(sender_id, relative_path, true, drop_position)


@rpc("authority", "call_remote", "reliable")
func _item_drop_result(relative_path: String, accepted: bool, drop_position: Vector3) -> void:
	if multiplayer.is_server() or not accepted:
		return
	var root := get_tree().current_scene
	if root == null:
		return
	var item := root.get_node_or_null(NodePath(relative_path)) as Node3D
	if not is_instance_valid(item):
		return
	item.global_position = drop_position
	var inventory := _local_body.get_node_or_null("ItemInventory") if is_instance_valid(_local_body) else null
	if inventory != null and inventory.has_method("network_drop_item_reference"):
		inventory.call("network_drop_item_reference", item)
	else:
		item.visible = true
		item.set_meta("in_inventory", false)
		_set_network_item_collision(item, false)


func _set_network_item_collision(node: Node, disabled: bool) -> void:
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0 if disabled else 1
		collision_object.collision_mask = 0 if disabled else 1
		collision_object.input_ray_pickable = not disabled
	if node is CollisionShape3D:
		(node as CollisionShape3D).set_deferred("disabled", disabled)
	for child in node.get_children():
		_set_network_item_collision(child, disabled)


@rpc("any_peer", "call_remote", "reliable")
func request_door_interaction(relative_path: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not multiplayer.get_peers().has(sender_id):
		return
	var root := get_tree().current_scene
	if root == null:
		return
	var target := root.get_node_or_null(NodePath(relative_path))
	if target == null or not target.is_in_group("doors") or not target.has_method("interact"):
		return
	var avatar := _remote_avatars.get(sender_id) as Node3D
	if not is_instance_valid(avatar):
		return
	# Tolak permintaan interaksi yang tidak masuk akal dari posisi pemain.
	if avatar.global_position.distance_to((target as Node3D).global_position) > 6.0:
		return
	# Pintu berkunci membaca ItemInventory pada aktor. Proxy jaringan tidak
	# mempunyai inventori lokal, jadi host memeriksa inventori otoritatif peer.
	var required_item := String(target.get_meta("required_item_type", ""))
	if not required_item.is_empty():
		var peer_items: Array = (_peer_inventory_types.get(sender_id, []) as Array)
		if not peer_items.has(required_item):
			_door_interaction_result.rpc_id(sender_id, false, required_item)
			return
		# Kunci sudah diverifikasi di host; lewati pemeriksaan lokal pintu untuk
		# proxy ini, lalu pulihkan properti pintu supaya state gameplay tetap terkunci.
		target.set("required_item_type", "")
		target.call("interact", avatar)
		target.set("required_item_type", required_item)
		target.set_meta("locked", true)
		target.set_meta("required_item_type", required_item)
	else:
		var progression_locked := bool(target.get_meta("locked", false))
		if progression_locked:
			_door_interaction_result.rpc_id(sender_id, false, "__objective__")
			return
		target.call("interact", avatar)
	_door_interaction_result.rpc_id(sender_id, true, "")


@rpc("authority", "call_remote", "reliable")
func _door_interaction_result(accepted: bool, required_item: String) -> void:
	if multiplayer.is_server() or accepted:
		return
	var message := "Pintu terkunci. Diperlukan: " + required_item
	if required_item == "__objective__":
		message = "Gerbang sekolah masih terkunci. Selesaikan 10 soal terlebih dahulu."
	match required_item:
		"class_key":
			message = "Pintu terkunci. Diperlukan: Kunci Kelas"
		"red_key":
			message = "Pintu terkunci. Diperlukan: Kunci Merah"
		"blue_key":
			message = "Pintu terkunci. Diperlukan: Kunci Biru"
		"yellow_key":
			message = "Pintu terkunci. Diperlukan: Kunci Kuning"
	var mobile_controls := _local_body.get_node_or_null("MobileControls") if is_instance_valid(_local_body) else null
	if mobile_controls != null and mobile_controls.has_method("show_notification"):
		mobile_controls.call("show_notification", message)
		return
	var ui := get_tree().root.find_child("UIManager", true, false)
	if ui != null and ui.has_method("show_notification"):
		ui.call("show_notification", message)


@rpc("any_peer", "call_remote", "reliable")
func request_rack_interaction(relative_path: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not multiplayer.get_peers().has(sender_id):
		return
	var root := get_tree().current_scene
	var avatar := _remote_avatars.get(sender_id) as Node3D
	if root == null or not is_instance_valid(avatar):
		return
	var target := root.get_node_or_null(NodePath(relative_path))
	if not is_instance_valid(target) or not target.is_in_group("map58_rack_storage") or not target.has_method("interact"):
		return
	if avatar.global_position.distance_to((target as Node3D).global_position) > 4.5:
		_rack_interaction_result.rpc_id(sender_id, relative_path, false, false)
		return
	var stored_item: Variant = target.get("_stored_item")
	var rack_is_open := bool(target.get("_door_open"))
	if stored_item != null and is_instance_valid(stored_item):
		if not rack_is_open:
			target.call("interact", avatar)
			_rack_visual_state.rpc(relative_path, bool(target.get("_door_open")), sender_id)
			_rack_interaction_result.rpc_id(sender_id, relative_path, true, bool(target.get("_door_open")))
			return
		var inventory_types: Array = (_peer_inventory_types.get(sender_id, []) as Array).duplicate()
		if inventory_types.size() >= 2:
			_rack_interaction_result.rpc_id(sender_id, relative_path, false, rack_is_open)
			return
		var item_type := String((stored_item as Node3D).get_meta("item_type", "")) if stored_item is Node3D else ""
		var stored_path := String(root.get_path_to(stored_item as Node3D)) if stored_item is Node3D else ""
		if item_type.is_empty() or stored_path.is_empty() or not target.has_method("network_take_stored_item"):
			_rack_interaction_result.rpc_id(sender_id, relative_path, false, rack_is_open)
			return
		var taken_item := target.call("network_take_stored_item") as Node3D
		if taken_item == null:
			_rack_interaction_result.rpc_id(sender_id, relative_path, false, rack_is_open)
			return
		inventory_types.append(item_type)
		_peer_inventory_types[sender_id] = inventory_types
		var inventory_paths: Array = (_peer_inventory_item_paths.get(sender_id, []) as Array).duplicate()
		var taken_item_path := String(root.get_path_to(taken_item))
		if not inventory_paths.has(taken_item_path):
			inventory_paths.append(taken_item_path)
		_peer_inventory_item_paths[sender_id] = inventory_paths
		_rack_item_transfer.rpc(relative_path, stored_path, sender_id, false, item_type)
		_rack_interaction_result.rpc_id(sender_id, relative_path, true, rack_is_open)
		return
	target.call("interact", avatar)
	var is_open := bool(target.get("_door_open"))
	_rack_visual_state.rpc(relative_path, is_open, sender_id)
	_rack_interaction_result.rpc_id(sender_id, relative_path, true, is_open)


@rpc("any_peer", "call_remote", "reliable")
func request_rack_store_item(rack_path: String, item_path: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not multiplayer.get_peers().has(sender_id):
		return
	var root := get_tree().current_scene
	var avatar := _remote_avatars.get(sender_id) as Node3D
	if root == null or not is_instance_valid(avatar):
		return
	var rack := root.get_node_or_null(NodePath(rack_path))
	if not is_instance_valid(rack) or not rack.is_in_group("map58_rack_storage") or not rack.has_method("network_store_item"):
		return
	if avatar.global_position.distance_to((rack as Node3D).global_position) > 4.5 or not bool(rack.get("_door_open")):
		return
	var existing_item: Variant = rack.get("_stored_item")
	if existing_item != null and is_instance_valid(existing_item):
		return
	var item := root.get_node_or_null(NodePath(item_path)) as Node3D
	if not is_instance_valid(item):
		return
	var item_type := String(item.get_meta("item_type", ""))
	var inventory_types: Array = (_peer_inventory_types.get(sender_id, []) as Array).duplicate()
	var inventory_paths: Array = (_peer_inventory_item_paths.get(sender_id, []) as Array).duplicate()
	if item_type.is_empty() or not inventory_types.has(item_type) or not inventory_paths.has(item_path) or not bool(item.get_meta("in_inventory", false)):
		return
	if not bool(rack.call("network_store_item", item)):
		return
	inventory_types.erase(item_type)
	inventory_paths.erase(item_path)
	_peer_inventory_types[sender_id] = inventory_types
	_peer_inventory_item_paths[sender_id] = inventory_paths
	_rack_item_transfer.rpc(rack_path, item_path, sender_id, true, item_type)


func consume_peer_inventory_item(peer_id: int, item_type: String) -> bool:
	# Dipanggil oleh GameManager host saat item ujian benar-benar dikonsumsi.
	if not multiplayer.is_server() or peer_id <= 1 or item_type.is_empty():
		return false
	var inventory_types: Array = (_peer_inventory_types.get(peer_id, []) as Array).duplicate()
	var type_index := inventory_types.find(item_type)
	if type_index < 0:
		return false
	inventory_types.remove_at(type_index)
	var inventory_paths: Array = (_peer_inventory_item_paths.get(peer_id, []) as Array).duplicate()
	var root := get_tree().current_scene
	var removed_path := ""
	if root != null:
		for path_value in inventory_paths:
			var path := String(path_value)
			var item := root.get_node_or_null(NodePath(path)) as Node3D
			if is_instance_valid(item) and String(item.get_meta("item_type", "")) == item_type:
				removed_path = path
				item.set_meta("in_inventory", false)
				item.set_meta("stored_in_rack", false)
				item.set_meta("spawned_at", 0.0)
				_set_network_item_collision(item, true)
				break
	if not removed_path.is_empty():
		inventory_paths.erase(removed_path)
	elif type_index < inventory_paths.size():
		inventory_paths.remove_at(type_index)
	_peer_inventory_types[peer_id] = inventory_types
	_peer_inventory_item_paths[peer_id] = inventory_paths
	var avatar := _remote_avatars.get(peer_id) as Node
	if is_instance_valid(avatar):
		avatar.set_meta("inventory_types", inventory_types.duplicate())
	_peer_inventory_item_consumed.rpc_id(peer_id, item_type, removed_path)
	return true


@rpc("authority", "call_remote", "reliable")
func _peer_inventory_item_consumed(item_type: String, item_path: String) -> void:
	if multiplayer.is_server() or not is_instance_valid(_local_body):
		return
	var inventory := _local_body.get_node_or_null("ItemInventory")
	if inventory == null:
		return
	var root := get_tree().current_scene
	var item := root.get_node_or_null(NodePath(item_path)) as Node3D if root != null and not item_path.is_empty() else null
	if is_instance_valid(item) and inventory.has_method("network_consume_item_reference"):
		if bool(inventory.call("network_consume_item_reference", item)):
			return
	if inventory.has_method("consume_item_type"):
		inventory.call("consume_item_type", item_type)


func broadcast_host_rack_transfer(rack_path: String, item_path: String, store_item: bool, item_type: String) -> void:
	if not bool(get_tree().get_meta("kelas_malam_multiplayer_active", false)) or multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	_rack_item_transfer.rpc(rack_path, item_path, 1, store_item, item_type)


@rpc("authority", "call_remote", "reliable")
func _rack_item_transfer(rack_path: String, item_path: String, source_peer_id: int, store_item: bool, item_type: String) -> void:
	if multiplayer.is_server():
		return
	var root := get_tree().current_scene
	if root == null:
		return
	var rack := root.get_node_or_null(NodePath(rack_path))
	if not is_instance_valid(rack) or not rack.has_method("network_store_item") or not rack.has_method("network_take_stored_item"):
		return
	var local_is_owner := multiplayer.get_unique_id() == source_peer_id
	var inventory := _local_body.get_node_or_null("ItemInventory") if is_instance_valid(_local_body) else null
	if store_item:
		var item := root.get_node_or_null(NodePath(item_path)) as Node3D
		if not is_instance_valid(item):
			return
		if local_is_owner and inventory != null and inventory.has_method("network_remove_item_reference"):
			inventory.call("network_remove_item_reference", item)
		rack.call("network_store_item", item)
	else:
		var item := rack.call("network_take_stored_item") as Node3D
		if item == null:
			return
		if local_is_owner and inventory != null and inventory.has_method("network_receive_item"):
			inventory.call("network_receive_item", item)


@rpc("authority", "call_remote", "reliable")
func _rack_visual_state(relative_path: String, is_open: bool, source_peer_id: int) -> void:
	if multiplayer.is_server() or multiplayer.get_unique_id() == source_peer_id:
		return
	var root := get_tree().current_scene
	if root == null:
		return
	var target := root.get_node_or_null(NodePath(relative_path))
	if is_instance_valid(target) and target.has_method("network_set_door_open"):
		target.call("network_set_door_open", is_open)


@rpc("authority", "call_remote", "reliable")
func _rack_interaction_result(relative_path: String, accepted: bool, is_open: bool) -> void:
	if multiplayer.is_server():
		return
	var root := get_tree().current_scene
	if root == null:
		return
	var target := root.get_node_or_null(NodePath(relative_path))
	if not is_instance_valid(target):
		return
	# Door state is already decided by the host. Never call interact() locally here,
	# because an occupied rack would otherwise retrieve an item a second time.
	if target.has_method("network_set_door_open"):
		target.call("network_set_door_open", is_open)


@rpc("any_peer", "call_remote", "reliable")
func request_hiding_interaction(relative_path: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not multiplayer.get_peers().has(sender_id):
		return
	var root := get_tree().current_scene
	var avatar := _remote_avatars.get(sender_id) as CharacterBody3D
	if root == null or not is_instance_valid(avatar):
		return
	var target := root.get_node_or_null(NodePath(relative_path))
	if not is_instance_valid(target) or not target is Node3D:
		return
	if not target.is_in_group("map58_hiding_spot") and not target.is_in_group("map58_classroom_cupboard"):
		return

	var entering := not bool(avatar.get_meta("is_hidden", false))
	if entering:
		if avatar.global_position.distance_to((target as Node3D).global_position) > 4.5:
			_hiding_interaction_result.rpc_id(sender_id, relative_path, false, true)
			return
		avatar.set_meta("network_saved_transform", avatar.global_transform)
		avatar.set_meta("network_hide_spot_path", relative_path)
		avatar.set_meta("is_hidden", true)
		var hide_position := (target as Node3D).global_position
		if target is Area3D and target.get_parent() is Node3D and target.get_script() != null and String(target.get_script().resource_path).ends_with("Map58CrateHiding.gd"):
			hide_position = (target.get_parent() as Node3D).to_global(Vector3(0.0, 0.12, 0.0))
		elif String(target.get_meta("hide_style", "")) == "under_bed" and target.get_parent() is Node3D:
			hide_position = (target.get_parent() as Node3D).global_position
		elif target.is_in_group("map58_classroom_cupboard"):
			hide_position = (target as Node3D).to_global(Vector3(-0.04, 0.0, 0.0))
		avatar.global_position = hide_position
		avatar.velocity = Vector3.ZERO
		avatar.set_meta("network_hide_visual_path", relative_path)
	else:
		var saved_path := String(avatar.get_meta("network_hide_spot_path", ""))
		if saved_path != relative_path:
			return
		var saved_transform: Variant = avatar.get_meta("network_saved_transform", Transform3D.IDENTITY)
		if saved_transform is Transform3D:
			avatar.global_transform = saved_transform
		avatar.velocity = Vector3.ZERO
		avatar.set_meta("is_hidden", false)
		avatar.set_meta("network_hide_spot_path", "")
		avatar.set_meta("network_hide_visual_path", "")
		_accepted_player_positions[sender_id] = avatar.global_position
		_accepted_player_state_times[sender_id] = Time.get_ticks_msec()

	_remote_targets[sender_id] = {
		"position": avatar.global_position,
		"yaw": avatar.global_rotation.y,
		"crouching": false,
		"horizontal_speed": 0.0,
		"knocked_out": bool(avatar.get_meta("knocked_out", false)),
		"is_hidden": entering
	}
	# Update host visuals locally and tell every other client to animate the same furniture.
	_set_hiding_visual_state(target, entering)
	_hiding_visual_state.rpc(relative_path, entering, sender_id)
	_hiding_interaction_result.rpc_id(sender_id, relative_path, true, entering)


func _set_hiding_visual_state(target: Node, hidden: bool) -> void:
	if target.has_method("network_set_hiding_visual"):
		target.call("network_set_hiding_visual", hidden)


@rpc("authority", "call_remote", "reliable")
func _hiding_visual_state(relative_path: String, hidden: bool, source_peer_id: int) -> void:
	if multiplayer.is_server() or multiplayer.get_unique_id() == source_peer_id:
		return
	var root := get_tree().current_scene
	if root == null:
		return
	var target := root.get_node_or_null(NodePath(relative_path))
	if is_instance_valid(target):
		_last_hiding_visual_states[relative_path] = hidden
		_set_hiding_visual_state(target, hidden)


@rpc("authority", "call_remote", "reliable")
func _hiding_interaction_result(relative_path: String, accepted: bool, entering: bool) -> void:
	if multiplayer.is_server() or not accepted or not is_instance_valid(_local_body):
		return
	var root := get_tree().current_scene
	if root == null:
		return
	var target := root.get_node_or_null(NodePath(relative_path))
	if not is_instance_valid(target) or not target.has_method("toggle_hide"):
		return
	# The server has authorized this exact object and range. Run the local camera,
	# physics and visibility half of the hiding animation on the owning player.
	if bool(_local_body.get_meta("is_hidden", false)) == entering:
		return
	target.call("toggle_hide", _local_body)
	_last_hiding_visual_states[relative_path] = entering


func _on_peer_connected(peer_id: int) -> void:
	_show_toast("Pemain %d bergabung ke permainan" % peer_id)
	_send_local_state()
	_refresh_network_hud()


func _on_peer_disconnected(peer_id: int) -> void:
	var avatar: Node = _remote_avatars.get(peer_id)
	if is_instance_valid(avatar):
		avatar.queue_free()
	_remote_avatars.erase(peer_id)
	_remote_targets.erase(peer_id)
	_accepted_player_positions.erase(peer_id)
	_accepted_player_state_times.erase(peer_id)
	_peer_inventory_types.erase(peer_id)
	_peer_inventory_item_paths.erase(peer_id)
	var communication := get_node_or_null("MultiplayerCommunication")
	if communication != null and communication.has_method("_stop_remote_voice"):
		communication.call("_stop_remote_voice", peer_id)
	_show_toast("Pemain %d meninggalkan permainan" % peer_id)
	_refresh_network_hud()



func _get_penalty_peer_id(game: Node) -> int:
	if game == null or not bool(game.get("_penalty_exam_active")):
		return 0
	var punished: Node = game.get("penalty_player")
	if not is_instance_valid(punished):
		return 0
	return int(punished.get_meta("network_peer_id", 1 if punished == _local_body else 0))


func _get_public_penalty_question(game: Node) -> Dictionary:
	if game == null or not bool(game.get("_penalty_exam_active")):
		return {}
	var question_value: Variant = game.get("current_question")
	if not question_value is Dictionary:
		return {}
	var question: Dictionary = question_value.duplicate(true)
	question.erase("answer")
	return question


const MAX_DOORS_PER_WORLD_RPC := 8


func _send_world_snapshot(target_peer_id: int = 0) -> void:
	# target_peer_id > 0: kirim snapshot PENUH hanya ke peer itu (mengabaikan cache delta).
	# target_peer_id == 0: siaran delta biasa ke semua peer.
	var full_sync := target_peer_id > 0
	var snapshot: Dictionary = _build_world_snapshot()
	var core: Dictionary = {}
	for key in ["game", "teacher", "players"]:
		if snapshot.has(key):
			core[key] = snapshot[key]
	if not core.is_empty():
		_emit_world_snapshot(core, target_peer_id)

	# World objects are mostly static. Send only changed entries; repeating full
	# transforms as reliable RPC 5x per second can saturate the network queue.
	var doors: Dictionary = snapshot.get("doors", {})
	var previous_doors: Dictionary = {}
	if not full_sync:
		previous_doors = _last_sent_world_sections.get("doors", {})
	var changed_doors := _changed_snapshot_entries(doors, previous_doors)
	var door_keys: Array = changed_doors.keys()
	for start_index in range(0, door_keys.size(), MAX_DOORS_PER_WORLD_RPC):
		var door_chunk: Dictionary = {}
		var end_index: int = mini(start_index + MAX_DOORS_PER_WORLD_RPC, door_keys.size())
		for index in range(start_index, end_index):
			var door_key: String = String(door_keys[index])
			door_chunk[door_key] = changed_doors[door_key]
		_emit_world_snapshot({"doors": door_chunk}, target_peer_id)
	if not full_sync:
		_last_sent_world_sections["doors"] = doors.duplicate(true)

	for key in ["items", "racks", "hiding"]:
		var section: Dictionary = snapshot.get(key, {})
		var previous_section: Dictionary = {}
		if not full_sync:
			previous_section = _last_sent_world_sections.get(key, {})
		var changed_section := _changed_snapshot_entries(section, previous_section)
		if not changed_section.is_empty():
			_emit_world_snapshot({key: changed_section}, target_peer_id)
		if not full_sync:
			_last_sent_world_sections[key] = section.duplicate(true)


func _emit_world_snapshot(data: Dictionary, target_peer_id: int) -> void:
	if target_peer_id > 0:
		_rpc_apply_world_snapshot.rpc_id(target_peer_id, data)
	else:
		_rpc_apply_world_snapshot.rpc(data)


# Client memberi tahu host bahwa scene dunianya sudah siap. Tanpa ini, RPC host yang tiba
# sebelum node client ada hilang dan tidak pernah dikirim ulang (snapshot biasa hanya
# memuat entri yang berubah).
func _request_full_world_sync() -> void:
	if multiplayer.is_server() or _world_synced or not _has_active_multiplayer_peer():
		return
	_world_ready_attempts += 1
	# Tunggu sebentar agar semua node scene (pintu, item, rak) selesai _ready.
	await get_tree().create_timer(0.5).timeout
	if _world_synced or not _has_active_multiplayer_peer():
		return
	_client_world_ready.rpc_id(1)
	# Ulangi tiap 2 detik sampai host membalas (maksimal 10 percobaan).
	if _world_ready_attempts < 10:
		await get_tree().create_timer(1.5).timeout
		if not _world_synced:
			_request_full_world_sync()


@rpc("any_peer", "call_remote", "reliable")
func _client_world_ready() -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not multiplayer.get_peers().has(sender_id):
		return
	_send_world_snapshot(sender_id)
	_full_world_sync_done.rpc_id(sender_id)


@rpc("authority", "call_remote", "reliable")
func _full_world_sync_done() -> void:
	if multiplayer.is_server():
		return
	_world_synced = true


func _changed_snapshot_entries(current: Dictionary, previous: Dictionary) -> Dictionary:
	var changed: Dictionary = {}
	for entry_key in current:
		if not previous.has(entry_key) or current[entry_key] != previous[entry_key]:
			changed[entry_key] = current[entry_key]
	return changed

func _build_world_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	var game := get_node_or_null("../GameManager")
	if game != null:
		snapshot["game"] = {
			"phase": String(game.get("phase")),
			"intro_remaining": float(game.get("intro_remaining")),
			"intro_questions": (game.get("intro_questions") as Array).duplicate(true),
			"intro_briefing_remaining": float(game.get("intro_briefing_remaining")),
			"transition_remaining": float(game.get("transition_remaining")),
			"intro_blackout_remaining": float(game.get("intro_blackout_remaining")),
			"intro_blackout_applied": bool(game.get_meta("intro_blackout_applied", false)),
			"intro_departure_active": bool(game.get("intro_departure_active")),
			"intro_camera_tracking_teacher": bool(game.get("_intro_camera_tracking_teacher")),
			"score": int(game.get("score")),
			"solved_papers": int(game.get("solved_papers")),
			"active_paper_count": int(game.get("active_paper_count")),
			"teacher_mode": String(game.get("teacher_mode")),
			"initial_teacher_remaining": float(game.get("initial_teacher_remaining")),
			"calm_remaining": float(game.get("calm_remaining")),
			"berserk_remaining": float(game.get("berserk_remaining")),
			"board_remaining": float(game.get("board_remaining")),
			"game_result": String(game.get("game_result")),
			"penalty_active": bool(game.get("_penalty_exam_active")),
			"penalty_question_index": int(game.get("penalty_question_index")),
			"penalty_peer_id": _get_penalty_peer_id(game),
			"penalty_question": _get_public_penalty_question(game),
		}
	var teacher := get_node_or_null("../Teacher") as Node3D
	if teacher != null:
		snapshot["teacher"] = {
			"position": teacher.global_position,
			"rotation": teacher.global_rotation,
			"velocity": teacher.velocity if teacher is CharacterBody3D else Vector3.ZERO,
			"mode": String(teacher.get_meta("teacher_mode", "TEACHER")),
			"capture_pose": bool(teacher.get_meta("capture_pose", false)),
			"capture_dragging": bool(teacher.get_meta("capture_dragging", false)),
			"animation_state": int(teacher.get("_current_state")) if teacher.get("_current_state") != null else 0,
			"intro_floating": bool((teacher.get_node_or_null("TeacherAnimation") as Node).get("intro_floating")) if teacher.get_node_or_null("TeacherAnimation") != null else false,
			"jump_animation_active": bool((teacher.get_node_or_null("TeacherAnimation") as Node).get("jump_animation_active")) if teacher.get_node_or_null("TeacherAnimation") != null else false,
		}
	var player_states: Dictionary = {}
	var game_phase := String(game.get("phase")) if game != null else ""
	var intro_phase_locked := game_phase in ["INTRO_BRIEFING", "INTRO_EXAM", "TRANSITION"]
	if is_instance_valid(_local_body):
		var local_host_locked := bool(_local_body.get_meta("intro_locked", false)) or intro_phase_locked
		player_states["1"] = {"knocked_out": bool(_local_body.get_meta("knocked_out", false)), "is_hidden": bool(_local_body.get_meta("is_hidden", false)), "host_locked": local_host_locked, "position": _local_body.global_position, "yaw": _local_body.global_rotation.y}
	for peer_value in _remote_avatars.keys():
		var peer_avatar := _remote_avatars[peer_value] as Node3D
		if is_instance_valid(peer_avatar):
			# Intro lock is a host-owned phase property and must reach every peer.
			peer_avatar.set_meta("intro_locked", intro_phase_locked)
			player_states[str(peer_value)] = {"knocked_out": bool(peer_avatar.get_meta("knocked_out", false)), "is_hidden": bool(peer_avatar.get_meta("is_hidden", false)), "host_locked": intro_phase_locked, "position": peer_avatar.global_position, "yaw": peer_avatar.global_rotation.y}
	snapshot["players"] = player_states
	var root := get_tree().current_scene
	if root != null:
		var items: Dictionary = {}
		_collect_item_snapshot(root, root, items)
		snapshot["items"] = items
		var doors: Dictionary = {}
		for door in get_tree().get_nodes_in_group("doors"):
			if not is_instance_valid(door) or not door is Node3D or not root.is_ancestor_of(door):
				continue
			var door_node := door as Node3D
			var door_state: Dictionary = {"position": door_node.global_position, "rotation": door_node.global_rotation}
			if door_node.has_method("is_open"):
				door_state["is_open"] = bool(door_node.call("is_open"))
			if door_node.has_method("is_locked"):
				door_state["locked"] = bool(door_node.call("is_locked"))
			if _node_has_property(door_node, "required_item_type"):
				var required_item_value: Variant = door_node.get("required_item_type")
				if required_item_value != null:
					door_state["required_item_type"] = String(required_item_value)
			var leaves: Dictionary = {}
			_collect_door_transforms(root, door_node, leaves)
			door_state["leaves"] = leaves
			doors[String(root.get_path_to(door_node))] = door_state
		snapshot["doors"] = doors
		var racks: Dictionary = {}
		for rack in get_tree().get_nodes_in_group("map58_rack_storage"):
			if not is_instance_valid(rack) or not rack is Node3D or not root.is_ancestor_of(rack):
				continue
			var rack_item := rack.get("_stored_item") as Node3D
			var rack_item_path := String(rack_item.get_meta("network_original_item_path", "")) if is_instance_valid(rack_item) else ""
			var rack_item_type := String(rack_item.get_meta("item_type", "")) if is_instance_valid(rack_item) else ""
			racks[String(root.get_path_to(rack))] = {"door_open": bool(rack.get("_door_open")), "stored_item_path": rack_item_path, "stored_item_type": rack_item_type}
		snapshot["racks"] = racks
		var hiding_states: Dictionary = {}
		for hiding_target in get_tree().get_nodes_in_group("map58_hiding_spot") + get_tree().get_nodes_in_group("map58_classroom_cupboard"):
			if not is_instance_valid(hiding_target) or not hiding_target is Node3D or not root.is_ancestor_of(hiding_target):
				continue
			var hiding_path := String(root.get_path_to(hiding_target))
			var hidden_here: bool = false
			if is_instance_valid(_local_body) and _local_body.has_meta("hide_spot"):
				hidden_here = _local_body.get_meta("hide_spot") == hiding_target
			for peer_key in _remote_avatars.keys():
				var hiding_avatar := _remote_avatars[peer_key] as Node3D
				if is_instance_valid(hiding_avatar) and String(hiding_avatar.get_meta("network_hide_spot_path", "")) == hiding_path:
					hidden_here = true
					break
			hiding_states[hiding_path] = hidden_here
		snapshot["hiding"] = hiding_states
	return snapshot


func _node_has_property(node: Object, property_name: String) -> bool:
	for property_info in node.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false

func _collect_door_transforms(root: Node, current: Node, result: Dictionary) -> void:
	if current is Node3D:
		var node_3d := current as Node3D
		result[String(root.get_path_to(node_3d))] = {"position": node_3d.global_position, "rotation": node_3d.global_rotation}
	for child in current.get_children():
		_collect_door_transforms(root, child, result)


# Client membuat ulang klon item buatan spawner host (nama dan path sama persis dengan host),
# karena node klon itu tidak ada di scene client dan tanpa ini snapshot melewatinya.
func _create_network_item_clone(root: Node, item_path: String, source_name: String) -> Node3D:
	if source_name.is_empty():
		return null
	var parent := root.get_node_or_null(NodePath(item_path.get_base_dir())) as Node3D
	if parent == null:
		return null
	var source := parent.get_node_or_null(NodePath(source_name)) as Node3D
	if source == null:
		return null
	var clone := source.duplicate() as Node3D
	if clone == null:
		return null
	clone.name = item_path.get_file()
	clone.visible = false
	clone.set_meta("in_inventory", false)
	clone.set_meta("network_clone_of", source_name)
	parent.add_child(clone)
	_set_network_item_collision(clone, true)
	return clone


func _collect_item_snapshot(root: Node, current: Node, result: Dictionary) -> void:
	if current.has_meta("item_type") and current is Node3D:
		var item := current as Node3D
		result[String(root.get_path_to(item))] = {
			"visible": item.visible,
			"position": item.global_position,
			"rotation": item.global_rotation,
			"in_inventory": bool(item.get_meta("in_inventory", false)),
			# Klon item buatan spawner host: client membuat klon yang sama dari item sumber ini.
			"clone_of": String(item.get_meta("network_clone_of", "")),
		}
	for child in current.get_children():
		_collect_item_snapshot(root, child, result)


@rpc("authority", "call_remote", "reliable")
func _rpc_apply_world_snapshot(snapshot: Dictionary) -> void:
	if multiplayer.is_server():
		return
	var game := get_node_or_null("../GameManager")
	if game != null:
		var state: Dictionary = snapshot.get("game", {})
		if not state.is_empty():
			if state.has("intro_camera_tracking_teacher"):
				game.set("_intro_camera_tracking_teacher", bool(state["intro_camera_tracking_teacher"]))
			var new_phase := String(state.get("phase", game.get("phase")))
			if new_phase != String(game.get("phase")) and game.has_method("_set_phase"):
				game.call("_set_phase", new_phase)
			for key in ["intro_remaining", "intro_briefing_remaining", "transition_remaining", "intro_blackout_remaining", "intro_departure_active", "score", "solved_papers", "active_paper_count", "initial_teacher_remaining", "calm_remaining", "berserk_remaining", "board_remaining", "game_result", "penalty_question_index"]:
				if state.has(key):
					game.set(key, state[key])
			if bool(state.get("intro_blackout_applied", false)) and not bool(game.get_meta("intro_blackout_applied", false)):
				if game.has_method("_blackout_nearest_class_lights"):
					game.call("_blackout_nearest_class_lights")
				else:
					game.set_meta("intro_blackout_applied", true)
			var local_peer_id := multiplayer.get_unique_id()
			var was_penalty_active := bool(game.get("_penalty_exam_active"))
			var penalty_active := bool(state.get("penalty_active", false)) and int(state.get("penalty_peer_id", 0)) == local_peer_id
			game.set("_penalty_exam_active", penalty_active)
			game.set("penalty_player", _local_body if penalty_active else null)
			if penalty_active or was_penalty_active:
				_local_body.set_meta("intro_locked", penalty_active)
			var penalty_question: Dictionary = state.get("penalty_question", {})
			if penalty_active and not penalty_question.is_empty():
				game.set("current_question", penalty_question.duplicate(true))
			elif was_penalty_active and not penalty_active:
				game.set("current_question", {})
			var mode := String(state.get("teacher_mode", game.get("teacher_mode")))
			if mode != String(game.get("teacher_mode")) and game.has_method("_set_teacher_mode"):
				game.call("_set_teacher_mode", mode, null)
			if game.has_method("apply_multiplayer_intro_state"):
				game.call("apply_multiplayer_intro_state", state)
			if game.has_method("_update_ui"):
				game.call("_update_ui")
	var teacher_state: Dictionary = snapshot.get("teacher", {})
	var teacher := get_node_or_null("../Teacher") as Node3D
	if teacher != null and not teacher_state.is_empty():
		teacher.global_position = teacher.global_position.lerp(teacher_state.get("position", teacher.global_position), 0.85)
		teacher.global_rotation = teacher.global_rotation.lerp(teacher_state.get("rotation", teacher.global_rotation), 0.85)
		if teacher is CharacterBody3D:
			(teacher as CharacterBody3D).velocity = (teacher as CharacterBody3D).velocity.lerp(teacher_state.get("velocity", Vector3.ZERO), 0.85)
		teacher.set_meta("teacher_mode", String(teacher_state.get("mode", "TEACHER")))
		teacher.set_meta("capture_pose", bool(teacher_state.get("capture_pose", false)))
		teacher.set_meta("capture_dragging", bool(teacher_state.get("capture_dragging", false)))
		if teacher.get("_current_state") != null:
			teacher.set("_current_state", int(teacher_state.get("animation_state", teacher.get("_current_state"))))
		var teacher_animation := teacher.get_node_or_null("TeacherAnimation")
		if teacher_animation != null:
			if teacher_animation.has_method("set_intro_floating"):
				teacher_animation.call("set_intro_floating", bool(teacher_state.get("intro_floating", false)))
			if teacher_animation.get("jump_animation_active") != null:
				teacher_animation.set("jump_animation_active", bool(teacher_state.get("jump_animation_active", false)))
	var root := get_tree().current_scene
	if root == null:
		return
	var player_states: Dictionary = snapshot.get("players", {})
	var local_state: Dictionary = player_states.get(str(multiplayer.get_unique_id()), {})
	if not local_state.is_empty() and is_instance_valid(_local_body):
		var local_knocked_out := bool(local_state.get("knocked_out", false))
		_local_body.set_meta("knocked_out", local_knocked_out)
		# Keep host-controlled intro/penalty locks consistent with the local controller.
		_local_body.set_meta("intro_locked", bool(local_state.get("host_locked", false)) or bool(game.get("_penalty_exam_active")))
		# The local hiding script owns its camera/physics transition after the host's
		# interaction approval; snapshots must not pre-flip this flag before that callback.
		if bool(game.get("_penalty_exam_active")) or local_knocked_out:
			_local_body.global_position = local_state.get("position", _local_body.global_position)
			_local_body.global_rotation.y = float(local_state.get("yaw", _local_body.global_rotation.y))
			_local_body.velocity = Vector3.ZERO
	for peer_value in _remote_avatars.keys():
		var peer_avatar := _remote_avatars[peer_value] as Node3D
		var peer_state: Dictionary = player_states.get(str(peer_value), {})
		if is_instance_valid(peer_avatar) and not peer_state.is_empty():
			peer_avatar.set_meta("knocked_out", bool(peer_state.get("knocked_out", false)))
			peer_avatar.set_meta("is_hidden", bool(peer_state.get("is_hidden", false)))
			peer_avatar.set_meta("intro_locked", bool(peer_state.get("host_locked", false)))
	# Pintu dan daun/collider mengikuti transform host.
	var door_states: Dictionary = snapshot.get("doors", {})
	for door_path in door_states:
		var door := root.get_node_or_null(NodePath(String(door_path)))
		if door == null:
			continue
		var door_state: Dictionary = door_states[door_path]
		if door is Node3D:
			(door as Node3D).global_position = door_state.get("position", (door as Node3D).global_position)
			(door as Node3D).global_rotation = door_state.get("rotation", (door as Node3D).global_rotation)
		if door_state.has("is_open") and door.get("_is_open") != null:
			door.set("_is_open", bool(door_state["is_open"]))
		if door_state.has("required_item_type") and _node_has_property(door, "required_item_type"):
			var synced_required_item := String(door_state["required_item_type"])
			door.set("required_item_type", synced_required_item)
			door.set_meta("required_item_type", synced_required_item)
			door.set_meta("locked", not synced_required_item.is_empty())
		elif door_state.has("locked") and _node_has_property(door, "locked"):
			door.set("locked", bool(door_state["locked"]))
			door.set_meta("locked", bool(door_state["locked"]))
		var leaves: Dictionary = door_state.get("leaves", {})
		for leaf_path in leaves:
			var leaf := root.get_node_or_null(NodePath(String(leaf_path))) as Node3D
			if leaf == null:
				continue
			var leaf_state: Dictionary = leaves[leaf_path]
			leaf.global_position = leaf_state.get("position", leaf.global_position)
			leaf.global_rotation = leaf_state.get("rotation", leaf.global_rotation)
	var rack_states: Dictionary = snapshot.get("racks", {})
	for rack_path in rack_states:
		var rack := root.get_node_or_null(NodePath(String(rack_path)))
		if not is_instance_valid(rack) or not rack.has_method("network_set_door_open"):
			continue
		var rack_state: Dictionary = rack_states[rack_path]
		rack.call("network_set_door_open", bool(rack_state.get("door_open", true)))
		var stored_item_path := String(rack_state.get("stored_item_path", ""))
		var local_stored_item: Variant = rack.get("_stored_item")
		if not stored_item_path.is_empty() and (local_stored_item == null or not is_instance_valid(local_stored_item)):
			var world_item := root.get_node_or_null(NodePath(stored_item_path)) as Node3D
			if is_instance_valid(world_item):
				rack.call("network_store_item", world_item)
	var hiding_states: Dictionary = snapshot.get("hiding", {})
	for hiding_path_value in hiding_states:
		var hiding_path := String(hiding_path_value)
		var hidden_value := bool(hiding_states[hiding_path_value])
		var hiding_target := root.get_node_or_null(NodePath(hiding_path))
		if not is_instance_valid(hiding_target) or not hiding_target.has_method("network_set_hiding_visual"):
			continue
		if not _last_hiding_visual_states.has(hiding_path):
			# Snapshot pertama hanya perlu memulai animasi bila objek benar-benar
			# sedang dipakai; jangan memainkan animasi "keluar" untuk semua objek.
			_last_hiding_visual_states[hiding_path] = hidden_value
			if hidden_value:
				hiding_target.call("network_set_hiding_visual", true)
		elif bool(_last_hiding_visual_states[hiding_path]) != hidden_value:
			_last_hiding_visual_states[hiding_path] = hidden_value
			hiding_target.call("network_set_hiding_visual", hidden_value)
	var item_states: Dictionary = snapshot.get("items", {})
	for path_value in item_states:
		var item := root.get_node_or_null(NodePath(String(path_value))) as Node3D
		var item_state: Dictionary = item_states[path_value]
		if item == null:
			# Klon item buatan host (pengganti kertas/kapur/medkit) belum ada di client.
			item = _create_network_item_clone(root, String(path_value), String(item_state.get("clone_of", "")))
		if item == null:
			continue
		item.global_position = item_state.get("position", item.global_position)
		item.global_rotation = item_state.get("rotation", item.global_rotation)
		item.visible = bool(item_state.get("visible", item.visible))
		item.set_meta("in_inventory", bool(item_state.get("in_inventory", false)))
		# Samakan collision dengan host: item tersembunyi/di inventori tidak bisa diambil, item
		# yang terlihat harus bisa diambil. Termasuk CollisionShape3D yang sebelumnya dimatikan
		# oleh spawner lokal; tanpa itu item yang aktif di host tidak bisa diambil di client.
		_set_network_item_collision(item, not item.visible)

