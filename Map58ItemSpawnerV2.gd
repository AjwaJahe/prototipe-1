extends Node

const TEST_POINTS_PATH := NodePath("../Furniture/Map58_ItemsTest")
const FURNITURE_PATH := NodePath("../Furniture")
const MAX_ACTIVE_ITEMS := 15
const MAX_ACTIVE_PAPERS := 5
const MAX_ACTIVE_CHALK := 5
const MAX_ACTIVE_MEDKITS := 5
# Ruang toilet: counter/cabinet wastafel belum punya collision, jadi titiknya diterima tanpa raycast.
const TOILET_ROOMS := ["MaleToilet", "FemaleToilet"]

@export var minimum_spawn_separation: float = 0.75
@export var initial_surface_offset: float = 0.04
@export var ground_despawn_seconds: float = 0.0
@export var randomize_respawn: bool = true

var _game: Node
var _rng := RandomNumberGenerator.new()
var _spawn_points: Array[Vector3] = []
var _spawn_points_by_room: Dictionary = {}
var _point_room: Dictionary = {}
var _despawn_check_remaining := 0.0


func _ready() -> void:
	_rng.randomize()
	call_deferred("_initialize")


## Di sesi multiplayer HANYA host yang mengacak, menaruh, dan mengganti item.
## Client mengikuti snapshot dunia dari host (MultiplayerGame.gd). Tanpa ini setiap
## peer mengacak sendiri dan membuat item/klon yang berbeda dari host.
func _is_network_client() -> bool:
	if not bool(get_tree().get_meta("kelas_malam_multiplayer_active", false)):
		return false
	return multiplayer.multiplayer_peer != null and not multiplayer.is_server()


## Client menyembunyikan semua item sampai snapshot host menentukan item mana yang aktif.
func _hide_all_items_until_host_sync() -> void:
	var net_game := get_node_or_null("../MultiplayerGame")
	if net_game != null and bool(net_game.get("_world_synced")):
		return
	var root := get_node_or_null(TEST_POINTS_PATH)
	if root == null:
		return
	for child in root.get_children():
		if child is Node3D and not String(child.get_meta("item_type", "")).is_empty():
			var item := child as Node3D
			item.visible = false
			item.set_meta("in_inventory", false)
			_set_collision_enabled(item, false)


func _process(delta: float) -> void:
	_despawn_check_remaining -= delta
	if _despawn_check_remaining > 0.0:
		return
	_despawn_check_remaining = 1.0
	_despawn_expired_ground_items()


func _initialize() -> void:
	_game = get_node_or_null("../GameManager")
	await get_tree().process_frame
	if _is_network_client():
		_hide_all_items_until_host_sync()
		print("Map58ItemSpawner: mode client - item mengikuti snapshot host.")
		return
	# Tunggu collision map dan furnitur masuk ke physics space sebelum validasi titik.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_collect_spawn_points()
	_validate_spawn_points()
	_randomize_initial_items()
	if _game != null and _game.has_signal("paper_respawn_requested"):
		var cb := Callable(self, "_on_paper_respawn_requested")
		if not _game.paper_respawn_requested.is_connected(cb):
			_game.paper_respawn_requested.connect(cb)
	print("Map58ItemSpawner: surface=", _spawn_points.size(),
		", item aktif=", _count_active_items(), "/", MAX_ACTIVE_ITEMS,
		", paper=", _count_active_type("paper"),
		", chalk=", _count_active_type("chalk"),
		", medkit=", _count_active_type("medkit"))


func _collect_spawn_points() -> void:
	_spawn_points.clear()
	_spawn_points_by_room.clear()
	_point_room.clear()
	var furniture := get_node_or_null(FURNITURE_PATH)
	if furniture != null:
		for room_root in furniture.get_children():
			var n := String(room_root.name)
			var room_key := n.trim_suffix("_Furniture") if n.ends_with("_Furniture") else ""
			if not room_key.is_empty():
				_spawn_points_by_room[room_key] = []
			_collect_furniture_surfaces(room_root, room_key)
	if not _spawn_points.is_empty():
		return
	var marker_root := get_node_or_null("../Map58_ItemSpawnPoints")
	if marker_root != null:
		for child in marker_root.get_children():
			if child is Marker3D:
				_spawn_points.append((child as Marker3D).global_position)


