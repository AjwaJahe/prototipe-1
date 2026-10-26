extends Node
## Singleton yang bertahan saat scene berubah agar RPC mulai tetap punya NodePath yang sama.

const GAME_SCENE_PATH := "res://main.tscn"
var _start_request_pending := false


func request_start_game(mode: String, duration: int, privacy: String, capacity: int) -> void:
	if multiplayer.multiplayer_peer == null:
		push_warning("MultiplayerSession: tidak ada peer multiplayer aktif.")
		return
	if not multiplayer.is_server():
		push_warning("MultiplayerSession: hanya host/server yang boleh memulai.")
		return
	if _start_request_pending:
		return
	_start_request_pending = true
	print("[MultiplayerSession] Host mengirim perintah mulai ke room.")
	_rpc_start_game.rpc(mode, duration, privacy, capacity)


func request_restart_game() -> void:
	if multiplayer.multiplayer_peer == null:
		get_tree().reload_current_scene()
		return
	if multiplayer.is_server():
		_rpc_restart_game.rpc()
	else:
		_rpc_request_restart.rpc_id(1)


func request_return_to_menu() -> void:
	# Keluar adalah aksi lokal. Klien tidak meminta host memindahkan seluruh room.
	_start_request_pending = false
	get_tree().set_meta("kelas_malam_multiplayer_active", false)
	get_tree().set_meta("kelas_malam_is_host", false)
	await get_tree().process_frame
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	var err := get_tree().change_scene_to_file("res://MainMenu.tscn")
	if err != OK:
		push_error("MultiplayerSession: gagal kembali ke menu utama (kode %d)." % err)


@rpc("authority", "call_local", "reliable")
func _rpc_start_game(mode: String, duration: int, privacy: String, capacity: int) -> void:
	if multiplayer.multiplayer_peer == null:
		push_warning("MultiplayerSession: perintah mulai diterima tanpa peer aktif.")
		return
	var active_room_id := ""
	if multiplayer.multiplayer_peer.has_method("get_room_id"):
		active_room_id = str(multiplayer.multiplayer_peer.call("get_room_id"))
	get_tree().set_meta("kelas_malam_room_id", active_room_id)
	get_tree().set_meta("kelas_malam_mode", mode)
	get_tree().set_meta("kelas_malam_duration_minutes", duration)
	get_tree().set_meta("kelas_malam_room_privacy", privacy)
	get_tree().set_meta("kelas_malam_room_capacity", capacity)
	get_tree().set_meta("kelas_malam_multiplayer_active", true)
	get_tree().set_meta("kelas_malam_is_host", multiplayer.is_server())
	print("[MultiplayerSession] Perintah mulai diterima; memuat scene permainan.")
	# Beri MultiplayerAPI satu frame untuk mem-poll/mengirim RPC sebelum scene menu hilang.
	await get_tree().process_frame
	var err := get_tree().change_scene_to_file(GAME_SCENE_PATH)
	_start_request_pending = false
	if err != OK:
		push_error("MultiplayerSession: gagal memuat scene permainan (kode %d)." % err)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_restart() -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not multiplayer.get_peers().has(sender_id):
		return
	_rpc_restart_game.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_restart_game() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	_start_request_pending = false
	await get_tree().process_frame
	var err := get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if err != OK:
		push_error("MultiplayerSession: gagal memulai ulang permainan (kode %d)." % err)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_return_to_menu() -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not multiplayer.get_peers().has(sender_id):
		return
	_rpc_return_to_menu.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_return_to_menu() -> void:
	_start_request_pending = false
	get_tree().set_meta("kelas_malam_multiplayer_active", false)
	get_tree().set_meta("kelas_malam_is_host", false)
	await get_tree().process_frame
	multiplayer.multiplayer_peer = null
	var err := get_tree().change_scene_to_file("res://MainMenu.tscn")
	if err != OK:
		push_error("MultiplayerSession: gagal kembali ke menu utama (kode %d)." % err)
