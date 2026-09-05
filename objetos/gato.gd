class_name Player
extends CharacterBody3D

@export var speed: float = 1
@export var jump_speed: float = 6
@export var acceleration: float = 5
@export var mouse_sensitivy: float = 0.005
@export var camera_min_pitch: float = -20
@export var camera_max_pitch: float = 30
@export var spring_min_pitch: float = -50
@export var spring_max_pitch: float = 50

@export var is_emoteando: bool = false
signal tiempo_trabajando(tiempo: int)

@onready var animation_player: AnimationPlayer = $GatoV5_Bone/AnimationPlayer
@onready var animation_tree: AnimationTree = $GatoV5_Bone/AnimationTree
@onready var action_state_machine: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/StateMachine/playback")
@onready var t_inicio: float = animation_player.get_animation("Esqueleto_acción_004").length

enum {C,R,L}
var curRot:int = C
@onready var intensidadR:float = 0
@onready var intensidadL:float = 0
@onready var fuerza_giro:float = 0

enum {IDLE,WALK,RUN}
var curAnim: int = IDLE
@onready var walk_val: float = 0
@onready var run: float = 0
@export var blend_speed: int = 15

@onready var label_3d: Label3D = $GatoV5_Bone/Esqueleto/Skeleton3D/Cube/Label3D

@onready var spring_arm_3d: SpringArm3D = $SpringArm3D
@onready var camera_3d: Camera3D = $SpringArm3D/Camera3D

@onready var input_synchronizer: InputSynchronizer = $InputSynchronizer
@onready var sync_timer: Timer = $SyncTimer

@onready var model: Node3D = $GatoV5_Bone/Esqueleto
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	sync_timer.timeout.connect(_on_sync_timeout)

	var player_data: Statics.PlayerData = Game.instance.get_player(get_multiplayer_authority())
	label_3d.text = player_data.name
	label_3d.visible = not is_multiplayer_authority()
	#sprite_puntero.visible = is_multiplayer_authority()
	camera_3d.current = is_multiplayer_authority()
	if is_multiplayer_authority():
		#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		sync_timer.start()

