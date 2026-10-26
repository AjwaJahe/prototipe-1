extends Control
## Minimap 2D yang menggambar area walkable dari NavigationMesh Map58.

var navigation_region: NavigationRegion3D
var player_node: Node3D
var teacher_node: Node3D

const MAP_PADDING := 5.0
const PLAYER_COLOR := Color(0.25, 1.0, 0.38, 1.0)
const FLOOR_COLOR := Color(0.47, 0.27, 0.17, 1.0)
const EDGE_COLOR := Color(0.96, 0.91, 0.80, 1.0)

var _map_polygons: Array[PackedVector2Array] = []
var _map_walls: Array[PackedVector2Array] = []
var _world_min := Vector2.ZERO
var _world_max := Vector2.ONE
var _cached_vertex_count := -1
var _cached_polygon_count := -1
var _redraw_timer := 0.0
var _last_players_map_positions: Dictionary = {}
var _last_control_size := Vector2.ZERO
var _geometry_ready := false


func _ready() -> void:
	custom_minimum_size = Vector2(170, 170)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	if size != _last_control_size:
		_last_control_size = size
		if is_instance_valid(navigation_region) and navigation_region.navigation_mesh != null:
			_rebuild_map_geometry()
			queue_redraw()
		return
	if not _geometry_ready:
		if is_instance_valid(navigation_region) and navigation_region.navigation_mesh != null:
			_rebuild_map_geometry()
			queue_redraw()
		return
	_redraw_timer -= delta
	if _redraw_timer > 0.0:
		return
	_redraw_timer = 0.25
	var current_positions: Dictionary = {}
	var moved := false
	for player in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(player) or not player is Node3D:
			continue
		var player_3d := player as Node3D
		var map_pos := _world_to_map(Vector2(player_3d.global_position.x, player_3d.global_position.z))
		var player_id := player_3d.get_instance_id()
		current_positions[player_id] = map_pos
		if not _last_players_map_positions.has(player_id) or map_pos.distance_squared_to(_last_players_map_positions[player_id]) > 1.0:
			moved = true
	if current_positions.size() != _last_players_map_positions.size():
		moved = true
	if moved:
		_last_players_map_positions = current_positions
		queue_redraw()

func _rebuild_map_geometry() -> void:
	_map_polygons.clear()
	_map_walls.clear()
	_geometry_ready = false
	if not is_instance_valid(navigation_region) or navigation_region.navigation_mesh == null:
		return
	var nav := navigation_region.navigation_mesh
	var vertices: PackedVector3Array = nav.get_vertices()
	_cached_vertex_count = vertices.size()
	_cached_polygon_count = nav.get_polygon_count()
	if vertices.is_empty():
		return

	_world_min = Vector2(INF, INF)
	_world_max = Vector2(-INF, -INF)
	var world_vertices := PackedVector2Array()
	world_vertices.resize(vertices.size())
	for i in range(vertices.size()):
		var world_pos := navigation_region.to_global(vertices[i])
		var point := Vector2(world_pos.x, world_pos.z)
		world_vertices[i] = point
		_world_min.x = minf(_world_min.x, point.x)
		_world_min.y = minf(_world_min.y, point.y)
		_world_max.x = maxf(_world_max.x, point.x)
		_world_max.y = maxf(_world_max.y, point.y)

	# Draw walkable floor and only external polygon edges, hiding triangulation lines.
	var edge_counts: Dictionary = {}
	for polygon_index in range(nav.get_polygon_count()):
		var polygon_indices: PackedInt32Array = nav.get_polygon(polygon_index)
		var polygon := PackedVector2Array()
		for vertex_index in polygon_indices:
			if vertex_index >= 0 and vertex_index < world_vertices.size():
				polygon.append(_world_to_map(world_vertices[vertex_index]))
		if polygon.size() >= 3:
			_map_polygons.append(polygon)
		for edge_index in range(polygon_indices.size()):
			var a: int = polygon_indices[edge_index]
			var b: int = polygon_indices[(edge_index + 1) % polygon_indices.size()]
			if a < 0 or b < 0 or a >= world_vertices.size() or b >= world_vertices.size():
				continue
			var edge_key := "%d:%d" % [mini(a, b), maxi(a, b)]
			if edge_counts.has(edge_key):
				edge_counts[edge_key]["count"] += 1
			else:
				edge_counts[edge_key] = {"count": 1, "a": a, "b": b}
	for edge_data in edge_counts.values():
		if int(edge_data["count"]) == 1:
			var wall := PackedVector2Array()
			wall.append(_world_to_map(world_vertices[int(edge_data["a"])]))
			wall.append(_world_to_map(world_vertices[int(edge_data["b"])]))
			_map_walls.append(wall)
	_geometry_ready = true


func _world_to_map(world_point: Vector2) -> Vector2:
	var available := size - Vector2.ONE * MAP_PADDING * 2.0
	var span := _world_max - _world_min
	span.x = maxf(span.x, 0.01)
	span.y = maxf(span.y, 0.01)
	var scale_factor := minf(available.x / span.x, available.y / span.y)
	var drawn_size := span * scale_factor
	var offset := (size - drawn_size) * 0.5
	return offset + (world_point - _world_min) * scale_factor


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.10, 0.07, 1.0), true)
	if _map_polygons.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(10, size.y * 0.5), "Peta dimuat...", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		return
	draw_rect(Rect2(Vector2(MAP_PADDING, MAP_PADDING), size - Vector2(MAP_PADDING * 2.0, MAP_PADDING * 2.0)), FLOOR_COLOR, true)
	for wall in _map_walls:
		draw_line(wall[0], wall[1], EDGE_COLOR, 1.2, true)

	# Tampilkan semua avatar pemain yang terdaftar, termasuk pemain remote multiplayer.
	# Guru sengaja tidak digambar pada minimap.
	for player in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(player) or not player is Node3D:
			continue
		var player_3d := player as Node3D
		var player_pos := _world_to_map(Vector2(player_3d.global_position.x, player_3d.global_position.z))
		draw_circle(player_pos, 3.2, PLAYER_COLOR)
		draw_arc(player_pos, 4.8, 0.0, TAU, 20, Color(0.03, 0.05, 0.04), 1.0)
