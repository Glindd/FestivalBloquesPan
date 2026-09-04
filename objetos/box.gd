extends Node3D

@onready var interaccion_area: InteraccionArea = $Interaccion_area

func _ready() -> void:
	interaccion_area.interact.connect(_request_interaction)
	
func _request_interaction() -> void:
	_execute_interaction.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _execute_interaction() -> void:
	pass
