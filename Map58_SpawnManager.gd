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

	if student_spawns == null:
		push_error("Map58 SpawnManager: StudentSpawns tidak ditemukan.")
		return

	var candidates: Array[Marker3D] = []

	for child in student_spawns.get_children():
		if child is Marker3D:
			candidates.append(child as Marker3D)

	if candidates.is_empty():
		push_error("Map58 SpawnManager: tidak ada spawn kelas siswa.")
		return

	var selected: Marker3D

	if random_student_spawn:
		selected = candidates[randi() % candidates.size()]
	else:
		selected = candidates[0]

	player_body.global_position = selected.global_position + Vector3.UP * student_spawn_height
	player_body.velocity = Vector3.ZERO

	print(
		"Map58 student spawn | ",
		selected.name,
		" | ",
		player_body.global_position
	)


func _print_teacher_spawn() -> void:
	if teacher_spawn == null:
		push_error("Map58 SpawnManager: TeacherSpawn tidak ditemukan.")
		return

	print(
		"Map58 teacher spawn | Ruang Guru | ",
		teacher_spawn.global_position
	)
