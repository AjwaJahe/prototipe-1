extends Control
## UI flow multiplayer untuk demo Kelas Malam menggunakan NodeTunnel.
## App ID disimpan di dalam game; pemain hanya perlu memasukkan Room ID saat bergabung.

const GAME_SCENE_PATH := "res://main.tscn"
const NODETUNNEL_RELAY := "us-east.nodetunnel.io:8080"
const NODETUNNEL_APP_ID := "xk997f4zitg8wfq"
const CONNECTION_TIMEOUT_SECONDS := 20.0
const DIRECT_DEFAULT_PORT := 7777
const DIRECT_CHANNEL_COUNT := 2
const MAX_ROOM_PLAYERS := 4
const MODES := ["SD", "SMP", "SMA", "Dasar"]
const DURATIONS := [3, 5, 10, 15]
const ROOM_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var _overlay: ColorRect
var _content: VBoxContainer
var _mode_option: OptionButton
var _duration_option: OptionButton
var _privacy_option: OptionButton
var _capacity_option: OptionButton
var _join_code: LineEdit
var _direct_public_address: LineEdit
var _direct_address: LineEdit
var _transport := "nodetunnel"

var _peer: Object
var _room_id := ""
var _selected_mode := "SD"
var _selected_duration := 5
var _selected_privacy := "Privat"
var _selected_capacity := MAX_ROOM_PLAYERS
var _player_ready := false
var _ready_by_peer: Dictionary = {}
var _notice := ""
var _pending_action := ""
var _pending_room_id := ""
var _connection_pending := false
var _connection_generation := 0
var _is_host := false


func _ready() -> void:
	_build_overlay()
	visible = false
	if not multiplayer.peer_connected.is_connected(_on_player_connected):
		multiplayer.peer_connected.connect(_on_player_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_player_disconnected):
		multiplayer.peer_disconnected.connect(_on_player_disconnected)


func open() -> void:
	visible = true
	_show_home()


func close() -> void:
	visible = false


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "RoomFlowOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.015, 0.015, 0.025, 0.96)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	var viewport_height := get_viewport_rect().size.y
	panel.custom_minimum_size = Vector2(460, minf(560.0, maxf(360.0, viewport_height - 64.0)))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.size_flags_stretch_ratio = 1.0
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.name = "RoomFlowScroll"
	scroll.custom_minimum_size = Vector2(0, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)


func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()


func _add_title(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.86, 0.16, 0.17))
	label.add_theme_font_size_override("font_size", 32)
	_content.add_child(label)


func _add_body(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82))
	_content.add_child(label)


