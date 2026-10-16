extends ObjetoInteractuable

# Horno. Igual que la mesa: el estado lo decide el servidor y cada cambio viaja como un
# rpc que corre igual en todas las máquinas.
#
# Antes el horno se vaciaba solo en el servidor al sacar el pan, así que los clientes se
# quedaban con el horno ocupado para siempre y su cartel seguía ofreciendo sacar algo que
# ya no estaba.

@onready var nodo_ing: Marker3D = $Ingrediente

var ingrediente: Ingrediente
var dummy_ing: PackedScene = preload("res://objetos/ingredientes/dummy_ing.tscn") as PackedScene
var pasos: Dictionary = {
	"amasado_crudo": preload("res://objetos/ingredientes/amasado.tscn") as PackedScene,
	"masa_madre_cruda": preload("res://objetos/ingredientes/masa_madre.tscn") as PackedScene,
	"pan_masa_madre": dummy_ing,
	"pan_amasado": dummy_ing
}


# con q se mete lo que se trae en la mano
@rpc("any_peer", "call_local", "reliable")
func _execute_interaction_q() -> void:
	if not multiplayer.is_server():
		return
	if is_instance_valid(ingrediente):
		return

	var quien: int = _quien_apreto()
	var jugador: Player = _get_player_by_peer_id(quien)
	
	# Si no hay jugador o no tiene nada en la mano, no se puede meter nada
	if jugador == null or not is_instance_valid(jugador.objeto_en_mano):
		return

	# Llamamos a meter en el horno
	_meter_en_el_horno.rpc(jugador.objeto_en_mano.get_path(), nodo_ing.global_position)
	
@rpc("any_peer", "call_local", "reliable")
func _execute_interaction() -> void:
	if not multiplayer.is_server():
		return
	if not is_instance_valid(ingrediente):
		return

	var quien: int = _quien_apreto()
	var jugador: Player = _get_player_by_peer_id(quien)
	var siguiente: PackedScene = _buscar_en_pasos()

	# Si hay un paso de cocción, se hornea
	if siguiente != null and siguiente != dummy_ing:
		_hornear_en_todos.rpc(ingrediente.get_path(), siguiente.resource_path, "Ingrediente_" + str(Time.get_ticks_msec()))
		return

	# Bloquear si el jugador ya tiene las manos ocupadas y solo intenta retirar
	if jugador != null and is_instance_valid(jugador.objeto_en_mano):
		return

	# Sacar del horno
	var listo: Ingrediente = ingrediente
	_sacar_del_horno.rpc()
	listo.request_tomar(quien)
# ---- los cambios de estado, que corren igual en todas las máquinas ----

@rpc("authority", "call_local", "reliable")
func _meter_en_el_horno(ruta: NodePath, pos: Vector3) -> void:
	var ing: Ingrediente = get_node_or_null(ruta) as Ingrediente
	if ing == null:
		return
	ingrediente = ing
	ing.dejar_en_mueble(pos)


@rpc("authority", "call_local", "reliable")
func _sacar_del_horno() -> void:
	ingrediente = null


@rpc("authority", "call_local", "reliable")
func _hornear_en_todos(ruta_a_borrar: NodePath, ruta_escena: String, nombre_unico: String) -> void:
	var viejo: Node = get_node_or_null(ruta_a_borrar)
	if viejo:
		viejo.queue_free()
	ingrediente = null

	var escena: PackedScene = load(ruta_escena) as PackedScene
	if escena == null:
		return
	var nuevo: Ingrediente = escena.instantiate() as Ingrediente
	nuevo.name = nombre_unico
	get_tree().current_scene.add_child(nuevo)
	nuevo.dejar_en_mueble(nodo_ing.global_position)
	ingrediente = nuevo


# ---- consultas ----

func texto_de_ayuda(jugador: Player) -> String:
	if not is_instance_valid(ingrediente):
		if is_instance_valid(jugador.objeto_en_mano):
			return "Presionar Q para meter al horno"
		return "Horno"
	if pasos.get(ingrediente.nombre_ingrediente, dummy_ing) != dummy_ing:
		return "Presionar E para hornear"
	if not is_instance_valid(jugador.objeto_en_mano): # Solo si tiene manos libres
		return "Presionar E para sacar"
	return "Horno ocupado"

func _buscar_en_pasos() -> PackedScene:
	if not is_instance_valid(ingrediente):
		return dummy_ing
	var llave: String = ingrediente.nombre_ingrediente
	if llave in pasos.keys():
		return pasos[llave]
	return dummy_ing


# Quién apretó la tecla. En la llamada local del servidor el emisor remoto llega en cero.
func _quien_apreto() -> int:
	var quien: int = multiplayer.get_remote_sender_id()
	return 1 if quien == 0 else quien


func _get_player_by_peer_id(peer_id: int) -> Player:
	for p: Node in get_tree().get_nodes_in_group("players"):
		if p.get_multiplayer_authority() == peer_id:
			return p as Player
	return null
