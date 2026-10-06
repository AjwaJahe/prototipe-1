@tool
extends Node3D

## Mode editor ringan Map58.
## Tidak mengubah posisi, mesh, collision, atau scene furniture.
## Hanya menyembunyikan kelompok berat saat main.tscn dibuka di editor.

@export_category("Map58 Editor Performance")
@export var show_heavy_furniture: bool = false:
	set(value):
		show_heavy_furniture = value
		_apply_editor_visibility()

@export var show_editor_lighting: bool = false:
	set(value):
		show_editor_lighting = value
		_apply_editor_visibility()


func _ready() -> void:
	_apply_editor_visibility()


func _apply_editor_visibility() -> void:
	if not Engine.is_editor_hint():
		_set_node_visible("Furniture", true)
		_set_node_visible("BasketballBleachers", true)
		_set_node_visible("BasketballCourt", true)
		_set_node_visible("Map58_AdditionalLighting", true)
		_set_node_visible("Map58_Lighting", true)
		return

	var heavy_visible := show_heavy_furniture
	_set_node_visible("Furniture", heavy_visible)
	_set_node_visible("BasketballBleachers", heavy_visible)
	_set_node_visible("BasketballCourt", heavy_visible)

	var lighting_visible := show_editor_lighting
	_set_node_visible("Map58_AdditionalLighting", lighting_visible)
	_set_node_visible("Map58_Lighting", lighting_visible)


func _set_node_visible(node_name: String, value: bool) -> void:
	var target := get_node_or_null(node_name) as Node3D
	if target != null:
		target.visible = value
