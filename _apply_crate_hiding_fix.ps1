$ErrorActionPreference = 'Stop'
Set-Location 'C:\Users\LENOVO\Documents\prototipe-1'
$stamp = '20261011'
Copy-Item 'Warehouse_Furniture.tscn' "Warehouse_Furniture.tscn.pre_crate_animation_$stamp.bak" -Force
Copy-Item 'Map58CrateHiding.gd' "Map58CrateHiding.gd.pre_crate_animation_$stamp.bak" -Force
Copy-Item 'Player.gd' "Player.gd.pre_crate_hiding_$stamp.bak" -Force
$scene = Get-Content 'Warehouse_Furniture.tscn' -Raw
$marker = '[node name="LargeStorageCrate" type="Node3D" parent="FurnitureRoot" unique_id=1414160753]'
if (-not $scene.Contains($marker)) { throw 'LargeStorageCrate node marker not found; aborting.' }
if ($scene.Contains('id="crate_wall_front"')) { throw 'Crate geometry patch already present; aborting to avoid duplicate resources.' }
$resources = @'
[sub_resource type="BoxMesh" id="crate_wall_front"]
material = SubResource("MatCrate")
size = Vector3(3.2, 1.72, 0.12)

[sub_resource type="BoxMesh" id="crate_wall_side"]
material = SubResource("MatCrate")
size = Vector3(0.12, 1.72, 1.6)

[sub_resource type="BoxMesh" id="crate_floor"]
material = SubResource("MatCrateDark")
size = Vector3(3.2, 0.16, 1.6)

[sub_resource type="BoxMesh" id="crate_lid"]
material = SubResource("MatCrate")
size = Vector3(3.2, 0.16, 1.6)

[sub_resource type="BoxShape3D" id="crate_floor_collision"]
size = Vector3(3.2, 0.16, 1.6)

[sub_resource type="BoxShape3D" id="crate_front_collision"]
size = Vector3(3.2, 1.72, 0.12)

[sub_resource type="BoxShape3D" id="crate_back_collision"]
size = Vector3(3.2, 1.72, 0.12)

[sub_resource type="BoxShape3D" id="crate_side_collision"]
size = Vector3(0.12, 1.72, 1.6)

'@
$scene = $scene.Replace($marker, $resources + $marker)
$oldBody = @'
[node name="Body" type="MeshInstance3D" parent="FurnitureRoot/LargeStorageCrate" unique_id=1252152273]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.95, 0)
mesh = SubResource("crate_body")
'@
$newBody = @'
[node name="Body" type="MeshInstance3D" parent="FurnitureRoot/LargeStorageCrate" unique_id=1252152273]
visible = false
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.95, 0)
mesh = SubResource("crate_body")

[node name="Floor" type="MeshInstance3D" parent="FurnitureRoot/LargeStorageCrate"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.08, 0)
mesh = SubResource("crate_floor")

[node name="FrontWall" type="MeshInstance3D" parent="FurnitureRoot/LargeStorageCrate"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.86, -0.74)
mesh = SubResource("crate_wall_front")

[node name="BackWall" type="MeshInstance3D" parent="FurnitureRoot/LargeStorageCrate"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.86, 0.74)
mesh = SubResource("crate_wall_front")

[node name="LeftWall" type="MeshInstance3D" parent="FurnitureRoot/LargeStorageCrate"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.54, 0.86, 0)
mesh = SubResource("crate_wall_side")

[node name="RightWall" type="MeshInstance3D" parent="FurnitureRoot/LargeStorageCrate"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.54, 0.86, 0)
mesh = SubResource("crate_wall_side")

[node name="LidPivot" type="Node3D" parent="FurnitureRoot/LargeStorageCrate"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.9, 0.74)