## Tolak titik hasil perkiraan mesh yang tidak ditopang collision fisik.
## Titik yang valid diselaraskan ke permukaan collision aktual; titik melayang,
## di dalam objek, atau pada sisi vertikal tidak boleh dipakai untuk spawn.
func _validate_spawn_points() -> void:
	var item_root := get_node_or_null(TEST_POINTS_PATH)
	var excluded: Array[RID] = []
	if item_root != null:
		for child in item_root.get_children():
			if child is CollisionObject3D:
				excluded.append((child as CollisionObject3D).get_rid())

	var valid_points: Array[Vector3] = []
	var valid_by_room: Dictionary = {}
	var valid_room_by_point: Dictionary = {}
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state

	for candidate in _spawn_points:
		var candidate_room := String(_point_room.get(candidate, ""))
		var hit: Dictionary = {}
		if candidate_room == "Warehouse":
			# Collider tiap rak gudang menutupi seluruh tinggi rak, sehingga raycast
			# mengenai puncak collider dan menolak ambalan bawah. Titik berasal langsung
			# dari AABB mesh Shelf_*; validasi pakai tinggi mesh itu, bukan collider rak.
			hit = {"position": candidate - Vector3.UP * initial_surface_offset, "normal": Vector3.UP}
		else:
			var query := PhysicsRayQueryParameters3D.create(
				candidate + Vector3.UP * 0.35,
				candidate - Vector3.UP * 0.65,
				0xFFFFFFFF,
				excluded
			)
			query.collide_with_areas = false
			hit = space.intersect_ray(query)
		if hit.is_empty():
			if candidate_room in TOILET_ROOMS:
				# Titik atas BoxMesh sudah akurat dari AABB; pakai langsung tanpa collision.
				hit = {"position": candidate - Vector3.UP * initial_surface_offset, "normal": Vector3.UP}
			else:
				continue

		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		var hit_position: Vector3 = hit.get("position", candidate)
		if normal.y < 0.65 or absf(hit_position.y - candidate.y) > 0.30:
			continue

		var point := Vector3(candidate.x, hit_position.y + initial_surface_offset, candidate.z)
		valid_points.append(point)
		var room := String(_point_room.get(candidate, ""))
		valid_room_by_point[point] = room
		if not room.is_empty():
			if not valid_by_room.has(room):
				valid_by_room[room] = []
			(valid_by_room[room] as Array).append(point)

	print("Map58ItemSpawner: titik spawn tervalidasi=", valid_points.size(), "/", _spawn_points.size())
	for room_key in _spawn_points_by_room.keys():
		var room_total: int = (_spawn_points_by_room[room_key] as Array).size()
		var room_ok: int = (valid_by_room[room_key] as Array).size() if valid_by_room.has(room_key) else 0
		var y_info := ""
		var room_node := get_node_or_null(String(FURNITURE_PATH) + "/" + String(room_key) + "_Furniture") as Node3D
		if room_node != null and valid_by_room.has(room_key):
			var y_min := INF
			var y_max := -INF
			for vp in (valid_by_room[room_key] as Array):
				var rel_y: float = (vp as Vector3).y - room_node.global_position.y
				y_min = minf(y_min, rel_y)
				y_max = maxf(y_max, rel_y)
			y_info = " | tinggi dari dasar ruangan %.2f..%.2f m" % [y_min, y_max]
		print("Map58ItemSpawner: ruangan ", room_key, " valid ", room_ok, "/", room_total, y_info)
	_spawn_points = valid_points
	_spawn_points_by_room = valid_by_room
	_point_room = valid_room_by_point


func _collect_furniture_surfaces(node: Node, room_key: String = "") -> void:
	if node is MeshInstance3D and _is_surface_candidate(node as MeshInstance3D, room_key):
		_add_surface_points(node as MeshInstance3D, room_key)
	for child in node.get_children():
		_collect_furniture_surfaces(child, room_key)


