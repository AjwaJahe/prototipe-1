extends Node3D

@export var flicker_enabled: bool = true

var _rng := RandomNumberGenerator.new()
var _timer := 1.6
var _flicker_lights: Array[OmniLight3D] = []
var _base_energy: Array[float] = []

const FLICKER_PATHS := [
	"CorridorLights/Corridor_North_02",
	"CorridorLights/Corridor_Mid_02",
	"CorridorLights/Corridor_South_02",
	"CorridorLights/LeftWing_01",
	"CorridorLights/BackHall",
	"RoomLights/Gudang/Light",
	"RoomLights/ToiletSketsel/Light"
]

func _ready() -> void:
	_rng.seed = 5802026

	for path in FLICKER_PATHS:
		var light := get_node_or_null(path) as OmniLight3D
		if light != null:
			_flicker_lights.append(light)
			_base_energy.append(light.light_energy)

	set_process(flicker_enabled)

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or _flicker_lights.is_empty():
		return

	var index := _rng.randi_range(0, _flicker_lights.size() - 1)
	var light := _flicker_lights[index]
	var base := _base_energy[index]
	var mode := _rng.randi_range(0, 2)

	if mode == 0:
		light.light_energy = 0.0
		_restore_after(light, base, _rng.randf_range(0.05, 0.11))
	elif mode == 1:
		light.light_energy = base * _rng.randf_range(0.20, 0.45)
		_restore_after(light, base, _rng.randf_range(0.08, 0.18))
	else:
		light.light_energy = base * _rng.randf_range(0.50, 0.75)
		_restore_after(light, base, _rng.randf_range(0.10, 0.22))

	_timer = _rng.randf_range(1.4, 4.2)

func _restore_after(light: OmniLight3D, base: float, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(light):
		light.light_energy = base