[node name="Lid" type="MeshInstance3D" parent="FurnitureRoot/LargeStorageCrate/LidPivot"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.08, -0.74)
mesh = SubResource("crate_lid")
'@
if (-not $scene.Contains($oldBody)) { throw 'Expected Body block not found; aborting.' }
$scene = $scene.Replace($oldBody, $newBody)
$oldBandTop = @'
[node name="BandTop" type="MeshInstance3D" parent="FurnitureRoot/LargeStorageCrate" unique_id=4573639]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.78, 0)
mesh = SubResource("crate_band_h")
'@
$newBandTop = @'
[node name="BandTop" type="MeshInstance3D" parent="FurnitureRoot/LargeStorageCrate/LidPivot" unique_id=4573639]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.08, -0.74)
mesh = SubResource("crate_band_h")
'@
if (-not $scene.Contains($oldBandTop)) { throw 'Expected BandTop block not found; aborting.' }
$scene = $scene.Replace($oldBandTop, $newBandTop)
$oldCollision = @'
[node name="CollisionShape3D" type="CollisionShape3D" parent="FurnitureRoot/LargeStorageCrate/FurnitureCollision" unique_id=1395409658]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.95, -0.0024999976)
shape = SubResource("BoxShape3D_wf87g")
'@
$newCollision = @'
[node name="CollisionShape3D" type="CollisionShape3D" parent="FurnitureRoot/LargeStorageCrate/FurnitureCollision" unique_id=1395409658]
disabled = true
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.95, -0.0024999976)
shape = SubResource("BoxShape3D_wf87g")

[node name="CrateFloorCollision" type="CollisionShape3D" parent="FurnitureRoot/LargeStorageCrate/FurnitureCollision"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.08, 0)
shape = SubResource("crate_floor_collision")

[node name="CrateFrontCollision" type="CollisionShape3D" parent="FurnitureRoot/LargeStorageCrate/FurnitureCollision"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.86, -0.74)
shape = SubResource("crate_front_collision")

[node name="CrateBackCollision" type="CollisionShape3D" parent="FurnitureRoot/LargeStorageCrate/FurnitureCollision"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.86, 0.74)
shape = SubResource("crate_back_collision")

[node name="CrateLeftCollision" type="CollisionShape3D" parent="FurnitureRoot/LargeStorageCrate/FurnitureCollision"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.54, 0.86, 0)
shape = SubResource("crate_side_collision")

[node name="CrateRightCollision" type="CollisionShape3D" parent="FurnitureRoot/LargeStorageCrate/FurnitureCollision"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.54, 0.86, 0)
shape = SubResource("crate_side_collision")
'@
if (-not $scene.Contains($oldCollision)) { throw 'Expected crate collision block not found; aborting.' }
$scene = $scene.Replace($oldCollision, $newCollision)
$tempScene = 'Warehouse_Furniture.tscn.crate_patch.tmp'
Set-Content $tempScene -Value $scene -NoNewline -Encoding utf8
Move-Item -LiteralPath $tempScene -Destination 'Warehouse_Furniture.tscn' -Force
$script = @'
extends Area3D

## Interaksi bersembunyi di peti gudang. Tutup berengsel dan menyisakan celah pandang kecil.

const LID_CLOSED_ROTATION := Vector3(-0.055, 0.0, 0.0)
const LID_OPEN_ROTATION := Vector3(-1.62, 0.0, 0.0)
const LID_ANIMATION_TIME := 0.42

var _crate: Node3D
var _lid_pivot: Node3D
var _busy := false
var _hidden_player: CharacterBody3D
var _saved_transform: Transform3D
var _saved_camera_position := Vector3.ZERO
var _saved_camera_rotation := Vector3.ZERO
var _saved_physics_process := true
var _saved_collision_disabled := false
var _saved_visibility: Dictionary = {}


func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    monitoring = true
    monitorable = true
    add_to_group("map58_hiding_spot")
    set_meta("interaction_type", "hiding")
    _crate = get_parent() as Node3D
    if _crate != null:
        _lid_pivot = _crate.get_node_or_null("LidPivot") as Node3D
        if _lid_pivot != null:
            _lid_pivot.rotation = LID_CLOSED_ROTATION


func toggle_hide(player: Node = null) -> void:
    if _busy or player == null or not player is CharacterBody3D:
        return
    var character := player as CharacterBody3D
    if _hidden_player == character:
        _exit_crate(character)
        return
    if bool(character.get_meta("is_hidden", false)) or _hidden_player != null:
        return
    _enter_crate(character)


