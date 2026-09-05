class_name InputSynchronizer
extends MultiplayerSynchronizer


@export var move_input: Vector2
@export var jump: bool
@export var mouse_motion: InputEventMouseMotion
@export var mouse_vector: Vector2
@export var idle1: bool
@export var idle2: bool
#export var E: bool
@export var correr: bool = false
@export var move_speed: float = 1

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	move_input = Input.get_vector("move_left", "move_right", "move_forward","move_backward")
	if Input.is_action_just_pressed("correr"):
		broadcast_correr.rpc()
	if Input.is_action_just_pressed("jump"):
		broadcast_jump.rpc()

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	mouse_motion = event as InputEventMouseMotion
	if mouse_motion:
		mouse_vector = mouse_motion.relative
		
@rpc("call_local")
func broadcast_correr() -> void:
	correr = not correr
	if correr:
		move_speed = 4
	else:
		move_speed = 1

#@rpc("call_local")
#func broadcast_interaccionE() -> void:
#	E = true

@rpc("call_local")
func broadcast_idle1() -> void:
	idle1 = true

@rpc("call_local")
func broadcast_idle2() -> void:
	idle2 = true
	
@rpc("call_local")
func broadcast_jump() -> void:
	jump = true
