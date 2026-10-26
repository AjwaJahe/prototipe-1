extends Camera3D

func _ready() -> void:
	# Pada single-player/offline, authority default juga pemain lokal.
	if not get_parent().is_multiplayer_authority():
		return
