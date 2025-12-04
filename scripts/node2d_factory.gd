extends Marker2D
class_name Node2DFactory

signal created(product)

@export var product_packed_scene: PackedScene
@export var target_container_name: StringName

func create(_product_packed_scene := product_packed_scene) -> Node2D:
	var product: Node2D = _product_packed_scene.instantiate()

	var container = _get_or_create_container()
	container.add_child(product)
	product.global_position = global_position 
	created.emit(product)
	return product


func _get_or_create_container() -> Node:
	## Find container by name, or create it if it doesn't exist
	var container = get_tree().root.find_child(target_container_name, true, false)
	
	if container:
		return container
	
	# Container doesn't exist - create it under the current scene
	container = Node2D.new()
	container.name = target_container_name
	get_tree().current_scene.add_child(container)
	return container
