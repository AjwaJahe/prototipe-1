extends Node
## Input layer for Map58's first-person interaction controls.
## Attach this script to a plain Node child of Player/CharacterBody3D.
## It does not replace or modify Player.gd.
##
## Left click:
##   - on press: calls "interact" on the object in front of the camera, if it exists.
##   - while held: calls "draw_answer" on the object, if it exists.
## Right click:
##   - on press: calls "toggle_hide" on the object, if it exists.
##   - while held: calls "heal" on the object, if it exists.
##
## Nothing happens when the corresponding method is not present.

@export var interaction_distance: float = 3.0

var _left_was_down := false
var _right_was_down := false

@onready var player: CharacterBody3D = get_parent() as CharacterBody3D
@onready var camera: Camera3D = player.get_node_or_null("Camera3D") as Camera3D

func _ready() -> void:
	if player == null:
		push_error("PlayerInteractionInput.gd harus menjadi child langsung dari CharacterBody3D Player.")
		set_process(false)
		set_process_unhandled_input(false)
		return
	if camera == null:
		push_error("Camera3D tidak ditemukan sebagai child dari CharacterBody3D Player.")

func _unhandled_input(event: InputEvent) -> void:
	if camera == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not _left_was_down:
				_handle_left_press()
			_left_was_down = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed and not _right_was_down:
				_handle_right_press()
			_right_was_down = event.pressed

func _process(_delta: float) -> void:
	if camera == null:
		return

	var left_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var right_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	if left_down:
		_handle_left_hold()
	elif _left_was_down:
		_handle_left_release()

	if right_down:
		_handle_right_hold()
	elif _right_was_down:
		_handle_right_release()

	_left_was_down = left_down
	_right_was_down = right_down

func _handle_left_press() -> void:
	var target := _get_look_target()
	if target != null and target.has_method("interact"):
		target.interact(player)

func _handle_left_hold() -> void:
	var target := _get_look_target()
	if target != null and target.has_method("draw_answer"):
		target.draw_answer(player)

func _handle_left_release() -> void:
	var target := _get_look_target()
	if target != null and target.has_method("stop_drawing"):
		target.stop_drawing(player)

func _handle_right_press() -> void:
	if bool(player.get_meta("is_hidden", false)):
		var hidden_spot := player.get_meta("hide_spot", null) as Node
		if hidden_spot != null and is_instance_valid(hidden_spot):
			if hidden_spot.has_method("toggle_hide"):
				hidden_spot.toggle_hide(player)
		return

	var target := _get_look_target()
	if target != null and target.has_method("toggle_hide"):
		target.toggle_hide(player)

func _handle_right_hold() -> void:
	var target := _get_look_target()
	if target != null and target.has_method("heal"):
		target.heal(player)

func _handle_right_release() -> void:
	var target := _get_look_target()
	if target != null and target.has_method("stop_heal"):
		target.stop_heal(player)

func _get_look_target() -> Node:
	if camera == null:
		return null

	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * interaction_distance)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var collider := hit.get("collider") as Node
	return _find_interaction_node(collider)

func _find_interaction_node(node: Node) -> Node:
	var current := node
	while current != null:
		if current.has_method("interact") or current.has_method("draw_answer") or current.has_method("toggle_hide") or current.has_method("heal"):
			return current
		current = current.get_parent()
	return null
