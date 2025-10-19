extends Marker2D
class_name Node2DFactory

signal created(product)

@export var product_packed_scene: PackedScene
@export var target_container_name: StringName

func create(_product_packed_scene := product_packed_scene) -> Node2D:
	var product: Node2D = _product_packed_scene.instantiate()
	var container = find_parent("Stage").find_child(target_container_name)
	container.add_child(product)
	product.global_position = global_position 
	print(product.global_position)
	created.emit(product)
	return product
