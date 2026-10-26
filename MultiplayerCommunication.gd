extends Node
## Chat teks dan voice chat untuk sesi multiplayer aktif.
const CHAT_MAX_CHARS := 160
# Suara dikirim mono 16-bit PCM pada 16 kHz: 20 ms = 320 sampel = 640 byte per paket
# (sebelumnya stereo float 4 KB per paket sehingga terfragmentasi dan banyak yang hilang).
const VOICE_SAMPLE_RATE := 16000
const VOICE_PACKET_FRAMES := 320
const VOICE_JITTER_FRAMES := 960
const VOICE_PLAYBACK_BUFFER_SEC := 0.5
const VOICE_MAX_LATENCY_SEC := 0.4
# Cadangan saja. Jarak dengar suara selalu mengikuti hearing_distance guru (lihat _get_voice_range).
const VOICE_HEARING_RANGE := 8.0
const VOICE_UNIT_RATIO := 0.4              # unit_size = jarak dengar x rasio ini
const VOICE_SOURCE_HEIGHT := 1.4          # suara keluar dari kepala, bukan dari titik kaki
const VOICE_OCCLUSION_INTERVAL_MSEC := 100
const VOICE_OCCLUSION_MAX_WALLS := 3
const VOICE_OCCLUDED_MAX_DB := -9.0       # peredaman maksimum di balik dinding (bukan hening)
const VOICE_OCCLUDED_CUTOFF_HZ := 1400.0  # suara di balik dinding jadi teredam

var _chat_panel: PanelContainer
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _voice_capture: AudioEffectCapture
var _mic_player: AudioStreamPlayer
var _voice_enabled := false
var _voice_playbacks: Dictionary = {}
var _rs_in := PackedFloat32Array()
var _rs_pos := 0.0
var _voice_out := PackedFloat32Array()


func _ready() -> void:
	if not bool(get_tree().get_meta("kelas_malam_multiplayer_active", false)):
		set_process(false)
		return
	_build_chat_ui()
	_setup_voice_audio()


func _unhandled_input(event: InputEvent) -> void:
	# Shortcut L/M/N adalah jalur desktop; tombol HUD menangani aksi pada mode HP.
	var player_node := get_tree().get_first_node_in_group("players")
	var mobile_controls := player_node.get_node_or_null("MobileControls") if player_node != null else null
	# Saat MobileControls aktif, shortcut L/M/N dimiliki satu tempat itu saja.
	# Jalur ini hanya fallback bila MultiplayerCommunication dipakai tanpa HUD pemain.
	if mobile_controls != null:
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	# Jangan mengambil tombol huruf saat pemain sedang mengetik pesan.
	if _chat_input != null and _chat_input.has_focus():
		return
	match key_event.keycode:
		KEY_L:
			toggle_chat()
			get_viewport().set_input_as_handled()
		KEY_M:
			if set_voice_enabled(not _voice_enabled):
				get_viewport().set_input_as_handled()
		KEY_N:
			var bus_index := AudioServer.get_bus_index("VoicePlayback")
			if bus_index >= 0:
				AudioServer.set_bus_mute(bus_index, not AudioServer.is_bus_mute(bus_index))
				get_viewport().set_input_as_handled()


