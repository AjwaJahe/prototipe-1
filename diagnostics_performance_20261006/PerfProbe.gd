extends SceneTree

var elapsed := 0.0
var last := -1
var next_report := 0.0

func _initialize() -> void:
    seed(12345)
    change_scene_to_file("res://main.tscn")

func _process(delta: float) -> bool:
    elapsed += delta
    if elapsed >= next_report:
        print("PIPELINE ", JSON.stringify({
            "t": elapsed,
            "fps": Performance.get_monitor(Performance.TIME_FPS),
            "frame_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
            "canvas": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
            "mesh": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
            "surface": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
            "draw": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
            "specialization": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION),
            "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
        }))
        next_report += 0.5
    if elapsed >= 6.0:
        quit()
    return false
