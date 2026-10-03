extends CharacterBody3D

@export var speed := 6.0
@export var run_speed := 10.0
@export var crouch_speed := 2.5
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.003

var gravity := 9.8
var is_crouching := false

@onready var camera := $Camera3D
@onready var collision_shape := $CollisionShape3D

var standing_height := 1.6
var crouching_height := 0.9

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Crouch toggle (tahan Ctrl)
	is_crouching = Input.is_key_pressed(KEY_CTRL)

	# Lompat tidak bisa sambil jongkok
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor() and not is_crouching:
		velocity.y = jump_velocity

	# Atur tinggi kamera & collision saat jongkok
	var target_cam_y = crouching_height if is_crouching else standing_height
	camera.position.y = lerp(camera.position.y, target_cam_y, delta * 10.0)

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	input_dir = input_dir.normalized()

	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Prioritas kecepatan: jongkok > lari > jalan normal
	var current_speed = speed
	if is_crouching:
		current_speed = crouch_speed
	elif Input.is_key_pressed(KEY_SHIFT):
		current_speed = run_speed

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
