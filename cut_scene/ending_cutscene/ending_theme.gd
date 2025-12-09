# EndingTheme.gd
class_name EndingTheme extends Resource

@export_group("Environment")
@export var sky_texture: Texture2D
@export var global_light_color: Color = Color.WHITE
@export var global_light_energy: float = 1.0
@export var env_modulate_color: Color = Color.WHITE # Màu ám lên biển/nước

@export_group("Rain Effect")
@export var is_raining: bool = false
@export var rain_color: Color = Color.WHITE
@export var rain_amount: float = 200.0

@export_group("Dialogic")
@export var timeline_name: String