func _is_surface_candidate(m: MeshInstance3D, room_key: String = "") -> bool:
	if m.mesh == null:
		return false
	# Nama permukaan sering ada di parent (mis. Desk_07), bukan mesh anak.
	var named_surface := false
	var name_node: Node = m
	for _i in range(10):
		if name_node == null:
			break
		var surface_name := String(name_node.name).to_lower()
		for word in ["top", "counter", "shelf", "worktop", "desktop", "table", "desk", "seat", "bench", "drawer", "cabinet"]:
			if surface_name.contains(word):
				named_surface = true
				break
		if named_surface:
			break
		name_node = name_node.get_parent()
	if not named_surface:
		return false
	
	var current: Node = m
	for _i in range(10):
		if current == null:
			break
		# Jangan gunakan permukaan furnitur yang berfungsi sebagai tempat bersembunyi.
		# Beberapa tempat sembunyi menandai dirinya dengan interaction_type, sementara
		# peti menandai Area3D anaknya melalui grup map58_hiding_spot.
		if String(current.get_meta("interaction_type", "")) == "hiding":
			return false
		if current.is_in_group("map58_hiding_spot") or current.is_in_group("map58_classroom_cupboard"):
			return false
		# Jangan memeriksa seluruh descendant dari root bersama (FurnitureRoot):
		# satu lemari tempat sembunyi dapat membuat semua meja di kelas ikut tertolak.
		var cn := String(current.name).to_lower()
		for word in ["door", "pintu", "frame", "whiteboard", "board", "lamp", "fixture", "sign", "roof", "awning", "leg", "back", "handle", "pull", "knob", "hinge", "collision"]:
			if cn.contains(word):
				return false
		current = current.get_parent()
	var a := m.get_aabb()
	var max_height := 0.45
	# Toilet: counter/cabinet wastafel berupa balok setinggi ±0.78 m. Titik spawn
	# diambil dari sisi atas balok, jadi batas tinggi dilonggarkan khusus di sini.
	if room_key in TOILET_ROOMS:
		max_height = 0.85
	return a.size.y <= max_height and a.size.x >= 0.22 and a.size.z >= 0.18


func _has_hiding_spot_descendant(node: Node) -> bool:
	# Cek anak langsung saja: peti memiliki Area3D tempat sembunyi sebagai anak,
	# sedangkan lemari kelas menandai node furniturnya sendiri.
	for child in node.get_children():
		if child.is_in_group("map58_hiding_spot") or String(child.get_meta("interaction_type", "")) == "hiding":
			return true
	return false


func _add_surface_points(m: MeshInstance3D, room_key: String = "") -> void:
	var a := m.get_aabb()
	var hx := a.size.x * 0.5
	var hz := a.size.z * 0.5
	var center := a.position + Vector3(hx, a.size.y, hz)
	var area := a.size.x * a.size.z
	var local_points: Array[Vector3] = []
	if area >= 2.0:
		var ox := minf(hx * 0.5, 0.75)
		var oz := minf(hz * 0.5, 0.35)
		# Rak gudang memiliki kotak di tengah tiap ambalan. Ambil titik di bibir
		# depan/belakang yang masih berada di atas papan, bukan menembus kotak.
		if room_key == "Warehouse":
			oz = minf(hz * 0.82, 0.45)
		local_points = [center + Vector3(-ox, initial_surface_offset, -oz),
			center + Vector3(ox, initial_surface_offset, -oz),
			center + Vector3(-ox, initial_surface_offset, oz),
			center + Vector3(ox, initial_surface_offset, oz)]
	elif area >= 0.35:
		local_points = [center + Vector3(-hx * 0.25, initial_surface_offset, 0),
			center + Vector3(hx * 0.25, initial_surface_offset, 0)]
	else:
		local_points = [center + Vector3(0, initial_surface_offset, 0)]
	for lp in local_points:
		var p: Vector3 = m.global_transform * lp
		_spawn_points.append(p)
		_point_room[p] = room_key
		if not room_key.is_empty() and _spawn_points_by_room.has(room_key):
			var room_points: Array = _spawn_points_by_room[room_key]
			room_points.append(p)
			_spawn_points_by_room[room_key] = room_points


func spawn_initial_items() -> void:
	_randomize_initial_items()


