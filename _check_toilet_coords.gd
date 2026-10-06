extends SceneTree
func bb(n):
 var m=n as VisualInstance3D; if m==null: return
 var a=m.get_aabb(); var t=m.global_transform;var mn=Vector3(INF,INF,INF);var mx=Vector3(-INF,-INF,-INF)
 for c in [a.position,a.position+Vector3(a.size.x,0,0),a.position+Vector3(0,a.size.y,0),a.position+Vector3(0,0,a.size.z),a.position+Vector3(a.size.x,a.size.y,0),a.position+Vector3(a.size.x,0,a.size.z),a.position+Vector3(0,a.size.y,a.size.z),a.position+a.size]:
  var q=t*c;mn.x=min(mn.x,q.x);mn.y=min(mn.y,q.y);mn.z=min(mn.z,q.z);mx.x=max(mx.x,q.x);mx.y=max(mx.y,q.y);mx.z=max(mx.z,q.z)
 print(n.get_path()," pos=",n.global_position," min=",mn," max=",mx)
func _init():
 var p=load("res://main.tscn");var s=p.instantiate();root.add_child(s)
 print("MAP GLOBAL=",s.get_node("Map58").global_position," FURN GLOBAL=",s.get_node("Furniture").global_position)
 var mf=s.get_node("Map58")
 for nm in ["Toilet_Pria_Floor","Toilet_Wanita_Floor"]:
  var n=mf.find_child(nm,true,false);if n:bb(n)
 var ft=s.get_node("Furniture/MaleToilet_Furniture")
 print("TOILET FURN GLOBAL=",ft.global_position)
 print("TOILET LOCAL=",ft.position)
 print("MAIN CHILD TRANSFORM=",ft.global_transform)
 quit()
