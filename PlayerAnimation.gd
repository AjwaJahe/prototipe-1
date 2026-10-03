extends Node

@export var walk_cycle_speed: float = 8.0
@export var run_cycle_speed: float = 13.0
@export var swing_degrees: float = 28.0
@export var body_bob_height: float = 0.035

var time_value := 0.0

@onready var body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var visual: Node3D = body.get_node_or_null("PlayerCharacter/world") as Node3D
@onready var leg_l: Node3D = visual.get_node_or_null("Leg_L") as Node3D
@onready var leg_r: Node3D = visual.get_node_or_null("Leg_R") as Node3D
@onready var arm_l: Node3D = visual.get_node_or_null("Arm_L") as Node3D
@onready var arm_r: Node3D = visual.get_node_or_null("Arm_R") as Node3D
@onready var torso: Node3D = visual.get_node_or_null("Torso") as Node3D

var leg_l_base := Vector3.ZERO
var leg_r_base := Vector3.ZERO
var arm_l_base := Vector3.ZERO
var arm_r_base := Vector3.ZERO
var torso_base_y := 0.0

func _ready() -> void:
    if leg_l: leg_l_base = leg_l.rotation
    if leg_r: leg_r_base = leg_r.rotation
    if arm_l: arm_l_base = arm_l.rotation
    if arm_r: arm_r_base = arm_r.rotation
    if torso: torso_base_y = torso.position.y

func _process(delta: float) -> void:
    if body == null or visual == null:
        return

    var horizontal_speed := Vector2(body.velocity.x, body.velocity.z).length()
    var moving := horizontal_speed > 0.15 and body.is_on_floor()
    var running := Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_CTRL)

    if moving:
        var cycle_speed := run_cycle_speed if running else walk_cycle_speed
        var swing := sin(time_value * cycle_speed) * deg_to_rad(swing_degrees)
        var arm_swing := -swing

        if leg_l: leg_l.rotation = leg_l_base + Vector3(swing, 0.0, 0.0)
        if leg_r: leg_r.rotation = leg_r_base + Vector3(-swing, 0.0, 0.0)
        if arm_l: arm_l.rotation = arm_l_base + Vector3(arm_swing, 0.0, 0.0)
        if arm_r: arm_r.rotation = arm_r_base + Vector3(-arm_swing, 0.0, 0.0)
        if torso:
            torso.position.y = torso_base_y + sin(time_value * cycle_speed * 2.0) * body_bob_height

        time_value += delta
    else:
        var settle := exp(-delta * 10.0)
        if leg_l: leg_l.rotation = leg_l.rotation.lerp(leg_l_base, settle)
        if leg_r: leg_r.rotation = leg_r.rotation.lerp(leg_r_base, settle)
        if arm_l: arm_l.rotation = arm_l.rotation.lerp(arm_l_base, settle)
        if arm_r: arm_r.rotation = arm_r.rotation.lerp(arm_r_base, settle)
        if torso:
            torso.position.y = lerp(torso.position.y, torso_base_y, settle)
        time_value = 0.0