func _randomize_initial_items() -> void:
	if _is_network_client():
		return
	var root := get_node_or_null(TEST_POINTS_PATH)
	if root == null or _spawn_points.is_empty():
		push_warning("ItemSpawner: tidak ada titik spawn furniture.")
		return
	var all_items: Array[Node3D] = []
	for child in root.get_children():
		if child is Node3D and not String(child.get_meta("item_type", "")).is_empty():
			all_items.append(child as Node3D)
	all_items.shuffle()
	var chosen: Array[Node3D] = []
	# Kunci unik tetap tersedia sejak awal; tidak akan diduplikasi setelah diambil.
	for item in all_items:
		var t := String(item.get_meta("item_type", ""))
		if t in ["class_key", "red_key", "blue_key", "yellow_key"]:
			chosen.append(item)
	for t in ["paper", "chalk", "medkit"]:
		var pool: Array[Node3D] = []
		for item in all_items:
			if String(item.get_meta("item_type", "")) == t:
				pool.append(item)
		pool.shuffle()
		var desired := 5 if t == "paper" else 3
		for item in pool:
			if pool.find(item) >= desired or chosen.size() >= MAX_ACTIVE_ITEMS:
				continue
			if not chosen.has(item):
				chosen.append(item)
	for item in all_items:
		if chosen.has(item):
			_place_item(item)
		else:
			item.visible = false
			item.set_meta("in_inventory", false)
			_set_collision_enabled(item, false)
	for item in all_items:
		if _count_active_items() >= MAX_ACTIVE_ITEMS:
			break
		if not item.visible and not bool(item.get_meta("in_inventory", false)):
			_place_item(item)


func on_item_picked_up(item: Node3D) -> void:
	if item == null:
		return
	if _is_network_client():
		# Client tidak boleh membuat klon pengganti sendiri; host yang memutuskan.
		return
	item.set_meta("spawned_at", 0.0)
	var t := String(item.get_meta("item_type", ""))
	if t in ["class_key", "red_key", "blue_key", "yellow_key"]:
		call_deferred("_replenish_any_after_pickup")
		return
	call_deferred("_replenish_after_pickup", t, item)


func _replenish_after_pickup(t: String, source: Node3D) -> void:
	await get_tree().process_frame
	if _count_active_items() >= MAX_ACTIVE_ITEMS or _count_active_type(t) >= _target_count(t):
		return
	if _target_count(t) <= 0 or not is_instance_valid(source):
		return
	var root := get_node_or_null(TEST_POINTS_PATH)
	if root == null:
		return
	var clone := source.duplicate() as Node3D
	if clone == null:
		return
	clone.name = source.name + "_Respawn_" + str(Time.get_ticks_msec())
	clone.set_meta("network_clone_of", String(source.name))
	root.add_child(clone)
	clone.visible = false
	clone.set_meta("in_inventory", false)
	_set_collision_enabled(clone, false)
	_place_item(clone)


func _replenish_any_after_pickup() -> void:
	await get_tree().process_frame
	if _count_active_items() >= MAX_ACTIVE_ITEMS:
		return
	for t in ["paper", "chalk", "medkit"]:
		if _count_active_type(t) >= _target_count(t):
			continue
		var hidden := _find_hidden_item(t)
		if hidden != null:
			_place_item(hidden)
			return
		var root := get_node_or_null(TEST_POINTS_PATH)
		if root == null:
			return
		for child in root.get_children():
			if child is Node3D:
				var source := child as Node3D
				if String(source.get_meta("item_type", "")) == t and source.visible and not bool(source.get_meta("in_inventory", false)):
					var clone := source.duplicate() as Node3D
					if clone != null:
						clone.name = source.name + "_Respawn_" + str(Time.get_ticks_msec())
						clone.set_meta("network_clone_of", String(source.name))
						root.add_child(clone)
						_place_item(clone)
						return


func _target_count(t: String) -> int:
	match t:
		"paper": return MAX_ACTIVE_PAPERS
		"chalk": return MAX_ACTIVE_CHALK
		"medkit": return MAX_ACTIVE_MEDKITS
		_: return 0


func _on_paper_respawn_requested() -> void:
	if _count_active_type("paper") < MAX_ACTIVE_PAPERS:
		request_item_respawn("paper")


