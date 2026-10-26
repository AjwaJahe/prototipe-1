extends SceneTree
func _initialize() -> void:
    var stream = load("res://assets/audio/footsteps/footstep_walk.ogg") as AudioStream
    print("FOOTSTEP_LENGTH_SECONDS=", stream.get_length() if stream != null else -1.0)
    quit()
