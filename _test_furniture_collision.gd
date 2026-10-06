extends SceneTree
func _init():
    var ps=load("res://main.tscn") as PackedScene
    var root_scene=ps.instantiate()
    get_root().add_child(root_scene)
    await process_frame
    var k=root_scene.get_node("Furniture/Kelas_10_A_Furniture")
    var desk=k.get_node("FurnitureRoot/StudentDesks/Desk_01")
    var cs=desk.get_node("FurnitureCollision/CollisionShape3D") as CollisionShape3D
    print("DESK_GLOBAL=",desk.global_position)
    print("COLLISION_GLOBAL=",cs.global_position)
    print("SHAPE=",cs.shape)
    print("DISABLED=",cs.disabled)
    var q=PhysicsShapeQueryParameters3D.new()
    q.shape=CapsuleShape3D.new()
    q.shape.radius=0.45
    q.shape.height=1.6
    q.transform=Transform3D(Basis.IDENTITY,desk.global_position+Vector3(0,0.5,0))
    q.collision_mask=1
    var hits=root_scene.get_world_3d().direct_space_state.intersect_shape(q,32)
    print("HITS_AT_DESK=",hits.size())
    var bench=root_scene.get_node_or_null("Furniture/BangkuLorong_01")
    print("BENCH_INSTANCE=",bench)
    quit()