func _input(event: InputEvent) -> void:
	
	#Mouse
	if event.is_action_pressed("Menu"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("Idle1") and not is_emoteando:
		trigger_emotiza1.rpc()
	if event.is_action_pressed("Idle2") and not is_emoteando:
		trigger_emotiza2.rpc()
	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion:
		spring_arm_3d.rotation.y = spring_arm_3d.rotation.y - input_synchronizer.mouse_vector.x * mouse_sensitivy
		camera_3d.rotation.x = clamp(
			camera_3d.rotation.x - input_synchronizer.mouse_vector.y * mouse_sensitivy,
			deg_to_rad(camera_min_pitch),
			deg_to_rad(camera_max_pitch)
		)

func _process(_delta: float) -> void:
	pass
	
func handle_animation(delta: float) -> void:
	match curAnim:
		IDLE:
			walk_val = lerpf(walk_val,0,blend_speed*delta)
			run = lerpf(run,0,blend_speed*delta)
		WALK:
			walk_val = lerpf(walk_val,1.5,blend_speed*delta)
			run = lerpf(run,0,blend_speed*delta)
		RUN:
			walk_val = lerpf(walk_val,0,blend_speed*delta)
			run = lerpf(run,1.5,blend_speed*delta)
	match curRot:
		R:
			intensidadL = lerpf(intensidadL,0,blend_speed*delta)
			intensidadR = lerpf(intensidadR,fuerza_giro,blend_speed*delta)
		L:
			intensidadL = lerpf(intensidadL,fuerza_giro,blend_speed*delta)
			intensidadR = lerpf(intensidadR,0,blend_speed*delta)
		C:
			intensidadL = lerpf(intensidadL,0,blend_speed*delta)
			intensidadR = lerpf(intensidadR,0,blend_speed*delta)
	update_tree()

func update_tree() -> void:
	animation_tree["parameters/Walk/blend_amount"] = walk_val
	animation_tree["parameters/Run/blend_amount"] = run
	animation_tree["parameters/RotandoR/add_amount"] = intensidadR
	animation_tree["parameters/RotandoL/add_amount"] = intensidadL
		
func _physics_process(delta: float) -> void:
	speed = lerpf(speed,input_synchronizer.move_speed,0.2)
	if is_emoteando:
		velocity.x = move_toward(velocity.x,0,acceleration)
		velocity.z = move_toward(velocity.z,0,acceleration)
		move_and_slide()
		return
		
	if not is_on_floor():
		velocity += get_gravity()*delta
	animation_player.speed_scale = max(int(input_synchronizer.move_speed * 0.75), 1)
	
	if not is_emoteando:
		var dif_angulo: float = angle_difference(model.rotation.y, spring_arm_3d.rotation.y)
		var umbral_giro: float = 0.05
		fuerza_giro = clampf(absf(dif_angulo) / (PI / 2.0), 0.0, 1.0)
		if dif_angulo > umbral_giro:
			curRot = R
		elif dif_angulo < -umbral_giro:
			curRot = L
		else:
			curRot = C
		model.rotation.y = lerp_angle(
			model.rotation.y,
			spring_arm_3d.rotation.y,
			10 * delta
		)
		collision_shape_3d.rotation = model.rotation
	

	if not input_synchronizer.move_input.is_zero_approx() and is_on_floor():
		if speed < 2.4:
			curAnim = WALK
		else:
			curAnim = RUN
	else:
		curAnim = IDLE

	if input_synchronizer.jump:
		if is_on_floor():
			curAnim = IDLE
			velocity.y = jump_speed
		input_synchronizer.jump = false
		
	handle_animation(delta)
	
	var move_input: Vector2 = input_synchronizer.move_input
	var direction: Vector3 = model.transform.basis * Vector3(move_input.x, 0, move_input.y)
	var target: Vector2 = Vector2(direction.x, direction.z) * input_synchronizer.move_speed
	var current: Vector2 = Vector2(velocity.x, velocity.z)
	var result: Vector2 = current.move_toward(target, acceleration * delta)
	velocity.x = result.x
	velocity.z = result.y
	
	move_and_slide()



func _ajustar_camara(largo: float, alto:float) -> void:
	spring_arm_3d.spring_length += largo
	spring_arm_3d.position.y += alto
	
@rpc("any_peer","call_local","reliable")
func trigger_emotiza1() -> void:
	if is_emoteando:
		return
	emotiza1()
	
func emotiza1() -> void:
	is_emoteando = true
	_ajustar_camara(4,-1)
	animation_tree.set("parameters/Idle1/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	await get_tree().create_timer(4.5).timeout
	_ajustar_camara(-4,1)
	is_emoteando = false

@rpc("any_peer","call_local","reliable")
func trigger_emotiza2() -> void:
	if is_emoteando:
		return
	emotiza2()
	
func emotiza2() -> void:
	is_emoteando = true

	_ajustar_camara(4,-1)
	animation_tree.set("parameters/Idle2/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	await get_tree().create_timer(3.5).timeout
	_ajustar_camara(-4,1)
	is_emoteando = false

#Accion predeterminada
@rpc("any_peer","call_local","reliable")
func trigger_emotiza(duracion:float) -> void:
	if is_emoteando:
		return
	_ejecutar_animacion_emotiza(duracion)
	
func _ejecutar_animacion_emotiza(duracion: float) -> void:
	is_emoteando = true
	tiempo_trabajando.emit(duracion)
	_ajustar_camara(3,1)
	var t_desarrollo: float = max(0.0, duracion - t_inicio *2)
	action_state_machine.travel("Inicio")

	var tween_in: Tween = create_tween()
	tween_in.tween_property(animation_tree, "parameters/Accion/blend_amount", 1.0, 0.15)
	
	await get_tree().create_timer(t_inicio + t_desarrollo).timeout
	action_state_machine.travel("Fin")
	await get_tree().create_timer(t_inicio-0.2).timeout
	_ajustar_camara(-3,-1)
	var tween_out: Tween = create_tween()
	tween_out.tween_property(animation_tree, "parameters/Accion/blend_amount", 0.0, 0.2)
	await tween_out.finished
	is_emoteando = false
	

func _on_sync_timeout() -> void:
	_sync.rpc(global_position, velocity)
	_sync2.rpc(spring_arm_3d.rotation)

@rpc("call_local", "unreliable")
func _sync(pos: Vector3, vel: Vector3) -> void:
	global_position = global_position.lerp(pos, 0.5)
	velocity = velocity.lerp(vel, 0.5)

@rpc("call_local","unreliable")
func _sync2(rot:Vector3) -> void:
	spring_arm_3d.rotation = spring_arm_3d.rotation.lerp(rot, 1)
	
