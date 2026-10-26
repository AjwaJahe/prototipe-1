extends Node3D

@export var student_spawn_height: float = 1.0
@export var random_student_spawn: bool = true


@onready var player_body: CharacterBody3D = get_node_or_null(
	"../Player/CharacterBody3D"
) as CharacterBody3D
@onready var student_spawns: Node3D = get_node_or_null(
	"StudentSpawns"
) as Node3D
@onready var teacher_spawn: Marker3D = get_node_or_null(
	"TeacherSpawn"
) as Marker3D


func _ready() -> void:
	call_deferred("_place_initial_spawns")


func _place_initial_spawns() -> void:
	_place_student()
	_print_teacher_spawn()


func _place_student() -> void:
	if player_body == null:
		push_error("Map58 SpawnManager: Player/CharacterBody3D tidak ditemukan.")
		return

	var multiplayer_active := bool(get_tree().get_meta("kelas_malam_multiplayer_active", false)) and multiplayer.multiplayer_peer != null
	var peer_id := multiplayer.get_unique_id() if multiplayer_active else 1
	var spawn_position := get_spawn_position_for_peer(peer_id) if multiplayer_active else _get_singleplayer_spawn_position()
	if spawn_position == Vector3.ZERO:
		push_error("Map58 SpawnManager: tidak menemukan kursi spawn di Kelas 10 A.")
		return

	player_body.global_position = spawn_position
	player_body.velocity = Vector3.ZERO
	player_body.set_meta("intro_spawn_marker_name", "Kelas_10_A")
	print("Map58 student spawn | Kelas_10_A | peer=", peer_id, " | ", player_body.global_position)


func get_spawn_position_for_peer(peer_id: int) -> Vector3:
	var chairs := _get_class_chairs()
	if not chairs.is_empty():
		var index := posmod(absi(peer_id * 7919), chairs.size())
		return chairs[index].global_position + Vector3.UP * student_spawn_height
	var marker := get_node_or_null("StudentSpawns/Kelas_10_A") as Marker3D
	if marker != null:
		return marker.global_position + Vector3.UP * student_spawn_height
	return Vector3.ZERO


func _get_singleplayer_spawn_position() -> Vector3:
	var chairs := _get_class_chairs()
	if not chairs.is_empty():
		var index := randi() % chairs.size() if random_student_spawn else 0
		return chairs[index].global_position + Vector3.UP * student_spawn_height
	var marker := get_node_or_null("StudentSpawns/Kelas_10_A") as Marker3D
	return marker.global_position + Vector3.UP * student_spawn_height if marker != null else Vector3.ZERO


func _get_class_chairs() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var class_root := get_node_or_null("../Furniture/Kelas_10_A_Furniture") as Node
	if class_root == null:
		return result
	var stack: Array[Node] = [class_root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Node3D and String(current.name).begins_with("Chair_"):
			result.append(current as Node3D)
		for child in current.get_children():
			stack.append(child)
	result.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.name) < String(b.name))
	return result

func _print_teacher_spawn() -> void:
	if teacher_spawn == null:
		push_error("Map58 SpawnManager: TeacherSpawn tidak ditemukan.")
		return

	print(
		"Map58 teacher spawn | Ruang Guru | ",
		teacher_spawn.global_position
	)
