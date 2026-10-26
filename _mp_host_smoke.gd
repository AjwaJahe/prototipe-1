extends SceneTree

const TEST_PORT := 38971

func _initialize() -> void:
	call_deferred("_boot")

func _boot() -> void:
	set_meta("kelas_malam_multiplayer_active", true)
	set_meta("kelas_malam_is_host", true)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(TEST_PORT, 4)
	if err != OK:
		print("MP_TEST_HOST_CREATE_FAILED=", err)
		quit(1)
		return
	get_root().multiplayer.multiplayer_peer = peer
	print("MP_TEST_HOST_LISTENING")
	var scene_err := change_scene_to_file("res://main.tscn")
	print("MP_TEST_HOST_SCENE=", scene_err)
	await create_timer(12.0).timeout
	var scene := current_scene
	var network_game := scene.find_child("MultiplayerGame", true, false) if scene != null else null
	var count := -1
	if network_game != null:
		var avatars: Dictionary = network_game.get("_remote_avatars")
		count = avatars.size()
	print("MP_TEST_HOST_REMOTE_AVATARS=", count)
	print("MP_TEST_HOST_PEERS=", get_root().multiplayer.get_peers().size())
	quit()
