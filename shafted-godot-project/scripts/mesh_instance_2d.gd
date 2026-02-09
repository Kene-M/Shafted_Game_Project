extends MeshInstance2D
var vertices: PackedVector2Array = []
var indices: PackedInt32Array = []

func _ready():
	vertices.append(Vector2(0, 0))    
	vertices.append(Vector2(100, 0))   
	vertices.append(Vector2(100, 100))  
	vertices.append(Vector2(0, 100))   

	indices.append(0)
	indices.append(1)
	indices.append(2)
	indices.append(0)
	indices.append(2)
	indices.append(3)

	create_mesh()
	
func create_mesh():
	var array_mesh = ArrayMesh.new()
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_INDEX] = indices 
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	mesh = array_mesh