func request_item_respawn(t: String) -> void:
	if _is_network_client():
		return
	call_deferred("_respawn_one", t)


func _respawn_one(t: String) -> void:
	if _count_active_items() >= MAX_ACTIVE_ITEMS or _count_active_type(t) >= _target_count(t):
		return
	var item := _find_hidden_item(t)
	if item != null:
		_place_item(item)
		if t == "paper" and _game != null:
			_game.call_deferred("register_spawned_paper")


func _find_hidden_item(t: String) -> Node3D:
	var root := get_node_or_null(TEST_POINTS_PATH)
	if root == null:
		return null
	for child in root.get_children():
		if child is Node3D:
			var item := child as Node3D
			if String(item.get_meta("item_type", "")) == t and not item.visible and not bool(item.get_meta("in_inventory", false)):
				return item
	return null


func _place_item(item: Node3D) -> void:
	var t := String(item.get_meta("item_type", ""))
	# Kunci, buku, dan kapur mengikuti titik spawn acak seperti item lainnya.
	var candidates_by_room: Dictionary = {}
	for point in _spawn_points:
		if _point_allowed(point, t) and _position_clear(point, item):
			var room := String(_point_room.get(point, ""))
			if not candidates_by_room.has(room):
				candidates_by_room[room] = []
			(candidates_by_room[room] as Array).append(point)
	# Ratakan persebaran: utamakan ruangan yang memiliki item aktif paling sedikit.
	if candidates_by_room.is_empty():
		for point in _spawn_points:
			if _point_allowed(point, t):
				var room := String(_point_room.get(point, ""))
				if not candidates_by_room.has(room):
					candidates_by_room[room] = []
				(candidates_by_room[room] as Array).append(point)
	if candidates_by_room.is_empty():
		push_warning("ItemSpawner: tidak ada lokasi aman untuk " + t)
		return
	var room_counts: Dictionary = {}
	var least_count := 2147483647
	for room_variant in candidates_by_room.keys():
		var room_name := String(room_variant)
		var count := _active_items_in_room(room_name)
		room_counts[room_name] = count
		least_count = mini(least_count, count)
	var preferred_rooms: Array[String] = []
	for room_variant in candidates_by_room.keys():
		var room_name := String(room_variant)
		if int(room_counts.get(room_name, 0)) == least_count:
			preferred_rooms.append(room_name)
	preferred_rooms.shuffle()
	var chosen_room := preferred_rooms[0]
	var room_candidates: Array = candidates_by_room[chosen_room]
	var point: Vector3 = room_candidates[_rng.randi_range(0, room_candidates.size() - 1)] if randomize_respawn else room_candidates[0]
	var lowest := _lowest_mesh_y(item)
	item.global_position = Vector3(point.x, point.y - lowest, point.z)
	item.set_meta("spawn_room", chosen_room)
	item.visible = true
	item.set_meta("in_inventory", false)
	item.set_meta("stored_in_rack", false)
	item.set_meta("spawned_at", Time.get_ticks_msec() / 1000.0)
	_set_collision_enabled(item, true)
	if item.has_method("set_highlighted"):
		item.set_highlighted(false)


func _active_items_in_room(room_name: String) -> int:
	if room_name.is_empty():
		return 0
	var root := get_node_or_null(TEST_POINTS_PATH)
	if root == null:
		return 0
	var count := 0
	for child in root.get_children():
		if child is Node3D:
			var item := child as Node3D
			if not item.visible or bool(item.get_meta("in_inventory", false)):
				continue
			if String(item.get_meta("spawn_room", "")) == room_name:
				count += 1
	return count


func _point_allowed(p: Vector3, t: String) -> bool:
	var room := String(_point_room.get(p, ""))
	var forbidden: Array[String] = []
	match t:
		"class_key": forbidden = ["Kelas_12_D"]
		"red_key": forbidden = ["Warehouse", "Gudang"]
		"blue_key": forbidden = ["UKS"]
		"yellow_key": forbidden = ["PrincipalOffice", "Library"]
	return not forbidden.has(room)


