extends CharacterBody3D

@export var jump_speed: float = 6
@export var acceleration: float = 5
@export var mouse_sensitivy: float = 0.005
@export var camera_min_pitch: float = -10
@export var camera_max_pitch: float = 30
@export var spring_min_pitch: float = -50
@export var spring_max_pitch: float = 50

@onready var animation_player: AnimationPlayer = $GatoV5_Bone/AnimationPlayer
@onready var animation_tree: AnimationTree = $GatoV5_Bone/AnimationTree

enum {IDLE,WALK,RUN}
var curAnim = IDLE
@onready var walk_val: float = 0
@onready var run: float = 0
@export var blend_speed: int = 15

@onready var label_3d: Label3D = $Label3D

@onready var spring_arm_3d: SpringArm3D = $SpringArm3D
@onready var camera_3d: Camera3D = $SpringArm3D/Camera3D

@onready var input_synchronizer: InputSynchronizer = $InputSynchronizer
@onready var sync_timer: Timer = $SyncTimer

@onready var model: Node3D = $GatoV5_Bone/Esqueleto
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	sync_timer.timeout.connect(_on_sync_timeout)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("test"):
		pass

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion:
		spring_arm_3d.rotation.y = spring_arm_3d.rotation.y - input_synchronizer.mouse_vector.x * mouse_sensitivy
		camera_3d.rotation.x = clamp(
			camera_3d.rotation.x - input_synchronizer.mouse_vector.y * mouse_sensitivy,
			deg_to_rad(camera_min_pitch),
			deg_to_rad(camera_max_pitch)
		)

func setup(player_data: Statics.PlayerData) -> void:
	label_3d.text = player_data.name
	set_multiplayer_authority(player_data.id)  
	name = str(player_data.id)
	label_3d.visible = not is_multiplayer_authority()
	camera_3d.current = is_multiplayer_authority()
	if is_multiplayer_authority():
		sync_timer.start()

func handle_animation(delta: float) -> void:
	match curAnim:
		IDLE:
			walk_val = lerpf(walk_val,0,blend_speed*delta)
			run = lerpf(run,0,blend_speed*delta)
			#idle1 = false #lerpf(idle1,0,blend_speed*delta)
			#idle2 = false #lerpf(idle2,0,blend_speed*delta)
		WALK:
			walk_val = lerpf(walk_val,1.5,blend_speed*delta)
			run = lerpf(walk_val,0,blend_speed*delta)
			#idle1 = false #lerpf(idle1,0,blend_speed*delta)
			#idle2 = false #lerpf(idle2,0,blend_speed*delta)
		#RUN:
			#walk_val = lerpf(walk_val,0,blend_speed*delta)
			#run = lerpf(run,8,blend_speed*delta)
		#IDLE1:
			#walk_val = lerpf(walk_val,0,blend_speed*delta)
			#idle1 = true #lerpf(idle1,1,blend_speed*delta)
			#idle2 = false #lerpf(idle2,0,blend_speed*delta)
		#IDLE2:
			#walk_val = lerpf(walk_val,0,blend_speed*delta)
			#idle1 = false #lerpf(idle1,0,blend_speed*delta)
			#idle2 = true #lerpf(idle2,1,blend_speed*delta)
	update_tree()

func update_tree() -> void:
	animation_tree["parameters/Walk/blend_amount"] = walk_val
	#animation_tree["parameters/Run/blend_amount"] = run
	#animation_tree["parameters/Idle1/request"] = idle1
	#animation_tree["parameters/Idle2/request"] = idle2

		
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity()*delta
	# Controlador de emotikones con k y l
	'''
	elif is_on_floor() and input_synchronizer.idle1:
		curAnim = IDLE1
		#await get_tree().create_timer(4.5).timeout
		animation_tree.set("parameters/Idle2/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		input_synchronizer.idle2 = false
	elif is_on_floor() and input_synchronizer.idle2:
		curAnim = IDLE2
		#await get_tree().create_timer(3.5).timeout
		animation_tree.set("parameters/Idle1/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		input_synchronizer.idle2 = false
	'''
	#elif not input_synchronizer.move_input.is_zero_approx() and is_on_floor() and input_synchronizer.move_speed <= 4:
		#curAnim = RUN
	if not input_synchronizer.move_input.is_zero_approx() and is_on_floor():
		curAnim = WALK
	else:
		curAnim = IDLE

	animation_player.speed_scale = max(int(input_synchronizer.move_speed * 0.75), 1)
		
	if is_on_floor() and input_synchronizer.jump:
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
	
	
	#if not move_input.is_zero_approx():
	model.rotation.y = lerp_angle(
		model.rotation.y,
		spring_arm_3d.rotation.y,
		0.1
	)
	collision_shape_3d.rotation = model.rotation
	move_and_slide()

	

			
func _on_sync_timeout() -> void:
	_sync.rpc(global_position, velocity)
	_sync2(spring_arm_3d.rotation)

@rpc("call_local", "unreliable")
func _sync(pos: Vector3, vel: Vector3) -> void:
	global_position = global_position.lerp(pos, 0.5)
	velocity = velocity.lerp(vel, 0.5)
	
func _sync2(rot:Vector3) -> void:
	spring_arm_3d.rotation = spring_arm_3d.rotation.lerp(rot, 1)
	
