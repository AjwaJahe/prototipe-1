extends SceneTree
func _init():
 var f=FileAccess.open("res://__write_test_out.txt", FileAccess.WRITE)
 f.store_string("TEST_OK")
 f.close()
 quit()
