class_name Estante
extends ObjetoInteractuable

@export var tipo_de_ingrediente: PackedScene 
@onready var nodo_spawn: Marker3D = $SpawnPoint
@onready var spawner_ingrediente: MultiplayerSpawner = $IngredientSpawner
@onready var positions: Array[Marker3D] = [$Ing1, $Ing2, $Ing3, $Ing4]
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	var nombre_unico: String
	var nuevo_ingrediente: Ingrediente
	for pos in positions:
		nombre_unico = "Ingrediente_" + str(Time.get_ticks_msec())
		nuevo_ingrediente = tipo_de_ingrediente.instantiate()
		nuevo_ingrediente.name = nombre_unico
		nuevo_ingrediente.collision_layer = 0
		nuevo_ingrediente.collision_mask = 0
		nuevo_ingrediente.freeze = true
		self.add_child(nuevo_ingrediente)
		nuevo_ingrediente.global_position = pos.global_position
	
	

func texto_de_ayuda(_jugador: Player) -> String:
	return "Presionar E para tomar"


@rpc("any_peer", "call_local", "reliable")
func _execute_interaction() -> void:
	print("ejecutando interaccion e")
	if not is_multiplayer_authority():
		print("no tenia la autoridad")
		return
	
	if not tipo_de_ingrediente:
		return
		
	var nombre_unico = "Ingrediente_" + str(Time.get_ticks_msec())
	
	print("spawneando objeto localmente")
	_spawn_ingrediente_localmente(nodo_spawn.global_position, nombre_unico)
	
	_comunicar_spawn_a_clientes.rpc(nodo_spawn.global_position, nombre_unico)

@rpc("authority", "call_remote", "reliable")
func _comunicar_spawn_a_clientes(posicion_global: Vector3, nombre_nodo: String) -> void:
	print("spawneando objeto en clientes")
	_spawn_ingrediente_localmente(posicion_global, nombre_nodo)

func _spawn_ingrediente_localmente(posicion_global: Vector3, nombre_nodo: String) -> void:
	var nuevo_ingrediente = tipo_de_ingrediente.instantiate()
	nuevo_ingrediente.name = nombre_nodo
	add_child(nuevo_ingrediente)
	nuevo_ingrediente.global_position = posicion_global
	