func _add_button(value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(button)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


func _add_back_button() -> void:
	_add_button("KEMBALI", _show_home)


func _show_home() -> void:
	_clear_content()
	_add_title("MAIN BERSAMA")
	_add_button("BUAT PERMAINAN", _show_setup)
	_add_button("GABUNG DENGAN ID", _show_join)
	_add_button("BUAT PERMAINAN LANGSUNG", _show_direct_setup)
	_add_button("GABUNG DENGAN ALAMAT", _show_direct_join)
	_add_button("KEMBALI KE MENU UTAMA", close)


func _show_setup() -> void:
	_clear_content()
	_add_title("PENGATURAN ROOM")

	_add_field_label("Mode permainan")
	_mode_option = OptionButton.new()
	for mode in MODES:
		_mode_option.add_item(_localized(mode))
	_mode_option.select(maxi(0, MODES.find(_selected_mode)))
	_content.add_child(_mode_option)

	_add_field_label("Durasi pengerjaan soal")
	_duration_option = OptionButton.new()
	for duration in DURATIONS:
		_duration_option.add_item(_localized("%d menit" % duration))
		_duration_option.set_item_metadata(_duration_option.item_count - 1, duration)
	_duration_option.select(maxi(0, DURATIONS.find(_selected_duration)))
	_content.add_child(_duration_option)

	_add_field_label("Privasi room")
	_privacy_option = OptionButton.new()
	_privacy_option.add_item(_localized("Privat — hanya dengan ID"))
	_privacy_option.add_item(_localized("Publik — dapat ditemukan"))
	_privacy_option.select(0 if _selected_privacy == "Privat" else 1)
	_content.add_child(_privacy_option)

	_add_field_label("Jumlah pemain maksimum")
	_capacity_option = OptionButton.new()
	for capacity in [2, 3, MAX_ROOM_PLAYERS]:
		_capacity_option.add_item(_localized("%d pemain" % capacity))
		_capacity_option.set_item_metadata(_capacity_option.item_count - 1, capacity)
	var capacity_index := [2, 3, MAX_ROOM_PLAYERS].find(_selected_capacity)
	_capacity_option.select(maxi(0, capacity_index))
	_content.add_child(_capacity_option)

	_add_button("BUAT ROOM", _create_room)
	_add_back_button()


func _localized(value: String) -> String:
	var localization := get_node_or_null("/root/Localization")
	if localization != null and localization.has_method("translate_text"):
		return String(localization.call("translate_text", value))
	return value


func _add_field_label(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 17)
	_content.add_child(label)


func _create_room() -> void:
	_transport = "nodetunnel"
	_selected_mode = MODES[_mode_option.selected]
	_selected_duration = int(_duration_option.get_item_metadata(_duration_option.selected))
	_selected_privacy = "Privat" if _privacy_option.selected == 0 else "Publik"
	_selected_capacity = int(_capacity_option.get_item_metadata(_capacity_option.selected))
	_player_ready = false
	_begin_connection("host", "")


func _show_direct_setup() -> void:
	_transport = "direct"
	_clear_content()
	_add_title("PENGATURAN ROOM LANGSUNG")
	_add_body("Koneksi langsung memakai UDP port 7777. Untuk bermain lintas rumah, buat tunnel UDP di playit.gg.")
	_add_field_label("Mode permainan")
	_mode_option = OptionButton.new()
	for mode in MODES:
		_mode_option.add_item(_localized(mode))
	_mode_option.select(maxi(0, MODES.find(_selected_mode)))
	_content.add_child(_mode_option)
	_add_field_label("Durasi pengerjaan soal")
	_duration_option = OptionButton.new()
	for duration in DURATIONS:
		_duration_option.add_item(_localized("%d menit" % duration))
		_duration_option.set_item_metadata(_duration_option.item_count - 1, duration)
	_duration_option.select(maxi(0, DURATIONS.find(_selected_duration)))
	_content.add_child(_duration_option)
	_add_field_label("Jumlah pemain maksimum")
	_capacity_option = OptionButton.new()
	for capacity in [2, 3, MAX_ROOM_PLAYERS]:
		_capacity_option.add_item(_localized("%d pemain" % capacity))
		_capacity_option.set_item_metadata(_capacity_option.item_count - 1, capacity)
	_capacity_option.select(maxi(0, [2, 3, MAX_ROOM_PLAYERS].find(_selected_capacity)))
	_content.add_child(_capacity_option)
	_add_field_label("Alamat publik (opsional, dari playit.gg)")
	_direct_public_address = LineEdit.new()
	_direct_public_address.placeholder_text = "nama.at.ply.gg:PORT (opsional)"
	_direct_public_address.max_length = 256
	_content.add_child(_direct_public_address)
	_add_body("Jika alamat publik kosong, alamat LAN akan ditampilkan. Izinkan Godot melewati Windows Firewall pada jaringan Private.")
	_add_button("BUAT ROOM LANGSUNG", _create_direct_room)
	_add_back_button()


func _create_direct_room() -> void:
	_transport = "direct"
	_selected_mode = MODES[_mode_option.selected]
	_selected_duration = int(_duration_option.get_item_metadata(_duration_option.selected))
	_selected_privacy = "Publik"
	_selected_capacity = int(_capacity_option.get_item_metadata(_capacity_option.selected))
	var public_address := _direct_public_address.text.strip_edges()
	if public_address.length() > 256:
		_show_connection_error("Alamat publik terlalu panjang.", "direct_host")
		return
	_player_ready = false
	_release_peer()
	_connection_generation += 1
	_connection_pending = true
	_pending_action = "direct_host"
	_ready_by_peer.clear()
	_room_id = ""
	_notice = ""
	_clear_content()
	_add_title("MENYIAPKAN SERVER LANGSUNG")
	_add_body("Membuka UDP port 7777…")
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_server(DIRECT_DEFAULT_PORT, _selected_capacity - 1, DIRECT_CHANNEL_COUNT)
	if err != OK:
		_connection_pending = false
		_show_connection_error("Gagal membuka UDP port %d (kode %d). Pastikan port tidak dipakai aplikasi lain." % [DIRECT_DEFAULT_PORT, err], "direct_host")
		return
	_peer = enet
	multiplayer.multiplayer_peer = enet
	_connection_pending = false
	_is_host = true
	_player_ready = false
	_ready_by_peer = {1: false}
	_room_id = public_address if not public_address.is_empty() else _get_lan_address()
	_pending_action = ""
	_show_lobby()
	_broadcast_lobby_state()


func _get_lan_address() -> String:
	var addresses := IP.get_local_addresses()
	# Utamakan alamat Wi-Fi/router umum agar tidak tanpa sengaja membagikan
	# alamat adapter virtual/VPN sebelum alamat LAN yang bisa dijangkau teman.
	for prefix in ["192.168.", "10."]:
		for address in addresses:
			var candidate := String(address)
			if candidate.begins_with(prefix) and candidate.count(".") == 3:
				return "%s:%d" % [candidate, DIRECT_DEFAULT_PORT]
	for address in addresses:
		var candidate := String(address)
		if not candidate.begins_with("172.") or candidate.count(".") != 3:
			continue
		var octets := candidate.split(".")
		if octets.size() == 4 and octets[1].is_valid_int() and int(octets[1]) >= 16 and int(octets[1]) <= 31:
			return "%s:%d" % [candidate, DIRECT_DEFAULT_PORT]
	return "127.0.0.1:%d" % DIRECT_DEFAULT_PORT


func _show_direct_join() -> void:
	_transport = "direct"
	_clear_content()
	_add_title("GABUNG LANGSUNG")
	_add_body("Masukkan alamat host, misalnya 192.168.1.10:7777 atau nama.at.ply.gg:PORT.")
	_direct_address = LineEdit.new()
	_direct_address.placeholder_text = "alamat:port (port boleh dikosongkan)"
	_direct_address.max_length = 256
	_direct_address.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_direct_address)
	_add_button("GABUNG LANGSUNG", _attempt_direct_join)
	_add_back_button()


