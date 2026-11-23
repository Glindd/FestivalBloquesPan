class_name Estante
extends ObjetoInteractuable

@export var tipo_de_ingrediente: PackedScene 
@onready var nodo_spawn: Marker3D = $SpawnPoint
@onready var spawner_ingrediente: MultiplayerSpawner = $IngredientSpawner
@onready var positions: Array[Marker3D] = [$Ing1, $Ing2, $Ing3, $Ing4]
# Los ingredientes de adorno que llenan las repisas. No se pueden tomar: van sin colisión
# y congelados, están solo para que el estante no se vea vacío.
#
# El nombre sale de su puesto en la repisa y no del reloj. Esto corre en todas las
# máquinas, y Time.get_ticks_msec() devuelve los milisegundos desde que arrancó cada
# computador, así que el mismo adorno terminaba llamándose distinto en cada una. Como el
# ingrediente trae un MultiplayerSynchronizer adentro, y un sincronizador busca su nodo
# por nombre, del otro lado no lo encontraba. Es el mismo problema que ya costó caro con
# la mesa y el horno.
#
# Además, el bucle corre tan rápido que el reloj alcanzaba a dar el mismo número para los
# cuatro, así que ni siquiera eran distintos entre sí dentro de la misma máquina.
func _ready() -> void:
	super()
	if tipo_de_ingrediente == null:
		return
	for i: int in positions.size():
		var adorno: Ingrediente = tipo_de_ingrediente.instantiate()
		adorno.name = "Adorno_%d" % (i + 1)
		adorno.collision_layer = 0
		adorno.collision_mask = 0
		adorno.freeze = true
		add_child(adorno)
		adorno.global_position = positions[i].global_position



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
	
