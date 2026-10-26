extends SceneTree

func _init() -> void:
	var log := FileAccess.open("res://__validate_ui_door.log", FileAccess.WRITE)
	var packed := load("res://main.tscn") as PackedScene
	if packed == null:
		log.store_line("MAIN_LOAD_FAILED")
		log.close()
		quit(1)
		return

	var main := packed.instantiate()
	get_root().add_child(main)
	await process_frame

	var player := main.get_node("Player")
	var character := player.get_node("CharacterBody3D")
	var interaction := character.get_node_or_null("InteractionInput")
	var crosshair := player.get_node_or_null("CrosshairLayer/CrosshairCenter/Crosshair")
	log.store_line("INTERACTION=" + str(interaction != null))
	log.store_line("CROSSHAIR=" + str(crosshair != null))

	var door := main.get_node("Furniture/PintuKelas_10_A_South")
	var area := door.get_node_or_null("InteractionArea")
	var slide := door.get_node("DoorPivot") as AnimatableBody3D
	log.store_line("AREA=" + str(area != null))
	log.store_line("START_X=" + str(slide.position.x))

	door.interact(character)
	await create_timer(1.0).timeout
	log.store_line("OPEN_X=" + str(slide.position.x))

	door.interact(character)
	await create_timer(1.0).timeout
	log.store_line("CLOSED_X=" + str(slide.position.x))
	log.store_line("ROT_Y=" + str(slide.rotation.y))

	log.close()
	main.queue_free()
	quit(0)