func _attempt_direct_join() -> void:
	_transport = "direct"
	var address_text := _direct_address.text.strip_edges()
	if address_text.is_empty() or address_text.length() > 256:
		_show_connection_error("Masukkan alamat host yang valid (maksimum 256 karakter).", "direct_join")
		return
	var host := address_text
	var port := DIRECT_DEFAULT_PORT
	var colon_index := address_text.rfind(":")
	if colon_index >= 0:
		host = address_text.substr(0, colon_index).strip_edges()
		var port_text := address_text.substr(colon_index + 1).strip_edges()
		if host.is_empty() or not port_text.is_valid_int():
			_show_connection_error("Format alamat salah. Gunakan alamat:port, misalnya 127.0.0.1:7777.", "direct_join")
			return
		port = int(port_text)
	if host.is_empty() or port < 1 or port > 65535:
		_show_connection_error("Alamat host atau port tidak valid. Port harus 1–65535.", "direct_join")
		return
	_release_peer()
	_connection_generation += 1
	var generation := _connection_generation
	_ready_by_peer.clear()
	_player_ready = false
	_pending_action = "direct_join"
	_pending_room_id = "%s:%d" % [host, port]
	_connection_pending = true
	_room_id = ""
	_notice = ""
	_clear_content()
	_add_title("MENGHUBUNGKAN LANGSUNG")
	_add_body("Menghubungkan ke %s:%d…" % [host, port])
	_add_button("BATAL", _cancel_connection)
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_client(host, port, DIRECT_CHANNEL_COUNT)
	if err != OK:
		_connection_pending = false
		_show_connection_error("Gagal memulai koneksi langsung (kode %d)." % err, "direct_join")
		return
	_peer = enet
	multiplayer.multiplayer_peer = enet
	if not multiplayer.connected_to_server.is_connected(_on_direct_connected):
		multiplayer.connected_to_server.connect(_on_direct_connected)
	if not multiplayer.connection_failed.is_connected(_on_direct_connection_failed):
		multiplayer.connection_failed.connect(_on_direct_connection_failed)
	get_tree().create_timer(CONNECTION_TIMEOUT_SECONDS).timeout.connect(
		_on_direct_timeout.bind(generation), CONNECT_ONE_SHOT
	)


