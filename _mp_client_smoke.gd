extends SceneTree

const TEST_PORT := 38971

func _initialize() -> void:
	call_deferred("_boot")

func _boot() -> void:
	set_meta("kelas_malam_multiplayer_active", true)
	set_meta("kelas_malam_is_host", false)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client("127.0.0.1", TEST_PORT)
	if err != OK:
		print("MP_TEST_CLIENT_CREATE_FAILED=", err)
		quit(1)
		return
	get_root().multiplayer.multiplayer_peer = peer
	get_root().multiplayer.connected_to_server.connect(_on_connected)
	var scene_err := change_scene_to_file("res://main.tscn")
	print("MP_TEST_CLIENT_SCENE=", scene_err)
	await create_timer(5.0).timeout
	var scene := current_scene
	var network_game := scene.find_child("MultiplayerGame", true, false) if scene != null else null
	var player_node := scene.find_child("Player", true, false) if scene != null else null
	var body := player_node.get_node_or_null("CharacterBody3D") as CharacterBody3D if player_node != null else null
	if network_game != null and body != null:
		var closest: Node3D = null
		var closest_distance := 3.5
		var candidates: Array[Node] = []
		_collect_items(scene, candidates)
		for candidate in candidates:
			var item := candidate as Node3D
			if not item.visible or bool(item.get_meta("in_inventory", false)) or bool(item.get_meta("stored_in_rack", false)):
				continue
			var distance := body.global_position.distance_to(item.global_position)
			if distance < closest_distance:
				closest = item
				closest_distance = distance
		if closest != null:
			var item_path := String(scene.get_path_to(closest))
			print("MP_TEST_CLIENT_PICKUP_REQUEST=", item_path)
			network_game.rpc_id(1, "request_item_pickup", item_path)
			await create_timer(1.0).timeout
			var inventory := body.get_node_or_null("ItemInventory")
			var item_count := int((inventory.get("items") as Array).size()) if inventory != null else -1
			print("MP_TEST_CLIENT_PICKUP_COUNT=", item_count)
			if inventory != null and item_count > 0:
				network_game.rpc_id(1, "request_drop_item", item_path)
				await create_timer(1.0).timeout
				print("MP_TEST_CLIENT_DROP_COUNT=", (inventory.get("items") as Array).size())
		else:
			print("MP_TEST_CLIENT_NO_NEARBY_ITEM")
	else:
		print("MP_TEST_CLIENT_SCENE_NODES_MISSING")
	await create_timer(5.0).timeout
	var remote_count := -1
	if network_game != null:
		var avatars: Dictionary = network_game.get("_remote_avatars")
		remote_count = avatars.size()
	print("MP_TEST_CLIENT_REMOTE_AVATARS=", remote_count)
	print("MP_TEST_CLIENT_PEER_ID=", get_root().multiplayer.get_unique_id())
	quit()

func _on_connected() -> void:
	print("MP_TEST_CLIENT_CONNECTED")

func _collect_items(node: Node, result: Array[Node]) -> void:
	if node is Node3D and node.has_meta("item_type"):
		result.append(node)
	for child in node.get_children():
		_collect_items(child, result)