func spawn_item_at_location(t: String, p: Vector3) -> bool:
	if _is_network_client() or _count_active_items() >= MAX_ACTIVE_ITEMS:
		return false
	var item := _find_hidden_item(t)
	if item == null:
		return false
	_place_item_at_surface(item, p)
	return true


func _place_item_at_surface(item: Node3D, p: Vector3) -> void:
	var lowest := _lowest_mesh_y(item)
	item.global_position = Vector3(p.x, p.y - lowest, p.z)
	item.visible = true
	item.set_meta("in_inventory", false)
	item.set_meta("stored_in_rack", false)
	item.set_meta("spawned_at", Time.get_ticks_msec() / 1000.0)
	_set_collision_enabled(item, true)


func get_spawn_location_for(t: String) -> Vector3:
	var candidates: Array[Vector3] = []
	for p in _spawn_points:
		if _point_allowed(p, t) and _position_clear(p, null):
			candidates.append(p)
	return candidates[_rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else Vector3.ZERO


func clear_all_items() -> void:
	var root := get_node_or_null(TEST_POINTS_PATH)
	if root == null:
		return
	for child in root.get_children():
		if child is Node3D and not String(child.get_meta("item_type", "")).is_empty():
			var item := child as Node3D
			item.visible = false
			item.set_meta("in_inventory", false)
			_set_collision_enabled(item, false)


func _despawn_expired_ground_items() -> void:
	if ground_despawn_seconds <= 0.0 or _is_network_client():
		return
	var root := get_node_or_null(TEST_POINTS_PATH)
	if root == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for child in root.get_children():
		if child is Node3D:
			var item := child as Node3D
			if not item.visible or bool(item.get_meta("in_inventory", false)):
				continue
			var spawned := float(item.get_meta("spawned_at", 0.0))
			if spawned > 0.0 and now - spawned >= ground_despawn_seconds:
				item.visible = false
				_set_collision_enabled(item, false)
				if String(item.get_meta("item_type", "")) == "paper" and _game != null:
					_game.call_deferred("unregister_spawned_paper")


func _lowest_mesh_y(item: Node3D) -> float:
	var inv := item.global_transform.affine_inverse()
	var lowest := INF
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(item, meshes)
	for m in meshes:
		if m.mesh == null:
			continue
		var local_to_root := inv * m.global_transform
		var a := m.get_aabb()
		for x in [0, 1]:
			for y in [0, 1]:
				for z in [0, 1]:
					var corner := a.position + Vector3(a.size.x if x == 1 else 0.0,
						a.size.y if y == 1 else 0.0, a.size.z if z == 1 else 0.0)
					lowest = minf(lowest, (local_to_root * corner).y)
	return lowest if lowest != INF else 0.0


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child as MeshInstance3D)
		_collect_meshes(child, result)


func _set_collision_enabled(node: Node, enabled: bool) -> void:
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		body.collision_layer = 1 if enabled else 0
		body.collision_mask = 1 if enabled else 0
		body.input_ray_pickable = enabled
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = not enabled
	for child in node.get_children():
		_set_collision_enabled(child, enabled)


func _position_clear(p: Vector3, ignore: Node3D) -> bool:
	var root := get_node_or_null(TEST_POINTS_PATH)
	if root == null:
		return true
	for child in root.get_children():
		if not child is Node3D:
			continue
		var other := child as Node3D
		if other == ignore or not other.visible or bool(other.get_meta("in_inventory", false)):
			continue
		if p.distance_to(other.global_position) < minimum_spawn_separation:
			return false
	return true


func _count_active_items() -> int:
	var count := 0
	var root := get_node_or_null(TEST_POINTS_PATH)
	if root == null:
		return 0
	for child in root.get_children():
		if child is Node3D:
			var item := child as Node3D
			if not String(item.get_meta("item_type", "")).is_empty() and item.visible and not bool(item.get_meta("in_inventory", false)):
				count += 1
	return count


func _count_active_type(t: String) -> int:
	var count := 0
	var root := get_node_or_null(TEST_POINTS_PATH)
	if root == null:
		return 0
	for child in root.get_children():
		if child is Node3D:
			var item := child as Node3D
			if String(item.get_meta("item_type", "")) == t and item.visible and not bool(item.get_meta("in_inventory", false)):
				count += 1
	return count