func _on_direct_connected() -> void:
	if _transport != "direct" or not _connection_pending or _pending_action != "direct_join":
		return
	_connection_pending = false
	_is_host = false
	_pending_action = ""
	_room_id = _pending_room_id
	_player_ready = false
	_show_lobby()


func _on_direct_connection_failed() -> void:
	if _transport == "direct" and _connection_pending and _pending_action == "direct_join":
		_fail_connection("Koneksi langsung gagal. Periksa alamat, port UDP, tunnel playit.gg, dan firewall host.", _connection_generation)


func _on_direct_timeout(generation: int) -> void:
	if generation == _connection_generation and _connection_pending and _pending_action == "direct_join":
		_fail_connection("Waktu koneksi langsung habis. Periksa alamat, port UDP, tunnel playit.gg, dan firewall host.", generation)


func _show_join() -> void:
	_clear_content()
	_add_title("GABUNG ROOM")
	_add_body("Masukkan Room ID yang ditampilkan pada perangkat host. App ID tidak perlu dimasukkan.")
	_join_code = LineEdit.new()
	_join_code.placeholder_text = "Tempel Room ID dari host"
	_join_code.max_length = 256
	_join_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_join_code)
	_add_button("GABUNG ROOM", _attempt_join)
	_add_back_button()


func _attempt_join() -> void:
	var code := _join_code.text.strip_edges()
	if code.is_empty():
		_show_join_error("Masukkan Room ID dari host.")
		return
	if code.length() > 256:
		_show_join_error("Room ID terlalu panjang.")
		return
	_player_ready = false
	_begin_connection("join", code)


func _begin_connection(action: String, code: String) -> void:
	if not ClassDB.class_exists("NodeTunnelPeer"):
		_show_connection_error("Library NodeTunnel belum dimuat. Pastikan addons/nodetunnel sudah ada dan ekstensi berhasil dimuat.", action)
		return

	# Bersihkan peer sesi sebelumnya agar percobaan ulang tidak tertahan oleh peer lama.
	_transport = "nodetunnel"
	_release_peer()
	_connection_generation += 1
	var generation := _connection_generation
	_ready_by_peer.clear()
	_player_ready = false
	_pending_action = action
	_pending_room_id = code
	_connection_pending = true
	_room_id = ""
	_notice = ""

	_clear_content()
	_add_title("MENGHUBUNGKAN")
	_add_body("Menghubungkan ke relay NodeTunnel…\nTunggu hingga room berhasil dibuat atau ditemukan.")
	_add_button("BATAL", _cancel_connection)

	_peer = ClassDB.instantiate("NodeTunnelPeer")
	if _peer == null:
		_fail_connection("NodeTunnelPeer gagal dibuat.", generation)
		return

	_peer.authenticated.connect(_on_authenticated.bind(generation))
	_peer.room_connected.connect(_on_room_connected.bind(generation))
	_peer.error.connect(_on_peer_error.bind(generation))
	_peer.forced_disconnect.connect(_on_forced_disconnect.bind(generation))

	var connect_error: int = _peer.connect_to_relay(NODETUNNEL_RELAY, NODETUNNEL_APP_ID)
	if connect_error != OK:
		_fail_connection("Tidak dapat memulai koneksi relay (kode %d)." % connect_error, generation)
		return

	# MultiplayerAPI perlu mem-poll MultiplayerPeerExtension agar relay mengirim
	# sinyal authenticated/room_connected. Peer dipasang saat koneksi dimulai.
	multiplayer.multiplayer_peer = _peer

	get_tree().create_timer(CONNECTION_TIMEOUT_SECONDS).timeout.connect(
		_on_connection_timeout.bind(generation), CONNECT_ONE_SHOT
	)


