extends SceneTree
## Headless validation: loads every .gd, .tscn and .scn file and reports failures.
## Run: godot --headless --path . --script res://tools/validate_project.gd
## Exits with code 1 if any file fails to load.

const SKIP_DIRS := [".godot", ".git", ".github", "addons"]
## Legacy scenes whose source assets (.glb / script) are not in the repository.
const SKIP_FILES := ["res://pp32.tscn", "res://map58/Furniture_Administrasi.tscn"]
const EXTENSIONS := ["gd", "tscn", "scn"]

var _errors := 0


func _init() -> void:
	var files: Array[String] = []
	_collect("res://", files)
	files.sort()
	print("Validating %d files..." % files.size())

	for path in files:
		_check(path)

	if _errors > 0:
		printerr("VALIDATION_FAILED: %d problem(s)" % _errors)
		quit(1)
	else:
		print("VALIDATION_OK")
		quit(0)


func _collect(dir_path: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir_path):
		if f.get_extension() in EXTENSIONS and dir_path.path_join(f) not in SKIP_FILES:
			out.append(dir_path.path_join(f))
	for d in DirAccess.get_directories_at(dir_path):
		if d in SKIP_DIRS:
			continue
		_collect(dir_path.path_join(d), out)


func _check(path: String) -> void:
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		_fail(path, "failed to load (parse error or missing resource)")
		return
	if res is GDScript and not (res as GDScript).can_instantiate():
		_fail(path, "script cannot be compiled")
	elif res is PackedScene and not (res as PackedScene).can_instantiate():
		_fail(path, "scene is not valid")


func _fail(path: String, msg: String) -> void:
	_errors += 1
	printerr("FAIL %s: %s" % [path, msg])
