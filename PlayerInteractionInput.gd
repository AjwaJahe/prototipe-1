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
var _mobile_left_held := false
var _mobile_right_held := false
var _highlight_target: Node = null

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
	if _is_mobile_mode():
		return
	if event is InputEventMouseButton and _pointer_over_ui():
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
	_update_interaction_highlight()

	# Klik/tahan mouse adalah jalur desktop. Di mode HP, hanya tombol interaksi
	# mobile_interact/mobile_stop_interact yang menggerakkan state interaksi.
	if not _is_mobile_mode():
		var left_raw := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		var right_raw := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		var pointer_over_ui := (left_raw or right_raw) and _pointer_over_ui()
		var left_down := left_raw and not pointer_over_ui
		var right_down := right_raw and not pointer_over_ui

		if left_down and not _left_was_down:
			_handle_left_press()
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
	else:
		if _left_was_down:
			_handle_left_release()
		if _right_was_down:
			_handle_right_release()
		_left_was_down = false
		_right_was_down = false

	# Tombol HP tetap memakai jalur tahan khususnya, terlepas dari mouse desktop.
	if _mobile_left_held:
		_handle_left_hold()
	if _mobile_right_held:
		_handle_right_hold()

func _is_mobile_mode() -> bool:
	var controls := player.get_node_or_null("MobileControls") if is_instance_valid(player) else null
	return controls != null and controls.has_method("is_mobile") and bool(controls.call("is_mobile"))


func _pointer_over_ui() -> bool:
	# GUI diberi prioritas di atas raycast 3D, termasuk panel modal dan tombol HUD.
	var pointer_position := get_viewport().get_mouse_position()
	var pending: Array[Node] = [get_tree().root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
		if not node is Control:
			continue
		var control := node as Control
		if not control.is_visible_in_tree() or control.mouse_filter != Control.MOUSE_FILTER_STOP:
			continue
		if control.get_global_rect().has_point(pointer_position):
			return true
	return false


func get_mobile_look_target() -> Node:
	return _get_look_target()


func mobile_interact() -> void:
	if not _mobile_left_held:
		_handle_left_press()
	_mobile_left_held = true


func mobile_stop_interact() -> void:
	if _mobile_left_held:
		_mobile_left_held = false
		_handle_left_release()


func mobile_hide() -> void:
	_handle_right_press()


func mobile_heal() -> void:
	_mobile_right_held = true
	_handle_right_hold()


func mobile_stop_heal() -> void:
	if _mobile_right_held:
		_mobile_right_held = false
		_handle_right_release()

func _handle_left_press() -> void:
	var target := _get_look_target()
	if target == null or not target.has_method("interact"):
		return
	if bool(get_tree().get_meta("kelas_malam_multiplayer_active", false)) and multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		var scene := get_tree().current_scene
		var network_game := scene.get_node_or_null("MultiplayerGame") if scene != null else null
		if target.is_in_group("doors"):
			if network_game != null and network_game.has_method("request_door_interaction"):
				network_game.rpc_id(1, "request_door_interaction", String(scene.get_path_to(target)))
			return
		if target.is_in_group("map58_rack_storage"):
			if network_game != null and network_game.has_method("request_rack_interaction"):
				network_game.rpc_id(1, "request_rack_interaction", String(scene.get_path_to(target)))
			return
		if String(target.get_meta("interaction_type", "")) == "item" and target.has_meta("item_type"):
			if network_game != null and network_game.has_method("request_item_pickup"):
				network_game.rpc_id(1, "request_item_pickup", String(scene.get_path_to(target)))
			return
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
		var hidden_spot: Node = player.get_meta("hide_spot") as Node if player.has_meta("hide_spot") else null
		if hidden_spot != null and is_instance_valid(hidden_spot):
			if _request_network_hiding(hidden_spot):
				return
			if hidden_spot.has_method("toggle_hide"):
				hidden_spot.toggle_hide(player)
		return

	var target := _get_look_target()
	if target == null or not target.has_method("toggle_hide"):
		return
	if target.is_in_group("map58_rack_storage") and _request_network_rack_store(target):
		return
	if _request_network_hiding(target):
		return
	target.toggle_hide(player)


func _request_network_hiding(target: Node) -> bool:
	if not bool(get_tree().get_meta("kelas_malam_multiplayer_active", false)):
		return false
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		return false
	# Only route actual hiding furniture through this RPC. Rack storage has a
	# separate inventory workflow and must not be treated as a hiding spot.
	if not target.is_in_group("map58_hiding_spot") and not target.is_in_group("map58_classroom_cupboard"):
		return false
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var network_game := scene.get_node_or_null("MultiplayerGame")
	if network_game == null or not network_game.has_method("request_hiding_interaction"):
		return false
	network_game.rpc_id(1, "request_hiding_interaction", String(scene.get_path_to(target)))
	return true

func _request_network_rack_store(target: Node) -> bool:
	if not bool(get_tree().get_meta("kelas_malam_multiplayer_active", false)) or multiplayer.multiplayer_peer == null or multiplayer.is_server():
		return false
	if not target.is_in_group("map58_rack_storage"):
		return false
	var inventory := player.get_node_or_null("ItemInventory")
	if inventory == null:
		return true
	var items_variant: Variant = inventory.get("items")
	var selected_slot := int(inventory.get("selected_slot"))
	if not items_variant is Array or selected_slot < 0 or selected_slot >= (items_variant as Array).size():
		if inventory.has_method("_set_status"):
			inventory.call("_set_status", "Pilih item di inventori sebelum menyimpannya di rak.")
		return true
	var items: Array = items_variant
	var item := items[selected_slot] as Node3D
	var scene := get_tree().current_scene
	if item == null or not is_instance_valid(item) or scene == null:
		return true
	var network_game := scene.get_node_or_null("MultiplayerGame")
	if network_game != null and network_game.has_method("request_rack_store_item"):
		network_game.rpc_id(1, "request_rack_store_item", String(scene.get_path_to(target)), String(scene.get_path_to(item)))
	return true


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
		if current is Node3D and (String(current.name) == "Bed_Left" or String(current.name) == "Bed_Right"):
			var bed_hide_spot := current.get_node_or_null("Map58HideSpotUnderBed")
			if bed_hide_spot != null:
				return bed_hide_spot
		if current.has_method("interact") or current.has_method("draw_answer") or current.has_method("toggle_hide") or current.has_method("heal"):
			return current
		current = current.get_parent()
	return null


func _update_interaction_highlight() -> void:
	var target := _get_look_target()
	if _highlight_target != target:
		if is_instance_valid(_highlight_target) and _highlight_target.has_method("set_interaction_highlight"):
			_highlight_target.set_interaction_highlight(false)
		_highlight_target = target
	if is_instance_valid(_highlight_target) and _highlight_target.has_method("set_interaction_highlight"):
		_highlight_target.set_interaction_highlight(true)