func _on_authenticated(generation: int) -> void:
	if generation != _connection_generation or not _connection_pending or _peer == null:
		return

	var request_error: int = OK
	if _pending_action == "host":
		var is_public := _selected_privacy == "Publik"
		var metadata := "Kelas Malam Demo | Mode %s | %d menit" % [_selected_mode, _selected_duration]
		request_error = _peer.host_room(is_public, metadata)
	else:
		request_error = _peer.join_room(_pending_room_id)

	if request_error != OK:
		_fail_connection("Relay menolak permintaan room (kode %d)." % request_error, generation)
		return

	_clear_content()
	_add_title("MENYIAPKAN ROOM")
	_add_body("Autentikasi berhasil. Menunggu relay mengonfirmasi room…")
	_add_button("BATAL", _cancel_connection)


func _on_room_connected(generation: int) -> void:
	if generation != _connection_generation or _peer == null:
		return

	_room_id = str(_peer.room_id)
	if _room_id.is_empty():
		_fail_connection("Relay mengonfirmasi koneksi tetapi Room ID kosong.", generation)
		return

	_connection_pending = false
	_is_host = _pending_action == "host"
	_player_ready = false
	if _is_host:
		_ready_by_peer.clear()
		_ready_by_peer[1] = false
	_show_lobby()
	if _is_host:
		_broadcast_lobby_state()


func _on_peer_error(message: String, generation: int) -> void:
	_fail_connection("NodeTunnel: " + message, generation)


func _on_forced_disconnect(generation: int) -> void:
	_fail_connection("Koneksi ke relay terputus. Buat atau gabung room kembali.", generation)


func _on_connection_timeout(generation: int) -> void:
	if generation != _connection_generation or not _connection_pending:
		return
	_fail_connection("Waktu koneksi habis. Periksa internet lalu coba lagi.", generation)


func _fail_connection(message: String, generation: int) -> void:
	if generation != _connection_generation:
		return
	var retry_action := _pending_action
	_connection_pending = false
	_connection_generation += 1
	_release_peer()
	_show_connection_error(message, retry_action)


func _show_connection_error(message: String, retry_action: String) -> void:
	_clear_content()
	_add_title("KONEKSI GAGAL")
	_add_body(message)
	if retry_action == "host":
		_add_button("COBA BUAT ROOM LAGI", _show_setup)
	elif retry_action == "direct_host":
		_add_button("COBA BUAT ROOM LANGSUNG LAGI", _show_direct_setup)
	elif retry_action == "direct_join":
		_add_button("COBA GABUNG LANGSUNG LAGI", _show_direct_join)
	else:
		_add_button("COBA GABUNG LAGI", _show_join)
	_add_button("KEMBALI KE MULTIPLAYER", _show_home)


func _show_join_error(message: String) -> void:
	_clear_content()
	_add_title("ROOM BELUM TERHUBUNG")
	_add_body(message)
	_add_button("COBA LAGI", _show_join)
	_add_back_button()


func _cancel_connection() -> void:
	_connection_generation += 1
	_connection_pending = false
	_release_peer()
	_show_home()


func _release_peer() -> void:
	# ENet harus ditutup eksplisit agar port host segera bebas untuk percobaan berikutnya.
	if _peer is ENetMultiplayerPeer:
		(_peer as ENetMultiplayerPeer).close()
	# RoomFlow dapat dibuat ulang setelah pergantian scene, sementara MultiplayerAPI
	# mungkin masih memegang peer sesi sebelumnya.
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_peer = null


