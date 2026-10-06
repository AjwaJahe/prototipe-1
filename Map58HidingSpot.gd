extends Area3D

## Tempat persembunyian runtime Map58.
## Area ini ditempel ke lemari/cabinet yang sudah ada tanpa mengubah mesh
## atau posisi furnitur.

func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    monitoring = true
    monitorable = true
    add_to_group("map58_hiding_spot")
    set_meta("interaction_type", "hiding")


func toggle_hide(player: Node = null) -> void:
    if player == null or not player is CharacterBody3D:
        return

    var character := player as CharacterBody3D

    if bool(character.get_meta("is_hidden", false)):
        _exit_hiding(character)
    else:
        _enter_hiding(character)


func _enter_hiding(player: CharacterBody3D) -> void:
    if bool(player.get_meta("is_hidden", false)):
        return

    player.velocity = Vector3.ZERO
    player.set_meta("is_hidden", true)
    player.set_meta("hide_spot", self)
    player.set_physics_process(false)

    _set_status(
        player,
        "Kamu bersembunyi. Guru tidak dapat melihat atau mendengar kamu."
    )


func _exit_hiding(player: CharacterBody3D) -> void:
    player.set_meta("is_hidden", false)
    player.set_meta("hide_spot", null)
    player.set_physics_process(true)

    _set_status(player, "Kamu keluar dari tempat persembunyian.")


func _set_status(player: CharacterBody3D, message: String) -> void:
    var inventory := player.get_node_or_null("ItemInventory")
    if inventory != null and inventory.has_method("_set_status"):
        inventory.call("_set_status", message)
