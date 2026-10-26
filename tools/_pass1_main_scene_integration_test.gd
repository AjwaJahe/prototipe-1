extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed := load("res://main.tscn") as PackedScene
	if packed == null:
		printerr("FAIL: main.tscn gagal dimuat")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	current_scene = game
	for i in range(30):
		await process_frame
	for path in [
		"GameManager",
		"Teacher",
		"Player/CharacterBody3D/MobileControls",
		"UIManager",
		"AudioManager",
		"GameAudioManager",
		"WhiteboardController",
		"FurnitureGameplay",
		"MultiplayerGame"
	]:
		if game.get_node_or_null(path) == null:
			failures.append("Node gameplay hilang: " + path)
			printerr("FAIL: node hilang ", path)
		else:
			print("NODE_OK ", path)
	var player := game.get_node_or_null("Player/CharacterBody3D")
	var hud := root.find_child("MobileHUDScene", true, false)
	if player == null or hud == null:
		failures.append("HUD mobile tidak terpasang di scene gameplay")
		printerr("FAIL: HUD mobile tidak terpasang di scene gameplay")
	else:
		print("HUD_OK rect=", hud.get_global_rect(), " filter=", hud.mouse_filter)
		for key in ["JumpButton", "RunButton", "CrouchButton", "MovementJoystick"]:
			if hud.get_node_or_null(key) == null:
				failures.append("Kontrol HUD hilang: " + key)
				printerr("FAIL: kontrol hilang ", key)
		var router := player.get_node_or_null("InputRouter")
		if router == null:
			failures.append("InputRouter tidak ditemukan pada Player")
			printerr("FAIL: InputRouter tidak ditemukan")
		else:
			print("INPUT_MODE mobile=", player.get_node("MobileControls").call("is_mobile"))
	if failures.is_empty():
		print("PASS: main.tscn runtime integration structure")
		quit(0)
	else:
		printerr("FAILURES: ", failures.size())
		quit(1)