func _show_lobby() -> void:
	_clear_content()
	_add_title("LOBI ROOM")
	if _transport == "direct":
		if multiplayer.is_server():
			_add_body("Server langsung aktif. Bagikan alamat ini kepada teman.")
		else:
			_add_body("Koneksi langsung berhasil. Alamat ini adalah alamat host.")
	else:
		_add_body("Koneksi NodeTunnel berhasil. Bagikan Room ID ini kepada teman.")
	var code := Label.new()
	code.text = _room_id
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code.add_theme_font_size_override("font_size", 30)
	code.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	code.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	_content.add_child(code)
	_add_button("SALIN ALAMAT" if _transport == "direct" else "SALIN ID ROOM", _copy_room_id)

	var player_count := maxi(1, _ready_by_peer.size())
	_add_body("Status: tersambung ke room\nPemain terdeteksi: %d" % player_count)
	if _transport == "direct":
		_add_body("Mode: %s\nDurasi soal: %d menit\nBatas pemain: %d" % [_selected_mode, _selected_duration, _selected_capacity])
	else:
		_add_body("Mode: %s\nDurasi soal: %d menit\nPrivasi: %s\nBatas pemain: %d" % [_selected_mode, _selected_duration, _selected_privacy, _selected_capacity])
	_add_field_label("STATUS PEMAIN")
	var peer_ids: Array[int] = [1]
	for peer_id in multiplayer.get_peers():
		var id := int(peer_id)
		if not peer_ids.has(id):
			peer_ids.append(id)
	# Relay dapat hanya menampilkan host di daftar koneksi klien; gunakan snapshot ready dari host juga.
	for ready_peer_id in _ready_by_peer.keys():
		var ready_id := int(ready_peer_id)
		if ready_id > 0 and not peer_ids.has(ready_id):
			peer_ids.append(ready_id)
	peer_ids.sort()
	var ready_lines: Array[String] = []
	for peer_id in peer_ids:
		var role := "Host" if peer_id == 1 else "Pemain %d" % (peer_ids.find(peer_id) + 1)
		var ready_text := "SIAP" if bool(_ready_by_peer.get(peer_id, false)) else "BELUM SIAP"
		if peer_id == multiplayer.get_unique_id():
			role += " (Kamu)"
		ready_lines.append("%s — %s" % [role, ready_text])
	_add_body("\n".join(ready_lines))
	# Tombol ini hanya mengubah status pemain pada perangkat ini.
	_add_button("BATAL SIAP" if _player_ready else "SAYA SIAP", _toggle_ready)
	if not _notice.is_empty():
		_add_body(_notice)
		_notice = ""
	if multiplayer.is_server():
		var all_ready := _all_connected_players_ready()
		_add_body("Semua pemain harus siap. %s" % ("Semua sudah siap." if all_ready else "Masih menunggu pemain siap."))
		var start_button := _add_button("MULAI PERMAINAN UNTUK SEMUA", _start_game)
		start_button.disabled = not all_ready
	else:
		_add_body("Menunggu host memulai permainan setelah semua pemain siap.")
	_add_button("KELUAR DARI ROOM", _leave_room)


func _copy_room_id() -> void:
	DisplayServer.clipboard_set(_room_id)
	_notice = "Alamat host disalin ke clipboard." if _transport == "direct" else "Room ID disalin ke clipboard."
	_show_lobby()


