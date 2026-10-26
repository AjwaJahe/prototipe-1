extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	var menu: Control = (load("res://MainMenu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	print("TEST menu siap")

	menu.get_node("%PengaturanButton").pressed.emit()
	await process_frame
	print("TEST settings terbuka=", menu.get_node("%SettingsOverlay").visible)
	var slider: HSlider = menu.get_node("%VolumeSlider")
	slider.value = 0.5
	await process_frame
	print("TEST volume 0.5 -> db=", snapped(AudioServer.get_bus_volume_db(0), 0.01), " label=", menu.get_node("%VolumeValue").text)
	slider.value = 1.0
	await process_frame
	print("TEST volume 1.0 -> db=", snapped(AudioServer.get_bus_volume_db(0), 0.01), " label=", menu.get_node("%VolumeValue").text)
	menu.get_node("%KembaliButton").pressed.emit()
	await process_frame
	print("TEST settings tertutup=", not menu.get_node("%SettingsOverlay").visible)

	menu.get_node("%KarakterButton").pressed.emit()
	await process_frame
	print("TEST info terbuka=", menu.get_node("%InfoOverlay").visible, " judul=", menu.get_node("%InfoTitle").text)
	menu.get_node("%InfoOkButton").pressed.emit()
	await process_frame
	print("TEST info tertutup=", not menu.get_node("%InfoOverlay").visible)

	# bersihkan file pengaturan hasil tes
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://menu_settings.cfg"))

	menu.get_node("%MulaiButton").pressed.emit()
	for i in 30:
		await process_frame
	print("TEST scene sekarang=", current_scene.name if current_scene != null else "null")
	quit()