func _build_chat_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "CommunicationHUD"
	canvas.layer = 45
	add_child(canvas)

	_chat_panel = PanelContainer.new()
	_chat_panel.name = "MultiplayerChatPanel"
	_chat_panel.set_anchors_preset(Control.PRESET_CENTER)
	_chat_panel.offset_left = -230.0
	_chat_panel.offset_top = -190.0
	_chat_panel.offset_right = 230.0
	_chat_panel.offset_bottom = 190.0
	_chat_panel.custom_minimum_size = Vector2(460.0, 380.0)
	_chat_panel.visible = false
	_chat_panel.add_theme_stylebox_override("panel", _panel_style())
	canvas.add_child(_chat_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	_chat_panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "CHAT PEMAIN"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "TUTUP"
	close_button.pressed.connect(func(): _set_chat_open(false))
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.name = "ChatScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	_chat_log = RichTextLabel.new()
	_chat_log.name = "ChatMessages"
	_chat_log.bbcode_enabled = false
	_chat_log.fit_content = true
	_chat_log.scroll_active = false
	_chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_log.custom_minimum_size = Vector2(400.0, 260.0)
	_chat_log.text = "Chat aktif untuk pemain dalam sesi ini.\n"
	scroll.add_child(_chat_log)

	var composer := HBoxContainer.new()
	layout.add_child(composer)
	_chat_input = LineEdit.new()
	_chat_input.name = "ChatInput"
	_chat_input.placeholder_text = "Tulis pesan (maks. 160 karakter)..."
	_chat_input.max_length = CHAT_MAX_CHARS
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.text_submitted.connect(_submit_chat_text)
	composer.add_child(_chat_input)
	var send_button := Button.new()
	send_button.text = "KIRIM"
	send_button.pressed.connect(func(): _submit_chat_text(_chat_input.text))
	composer.add_child(send_button)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.05, 0.96)
	style.border_color = Color(0.35, 0.58, 0.68, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func toggle_chat() -> void:
	if _chat_panel == null:
		return
	_set_chat_open(not _chat_panel.visible)


func _set_chat_open(open: bool) -> void:
	if _chat_panel == null:
		return
	_chat_panel.visible = open
	get_tree().set_meta("kelas_malam_chat_open", open)
	# Saat chat dibuka, lepaskan mouse dan hentikan kontrol gameplay.
	var players := get_tree().get_nodes_in_group("players")
	for player in players:
		if is_instance_valid(player):
			player.set_meta("communication_ui_open", open)
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if _chat_input != null:
			_chat_input.release_focus()
	else:
		if _chat_input != null:
			_chat_input.release_focus()
		# Kembali ke kontrol FPS desktop hanya jika tidak ada UI lain yang sedang terbuka.
		var pause_overlay := get_tree().root.find_child("PauseMenuOverlay", true, false) as Control
		if pause_overlay == null or not pause_overlay.visible:
			if not OS.has_feature("web_android") and not OS.has_feature("web_ios") and not DisplayServer.is_touchscreen_available():
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _submit_chat_text(raw_text: String) -> void:
	var message := raw_text.strip_edges()
	if message.is_empty() or multiplayer.multiplayer_peer == null:
		return
	message = message.substr(0, CHAT_MAX_CHARS)
	_chat_input.clear()
	if multiplayer.is_server():
		_broadcast_chat(multiplayer.get_unique_id(), message)
	else:
		_chat_request.rpc_id(1, message)


@rpc("any_peer", "call_remote", "reliable")
func _chat_request(message: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not multiplayer.get_peers().has(sender_id):
		return
	var clean_message := message.strip_edges().substr(0, CHAT_MAX_CHARS)
	if clean_message.is_empty():
		return
	_broadcast_chat(sender_id, clean_message)


func _broadcast_chat(sender_id: int, message: String) -> void:
	var sender_name := "Pemain %d" % sender_id
	if sender_id == multiplayer.get_unique_id():
		var local_name := String(get_tree().get_meta("kelas_malam_player_name", "")).strip_edges()
		if not local_name.is_empty():
			sender_name = local_name
	_chat_message.rpc(sender_id, sender_name, message)
	_append_chat_line(sender_name, message)


@rpc("authority", "call_remote", "reliable")
func _chat_message(sender_id: int, sender_name: String, message: String) -> void:
	if sender_id <= 0:
		return
	_append_chat_line(sender_name, message.substr(0, CHAT_MAX_CHARS))


func _append_chat_line(sender_name: String, message: String) -> void:
	if _chat_log == null or not is_instance_valid(_chat_log):
		return
	var safe_message := message.replace("\r", " ").replace("\n", " ")
	_chat_log.append_text("%s: %s\n" % [sender_name, safe_message])
	call_deferred("_scroll_chat_to_bottom")


func _scroll_chat_to_bottom() -> void:
	if _chat_panel == null or _chat_log == null:
		return
	var scroll := _chat_panel.find_child("ChatScroll", true, false) as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = int(_chat_log.get_content_height())


func _ensure_audio_bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	return index


func _setup_voice_audio() -> void:
	var capture_bus := _ensure_audio_bus("VoiceCapture")
	_ensure_audio_bus("VoicePlayback")
	_voice_capture = null
	for effect_index in range(AudioServer.get_bus_effect_count(capture_bus)):
		var existing_effect := AudioServer.get_bus_effect(capture_bus, effect_index)
		if existing_effect is AudioEffectCapture:
			_voice_capture = existing_effect as AudioEffectCapture
			break
	if _voice_capture == null:
		_voice_capture = AudioEffectCapture.new()
		_voice_capture.buffer_length = 0.25
		AudioServer.add_bus_effect(capture_bus, _voice_capture)
	AudioServer.set_bus_mute(capture_bus, true)
	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = "VoiceMicrophoneInput"
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = "VoiceCapture"
	add_child(_mic_player)


func set_voice_enabled(enabled: bool) -> bool:
	# Pastikan izin diminta sebelum memeriksa koneksi multiplayer atau perangkat capture.
	if enabled and OS.get_name() == "Android" and not OS.get_granted_permissions().has("android.permission.RECORD_AUDIO"):
		OS.request_permission("android.permission.RECORD_AUDIO")
		return false
	if multiplayer.multiplayer_peer == null or _mic_player == null or _voice_capture == null:
		return false
	if enabled:
		_voice_capture.clear_buffer()
		_reset_voice_pipeline()
		_mic_player.play()
		_voice_enabled = true
	else:
		_voice_enabled = false
		_mic_player.stop()
		_voice_capture.clear_buffer()
		_reset_voice_pipeline()
	return true


func set_remote_voice_muted(muted: bool) -> void:
	var bus_index := AudioServer.get_bus_index("VoicePlayback")
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, muted)


func _reset_voice_pipeline() -> void:
	_rs_in = PackedFloat32Array()
	_rs_pos = 0.0
	_voice_out = PackedFloat32Array()


func _process(_delta: float) -> void:
	if not _voice_enabled or _voice_capture == null or multiplayer.multiplayer_peer == null:
		return
	# Ambil SEMUA frame yang tersedia setiap frame. Sebelumnya hanya satu paket tiap
	# ~33 ms padahal mic menghasilkan satu paket tiap ~21 ms, sehingga buffer meluap
	# dan suara putus-putus.
	var available := _voice_capture.get_frames_available()
	if available > 0:
		_resample_to_voice_rate(_voice_capture.get_buffer(available), AudioServer.get_mix_rate())
	while _voice_out.size() >= VOICE_PACKET_FRAMES:
		var chunk := _voice_out.slice(0, VOICE_PACKET_FRAMES)
		_voice_out = _voice_out.slice(VOICE_PACKET_FRAMES)
		_send_voice_chunk(chunk)


# Mengubah frame mic (stereo, pada mix rate perangkat) menjadi mono 16 kHz.
# Laju sebenarnya dibaca dari AudioServer (44,1/48 kHz tergantung perangkat); dulu
# dianggap selalu 48 kHz sehingga nada dan kecepatan suara meleset. Rata-rata
# jendela dipakai sebagai filter sederhana agar tidak terjadi aliasing (suara pecah).
func _resample_to_voice_rate(frames: PackedVector2Array, mix_rate: float) -> void:
	if frames.is_empty() or mix_rate <= 0.0:
		return
	var ratio := mix_rate / float(VOICE_SAMPLE_RATE)
	var old_size := _rs_in.size()
	_rs_in.resize(old_size + frames.size())
	for i in range(frames.size()):
		_rs_in[old_size + i] = (frames[i].x + frames[i].y) * 0.5
	var count := _rs_in.size()
	var pos := _rs_pos
	var out := PackedFloat32Array()
	while pos + ratio <= float(count):
		var end := pos + ratio
		var total := 0.0
		for i in range(int(floor(pos)), mini(int(ceil(end)), count)):
			total += _rs_in[i] * (minf(end, float(i + 1)) - maxf(pos, float(i)))
		out.append(total / ratio)
		pos = end
	var drop := mini(int(floor(pos)), count)
	if drop > 0:
		_rs_in = _rs_in.slice(drop)
		pos -= float(drop)
	_rs_pos = pos
	_voice_out.append_array(out)


func _encode_pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	return bytes


func _decode_pcm16(bytes: PackedByteArray) -> PackedVector2Array:
	var frames := PackedVector2Array()
	var count := bytes.size() / 2
	frames.resize(count)
	for i in range(count):
		var s := float(bytes.decode_s16(i * 2)) / 32768.0
		frames[i] = Vector2(s, s)
	return frames


func _send_voice_chunk(chunk: PackedFloat32Array) -> void:
	var pcm := _encode_pcm16(chunk)
	var voice_position := _get_local_voice_position()
	if multiplayer.is_server():
		_notify_teacher_voice(multiplayer.get_unique_id(), voice_position, _decode_pcm16(pcm))
		_relay_voice(multiplayer.get_unique_id(), pcm, voice_position)
	else:
		_voice_packet.rpc_id(1, pcm, voice_position)


# Host meneruskan suara ke pemain lain saja, bukan ke pengirimnya sendiri.
func _relay_voice(sender_id: int, pcm: PackedByteArray, voice_position: Vector3) -> void:
	for peer_id in multiplayer.get_peers():
		if peer_id != sender_id:
			_voice_relay.rpc_id(peer_id, sender_id, pcm, voice_position)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _voice_packet(pcm: PackedByteArray, voice_position: Vector3) -> void:
	if not multiplayer.is_server() or pcm.is_empty() or pcm.size() % 2 != 0 or pcm.size() > VOICE_PACKET_FRAMES * 4:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or not multiplayer.get_peers().has(sender_id):
		return
	# Posisi harus dekat dengan avatar terakhir yang diketahui host agar klien
	# tidak dapat memancing guru dari koordinat sembarang lewat paket voice.
	var avatar := get_parent().get_node_or_null("RemotePlayer_%d" % sender_id) as Node3D
	if avatar != null and is_instance_valid(avatar) and avatar.global_position.distance_to(voice_position) > 5.0:
		voice_position = avatar.global_position
	var samples := _decode_pcm16(pcm)
	_play_remote_voice(sender_id, samples, voice_position)
	_notify_teacher_voice(sender_id, voice_position, samples)
	_relay_voice(sender_id, pcm, voice_position)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _voice_relay(sender_id: int, pcm: PackedByteArray, voice_position: Vector3) -> void:
	if sender_id <= 0 or sender_id == multiplayer.get_unique_id() or pcm.is_empty() or pcm.size() % 2 != 0 or pcm.size() > VOICE_PACKET_FRAMES * 4:
		return
	_play_remote_voice(sender_id, _decode_pcm16(pcm), voice_position)

func _get_local_voice_position() -> Vector3:
	var local_body := get_node_or_null("../../Player/CharacterBody3D") as Node3D
	if local_body == null:
		local_body = get_tree().get_first_node_in_group("players") as Node3D
	return local_body.global_position if local_body != null else Vector3.ZERO


func _notify_teacher_voice(peer_id: int, voice_position: Vector3, samples: PackedVector2Array) -> void:
	if not multiplayer.is_server():
		return
	var energy := 0.0
	for sample in samples:
		energy += sample.length_squared()
	energy = sqrt(energy / maxf(1.0, float(samples.size())))
	if energy < 0.012:
		return
	var teacher := get_tree().get_first_node_in_group("teacher")
	if teacher == null or not is_instance_valid(teacher) or not teacher.has_method("hear_multiplayer_voice"):
		return
	if teacher is Node3D and (teacher as Node3D).global_position.distance_to(voice_position) <= _get_voice_range():
		teacher.call("hear_multiplayer_voice", voice_position, peer_id, clampf(energy * 18.0, 0.15, 1.0))


func _play_remote_voice(peer_id: int, samples: PackedVector2Array, voice_position: Vector3) -> void:
	if samples.is_empty() or peer_id == multiplayer.get_unique_id():
		return
	var entry: Dictionary = _voice_playbacks.get(peer_id, {})
	var player := entry.get("player") as AudioStreamPlayer3D
	var playback := entry.get("playback") as AudioStreamGeneratorPlayback
	if not is_instance_valid(player) or playback == null:
		var generator := AudioStreamGenerator.new()
		generator.mix_rate = VOICE_SAMPLE_RATE
		generator.buffer_length = VOICE_PLAYBACK_BUFFER_SEC
		player = AudioStreamPlayer3D.new()
		player.name = "VoicePeer_%d" % peer_id
		player.stream = generator
		player.bus = "VoicePlayback"
		player.max_distance = _get_voice_range()
		player.unit_size = _get_voice_range() * VOICE_UNIT_RATIO
		# Filter bawaan 5 kHz membuat konsonan tumpul; peredaman dinding diatur sendiri.
		player.attenuation_filter_cutoff_hz = 20500.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.panning_strength = 1.0
		add_child(player)
		player.play()
		playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
		entry = {"player": player, "playback": playback, "last_msec": 0, "occlusion": 0.0, "occ_msec": 0}
		_voice_playbacks[peer_id] = entry
	_update_voice_spatial(player, entry, voice_position + Vector3(0.0, VOICE_SOURCE_HEIGHT, 0.0))
	if playback == null:
		return
	var capacity := int(VOICE_SAMPLE_RATE * VOICE_PLAYBACK_BUFFER_SEC)
	var buffered := capacity - playback.get_frames_available()
	var now := Time.get_ticks_msec()
	var gap_ms := now - int(entry.get("last_msec", 0))
	entry["last_msec"] = now
	# Penyangga jitter: paket jaringan datang tidak rata. Tanpa cadangan beberapa milidetik,
	# generator kehabisan data di sela paket dan suara berderak. Isi sedikit hening di awal
	# bicara atau setelah buffer kosong.
	if buffered <= 0 or gap_ms > 250:
		var padding := PackedVector2Array()
		padding.resize(VOICE_JITTER_FRAMES)
		if playback.can_push_buffer(padding.size()):
			playback.push_buffer(padding)
			buffered += padding.size()
	# Buang paket bila antrean terlalu panjang agar suara tidak makin tertinggal.
	if buffered > int(VOICE_SAMPLE_RATE * VOICE_MAX_LATENCY_SEC):
		return
	if playback.can_push_buffer(samples.size()):
		playback.push_buffer(samples)

# Jarak dengar suara pemain = jarak dengar guru, dibaca langsung dari guru supaya
# kalau hearing_distance guru diubah, suara pemain ikut berubah.
func _get_voice_range() -> float:
	var teacher := get_tree().get_first_node_in_group("teacher")
	if teacher != null and is_instance_valid(teacher):
		var value: Variant = teacher.get("hearing_distance")
		if value is float or value is int:
			return maxf(float(value), 1.0)
	return VOICE_HEARING_RANGE


func _update_voice_spatial(player: AudioStreamPlayer3D, entry: Dictionary, source_position: Vector3) -> void:
	var voice_range := _get_voice_range()
	player.max_distance = voice_range
	player.unit_size = voice_range * VOICE_UNIT_RATIO
	player.global_position = source_position
	var now := Time.get_ticks_msec()
	if now - int(entry.get("occ_msec", 0)) < VOICE_OCCLUSION_INTERVAL_MSEC:
		return
	entry["occ_msec"] = now
	# Berubah halus (bukan mendadak) saat pemain keluar-masuk di balik dinding.
	var occlusion := lerpf(float(entry.get("occlusion", 0.0)), _wall_occlusion(source_position), 0.4)
	entry["occlusion"] = occlusion
	player.volume_db = VOICE_OCCLUDED_MAX_DB * occlusion
	var cutoff := 20500.0 * pow(VOICE_OCCLUDED_CUTOFF_HZ / 20500.0, occlusion)
	player.attenuation_filter_cutoff_hz = 20500.0 if cutoff > 18000.0 else cutoff


# 0 = jalur bersih, 1 = banyak dinding. Dinding hanya meredam dan menumpulkan suara,
# tidak pernah membuatnya hilang total.
func _wall_occlusion(source_position: Vector3) -> float:
	var camera := get_viewport().get_camera_3d()
	var world := get_viewport().find_world_3d()
	if camera == null or world == null:
		return 0.0
	var space := world.direct_space_state
	var exclude: Array[RID] = []
	var walls := 0
	for _attempt in range(VOICE_OCCLUSION_MAX_WALLS + 3):
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, source_position, 0xFFFFFFFF, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		exclude.append(hit["rid"])
		var collider: Object = hit.get("collider")
		# Orang (pemain/guru) dan benda lepas tidak dianggap penghalang.
		if collider is CharacterBody3D or collider is RigidBody3D:
			continue
		walls += 1
		if walls >= VOICE_OCCLUSION_MAX_WALLS:
			break
	match walls:
		0:
			return 0.0
		1:
			return 0.6
		2:
			return 0.85
		_:
			return 1.0

func _stop_remote_voice(peer_id: int) -> void:
	var entry: Dictionary = _voice_playbacks.get(peer_id, {})
	var player := entry.get("player") as AudioStreamPlayer3D
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
	_voice_playbacks.erase(peer_id)