func _toggle_ready() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	var requested_ready := not _player_ready
	if multiplayer.is_server():
		# Host hanya mengubah entri statusnya sendiri.
		_player_ready = requested_ready
		_ready_by_peer[1] = requested_ready
		_broadcast_lobby_state()
	else:
		# Snapshot status dimiliki server; klien hanya mengirim permintaan.
		_rpc_ready_changed.rpc_id(1, requested_ready)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_ready_changed(ready_value: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not multiplayer.get_peers().has(sender_id):
		return
	_ready_by_peer[sender_id] = ready_value
	_broadcast_lobby_state()


@rpc("authority", "call_local", "reliable")
func _rpc_lobby_state(ready_snapshot: Dictionary, settings: Dictionary) -> void:
	_ready_by_peer = ready_snapshot.duplicate(true)
	if not _is_host:
		_selected_mode = String(settings.get("mode", _selected_mode))
		_selected_duration = int(settings.get("duration", _selected_duration))
		_selected_privacy = String(settings.get("privacy", _selected_privacy))
		_selected_capacity = mini(MAX_ROOM_PLAYERS, maxi(1, int(settings.get("capacity", MAX_ROOM_PLAYERS))))
	_player_ready = bool(_ready_by_peer.get(multiplayer.get_unique_id(), false))
	if visible and not _room_id.is_empty():
		_show_lobby()


func _broadcast_lobby_state() -> void:
	if not multiplayer.is_server() or multiplayer.multiplayer_peer == null:
		return
	var settings := {
		"mode": _selected_mode,
		"duration": _selected_duration,
		"privacy": _selected_privacy,
		"capacity": _selected_capacity,
	}
	_rpc_lobby_state.rpc(_ready_by_peer.duplicate(true), settings)


func _all_connected_players_ready() -> bool:
	if multiplayer.multiplayer_peer == null:
		return false
	var peers := multiplayer.get_peers()
	if peers.size() + 1 > _selected_capacity:
		return false
	if not bool(_ready_by_peer.get(1, false)):
		return false
	for peer_id in peers:
		if not bool(_ready_by_peer.get(int(peer_id), false)):
			return false
	return true


func _on_player_connected(peer_id: int) -> void:
	if multiplayer.is_server() and not _room_id.is_empty():
		var peer := multiplayer.multiplayer_peer
		if multiplayer.get_peers().size() + 1 > _selected_capacity:
			if peer != null and peer.has_method("disconnect_peer"):
				peer.call("disconnect_peer", peer_id, true)
			_notice = "Pemain %d ditolak karena batas room (%d) sudah penuh." % [peer_id, _selected_capacity]
			_broadcast_lobby_state()
			return
		_ready_by_peer[peer_id] = false
		_broadcast_lobby_state()
	elif not multiplayer.is_server():
		# Beri host waktu memperbarui snapshot setelah sinyal peer_connected.
		pass
	if visible and not _room_id.is_empty():
		_show_lobby()


func _on_player_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		_ready_by_peer.erase(peer_id)
		_broadcast_lobby_state()
	if visible and not _room_id.is_empty():
		_show_lobby()


func _leave_room() -> void:
	_connection_generation += 1
	_connection_pending = false
	_release_peer()
	_room_id = ""
	_pending_action = ""
	_pending_room_id = ""
	_player_ready = false
	_ready_by_peer.clear()
	_show_home()


func _start_game() -> void:
	if _room_id.is_empty() or multiplayer.multiplayer_peer == null:
		_show_connection_error("Belum ada koneksi room aktif. Buat atau gabung room terlebih dahulu.", "host" if _is_host else "join")
		return
	if not multiplayer.is_server():
		_notice = "Hanya host yang dapat memulai permainan."
		_show_lobby()
		return
	if multiplayer.get_peers().size() + 1 > _selected_capacity:
		_notice = "Room melebihi batas %d pemain. Keluarkan pemain tambahan sebelum mulai." % _selected_capacity
		_show_lobby()
		return
	if not _all_connected_players_ready():
		_notice = "Semua pemain, termasuk host, harus menekan SIAP terlebih dahulu."
		_show_lobby()
		return
	if not is_instance_valid(get_node_or_null("/root/MultiplayerSession")):
		_show_connection_error("Pengelola multiplayer belum dimuat. Periksa Autoload MultiplayerSession.", "host")
		return
	_add_body("Mengirim perintah mulai ke semua pemain…")
	get_node("/root/MultiplayerSession").request_start_game(_selected_mode, _selected_duration, _selected_privacy, _selected_capacity)
