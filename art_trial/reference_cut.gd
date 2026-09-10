class_name ReferenceCut
extends RefCounted
## One convex art-mesh cut. Interpolates original normals and UVs; caps are flat.
const EPS := 0.00001

static func clip(mesh: Mesh, plane: Plane, surface: Material, cap: Material) -> ArrayMesh:
 var tool := SurfaceTool.new()
 tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 tool.set_material(surface)
 var crossings: Array[Vector3] = []
 for surface_index: int in mesh.get_surface_count():
  var arrays := mesh.surface_get_arrays(surface_index)
  var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
  var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
  var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
  if indices.is_empty():
   for index: int in vertices.size(): indices.append(index)
  for index: int in range(0,indices.size(),3):
   var polygon: Array[Dictionary] = []
   for corner: int in 3:
    var id := indices[index+corner]
    polygon.append({"p":vertices[id],"n":normals[id],"uv":uv[id] if not uv.is_empty() else Vector2.ZERO})
   _emit(tool,_clip_polygon(polygon,plane,crossings))
 var result := tool.commit()
 if crossings.size() < 3: return result
 var centre := Vector3.ZERO
 for point: Vector3 in crossings: centre += point
 centre /= crossings.size()
 var axis := plane.normal.cross(Vector3.UP).normalized()
 if axis.length_squared() < EPS: axis = Vector3.RIGHT
 var second := plane.normal.cross(axis)
 crossings.sort_custom(func(a:Vector3,b:Vector3)->bool: return atan2((a-centre).dot(second),(a-centre).dot(axis)) < atan2((b-centre).dot(second),(b-centre).dot(axis)))
 tool = SurfaceTool.new()
 tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 tool.set_material(cap)
 for index: int in crossings.size():
  # Godot front faces use clockwise winding.
  for point: Vector3 in [centre,crossings[(index+1)%crossings.size()],crossings[index]]:
   tool.set_normal(plane.normal)
   tool.set_uv(Vector2(point.dot(axis),point.dot(second)))
   tool.add_vertex(point)
 tool.commit(result)
 return result

static func _clip_polygon(polygon: Array[Dictionary],plane:Plane,crossings:Array[Vector3])->Array[Dictionary]:
 var output: Array[Dictionary] = []
 for index: int in polygon.size():
  var a := polygon[index]
  var b := polygon[(index+1)%polygon.size()]
  var da := plane.distance_to(a.p)
  var db := plane.distance_to(b.p)
  if da <= EPS: output.append(a)
  if (da < -EPS and db > EPS) or (da > EPS and db < -EPS):
   var weight := da/(da-db)
   var point: Vector3 = a.p.lerp(b.p,weight)
   output.append({"p":point,"n":a.n.lerp(b.n,weight).normalized(),"uv":a.uv.lerp(b.uv,weight)})
   var found := false
   for existing: Vector3 in crossings:
    if existing.distance_squared_to(point) < EPS*EPS: found=true; break
   if not found: crossings.append(point)
 return output

static func _emit(tool:SurfaceTool,polygon:Array[Dictionary])->void:
 for index: int in range(1,polygon.size()-1):
  for vertex: Dictionary in [polygon[0],polygon[index],polygon[index+1]]:
   tool.set_normal(vertex.n)
   tool.set_uv(vertex.uv)
   tool.add_vertex(vertex.p)