func _enter_crate(player: CharacterBody3D) -> void:
    if _crate == null or _lid_pivot == null:
        _set_status(player, "Peti belum siap digunakan.")
        return

    _busy = true
    _hidden_player = player
    _saved_transform = player.global_transform
    _saved_physics_process = player.is_physics_processing()
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    var player_collision := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if camera != null:
        _saved_camera_position = camera.position
        _saved_camera_rotation = camera.rotation
    if player_collision != null:
        _saved_collision_disabled = player_collision.disabled
        player_collision.set_deferred("disabled", true)

    _saved_visibility.clear()
    _save_visibility_recursive(player)
    player.velocity = Vector3.ZERO
    player.set_meta("is_hidden", true)
    player.set_meta("hide_spot", self)
    player.set_physics_process(false)

    await _animate_lid(true)
    player.global_transform = _crate.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.12, 0.0))
    if camera != null:
        # Kamera menghadap panel depan; celah di bawah tutup memberi garis pandang ke luar.
        camera.position = Vector3(0.0, 1.43, -0.10)
        camera.rotation = Vector3(-0.20, 0.0, 0.0)
    _set_player_meshes_visible(player, false)
    await _animate_lid(false)
    _set_status(player, "Kamu bersembunyi di dalam peti. Klik kanan untuk keluar.")
    _busy = false


func _exit_crate(player: CharacterBody3D) -> void:
    _busy = true
    await _animate_lid(true)
    _set_player_meshes_visible(player, true)
    player.set_physics_process(false)
    player.global_transform = _saved_transform
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    if camera != null:
        camera.position = _saved_camera_position
        camera.rotation = _saved_camera_rotation
    var player_collision := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if player_collision != null:
        player_collision.set_deferred("disabled", _saved_collision_disabled)
    player.velocity = Vector3.ZERO
    player.set_meta("is_hidden", false)
    player.set_meta("hide_spot", null)
    player.set_physics_process(_saved_physics_process)
    _hidden_player = null
    _set_status(player, "Kamu keluar dari peti.")
    await _animate_lid(false)
    _busy = false


func _animate_lid(open_value: bool) -> void:
    if _lid_pivot == null:
        return
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(
        _lid_pivot,
        "rotation",
        LID_OPEN_ROTATION if open_value else LID_CLOSED_ROTATION,
        LID_ANIMATION_TIME
    )
    await tween.finished


func _save_visibility_recursive(node: Node) -> void:
    for child in node.get_children():
        if child is VisualInstance3D:
            _saved_visibility[child.get_instance_id()] = [child, child.visible]
        _save_visibility_recursive(child)


func _set_player_meshes_visible(player: Node, visible_value: bool) -> void:
    for entry in _saved_visibility.values():
        var node: Node = entry[0]
        if is_instance_valid(node):
            node.visible = bool(entry[1]) if visible_value else false


func _set_status(player: CharacterBody3D, message: String) -> void:
    var inventory := player.get_node_or_null("ItemInventory")
    if inventory != null and inventory.has_method("_set_status"):
        inventory.call("_set_status", message)
'@
Set-Content 'Map58CrateHiding.gd' -Value $script -NoNewline -Encoding utf8
$playerScript = Get-Content 'Player.gd' -Raw
$pattern = '(?m)^(func _unhandled_input\(event: InputEvent\) -> void:\r?\n)(\s*# Input tetap dikunci saat cutscene/drag; pemain KO boleh melihat arah merangkak\.)'
if (-not [regex]::IsMatch($playerScript, $pattern)) { throw 'Player input function marker not found; backups exist, aborting Player.gd edit.' }
$nl = [Environment]::NewLine
$insert = '$1    # Kamera dikunci ke celah peti selama bersembunyi.' + $nl + '    if bool(get_meta("is_hidden", false)):' + $nl + '        return' + $nl + '    # Input tetap dikunci saat cutscene/drag; pemain KO boleh melihat arah merangkak.'
$playerScript = [regex]::Replace($playerScript, $pattern, $insert, 1)
$tempPlayer = 'Player.gd.crate_patch.tmp'
Set-Content $tempPlayer -Value $playerScript -NoNewline -Encoding utf8
Move-Item -LiteralPath $tempPlayer -Destination 'Player.gd' -Force
Write-Output 'Patched crate scene and hiding script.'
Write-Output ('Rack count: ' + (Select-String -Path 'Warehouse_Furniture.tscn' -Pattern '\[node name="Rack_').Count)
Write-Output ('Crate lid pivot count: ' + (Select-String -Path 'Warehouse_Furniture.tscn' -Pattern '\[node name="LidPivot"').Count)
Write-Output ('Crate collision count: ' + (Select-String -Path 'Warehouse_Furniture.tscn' -Pattern '\[node name="Crate.*Collision"').Count)
