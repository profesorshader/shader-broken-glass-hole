extends ColorRect

@export var speed: float = 1.0

var value: float

func _ready() -> void:
	value = material.get_shader_parameter("g_hole_limit")

func _process(delta: float) -> void:
	value += speed * delta
	material.set_shader_parameter("g_hole_limit", value)
