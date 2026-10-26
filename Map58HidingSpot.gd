extends Area3D

## Shared hiding controller for cabinets and under-bed hiding.
## Under-bed mode relocates the player's POV below the mattress and restores
## the exact previous transform when the player exits.

var _hidden_player: CharacterBody3D
var _saved_player_transform: Transform3D
var _saved_camera_position := Vector3.ZERO
var _saved_camera_rotation := Vector3.ZERO
var _saved_physics_process := true


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	monitoring = true
	monitorable = true
	add_to_group("map58_hiding_spot")
	set_meta("interaction_type", "hiding")


func toggle_hide(player: Node = null) -> void:
	if player == null or not player is CharacterBody3D:
		return

	var character := player as CharacterBody3D
	if bool(character.get_meta("is_hidden", false)):
		_exit_hiding(character)
	else:
		_enter_hiding(character)


func _enter_hiding(player: CharacterBody3D) -> void:
	if bool(player.get_meta("is_hidden", false)):
		return

	_hidden_player = player
	_saved_player_transform = player.global_transform
	_saved_physics_process = player.is_physics_processing()
	var camera := player.get_node_or_null("Camera3D") as Camera3D
	if camera != null:
		_saved_camera_position = camera.position
		_saved_camera_rotation = camera.rotation

	player.velocity = Vector3.ZERO
	player.set_meta("is_hidden", true)
	player.set_meta("hide_spot", self)

	if String(get_meta("hide_style", "")) == "under_bed":
		_enter_under_bed(player, camera)
		_set_status(player, "Kamu bersembunyi di bawah kasur. Klik kanan untuk keluar.")
	else:
		player.set_physics_process(false)
		_set_status(player, "Kamu bersembunyi. Klik kanan untuk keluar.")


func _enter_under_bed(player: CharacterBody3D, camera: Camera3D) -> void:
	var bed := get_parent() as Node3D
	if bed == null:
		player.set_meta("is_hidden", false)
		player.set_meta("hide_spot", null)
		return

	# Place the player under the center of the bed; the camera sits just below
	# the mattress and faces out through the long side for a horror-game POV.
	var under_bed_position := bed.to_global(Vector3(0.0, 0.0, 0.0))
	player.global_position = under_bed_position
	player.global_rotation = bed.global_rotation
	player.rotate_y(PI)
	player.velocity = Vector3.ZERO
	if camera != null:
		camera.position = Vector3(
			_saved_camera_position.x,
			0.34,
			_saved_camera_position.z
		)
		camera.rotation = Vector3(-0.04, 0.0, 0.0)

	player.set_physics_process(false)


func _exit_hiding(player: CharacterBody3D) -> void:
	var camera := player.get_node_or_null("Camera3D") as Camera3D
	player.set_physics_process(false)
	player.global_transform = _saved_player_transform
	if camera != null:
		camera.position = _saved_camera_position
		camera.rotation = _saved_camera_rotation
	player.velocity = Vector3.ZERO
	player.set_meta("is_hidden", false)
	player.set_meta("hide_spot", null)
	player.set_physics_process(_saved_physics_process)
	_hidden_player = null
	_set_status(player, "Kamu keluar dari tempat persembunyian.")


func _set_status(player: CharacterBody3D, message: String) -> void:
	var inventory := player.get_node_or_null("ItemInventory")
	if inventory != null and inventory.has_method("_set_status"):
		inventory.call("_set_status", message)
