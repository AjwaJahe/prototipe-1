extends Camera3D

# Menyembunyikan kepala/rambut HANYA dari kamera pemain yang memilikinya.
# Tidak mengubah Map58, collision, movement, atau Player.gd.
# Pemain lain tetap melihat kepala/rambut karakter ini secara normal.

const LOCAL_ONLY_LAYER_BIT := 1 # visual layer 2 (bit index 1)

const HIDDEN_PARTS := [
	"Head",
	"Hair_Cap",
	"Fringe_0",
	"Fringe_1",
	"Fringe_2",
	"Fringe_3",
	"Fringe_4",
	"Eye_L",
	"Eye_R",
	"Brow_L",
	"Brow_R",
	"Ear_L",
	"Ear_R",
    "Neck"
]

func _ready() -> void:
	# Pada single-player/offline, authority default juga pemain lokal.
	if not get_parent().is_multiplayer_authority():
		return

	# Kamera lokal tidak merender layer 2.
	cull_mask &= ~(1 << LOCAL_ONLY_LAYER_BIT)

	var player_visual := get_parent().get_node_or_null("PlayerVisual")
	if player_visual == null:
		push_warning("FirstPersonLocalHeadCulling: node PlayerVisual tidak ditemukan.")
		return

	_move_local_head_to_private_layer(player_visual)

func _move_local_head_to_private_layer(node: Node) -> void:
	if node is VisualInstance3D and node.name in HIDDEN_PARTS:
		node.layers = (1 << LOCAL_ONLY_LAYER_BIT)

	for child in node.get_children():
		_move_local_head_to_private_layer(child)
