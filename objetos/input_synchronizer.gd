class_name InputSynchronizer
extends MultiplayerSynchronizer


@export var move_input: Vector2
@export var jump: bool

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	move_input = Input.get_vector("move_left", "move_right", "move_forward","move_backward")
	
	if Input.is_action_just_pressed("jump"):
		broadcast_jump.rpc()

@rpc("call_local")
func broadcast_jump() -> void:
	jump = true
