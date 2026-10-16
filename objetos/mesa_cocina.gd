class_name MesaCocina
extends ObjetoInteractuable

@onready var area_interaccion: CollisionShape3D = $Interaccion_area/CollisionShape3D2
@onready var nodo_ing_1: Marker3D = $Ingrediente1
@onready var nodo_ing_2: Marker3D = $Ingrediente2
@onready var nodo_ing_3: Marker3D = $Ingrediente3
@onready var nodo_listo: Marker3D = $IngredienteListo
var ingredientes: Array[Ingrediente]
var max_ingredientes = 3
var nodos_pos: Array[Marker3D]
var nom_ingredientes: Array[String]
var recibe_ingredientes: bool = true
var dummy_ing = preload("res://objetos/ingredientes/dummy_ing.tscn") as PackedScene

var ingrediente_listo: Ingrediente = null

# Cuánto dura el aviso de receta bloqueada sobre la mesa antes de volver al texto normal.
const SEGUNDOS_DE_AVISO: float = 2.0

# El texto que trae la etiqueta de la mesa en la escena, para poder devolverlo después
# de un aviso sin escribirlo a mano en dos lugares.
var _texto_de_la_etiqueta: String = ""

# Cuántos avisos se han mostrado. Si llega uno nuevo antes de que termine el anterior,
# solo el último devuelve la etiqueta a su texto normal.
var _avisos_mostrados: int = 0

# quizas seria bueno hacer un tipo receta y manejar los pasos (recetas desbloqueadas)
# desde el game manager
# key: String, val: PackedScene (ingrediente para que se pueda tomar)
# el string es la concatenacion con + de los nombres de los ingredientes en orden alfabetico
var pasos: Dictionary = {
	"agua+harina": preload("res://objetos/ingredientes/amasado_crudo.tscn") as PackedScene,
	"amasado_crudo": dummy_ing,
	"agua+harina+levadura": preload("res://objetos/ingredientes/masa_madre_cruda.tscn") as PackedScene,
	"masa_madre_cruda": dummy_ing
}

func _ready() -> void:
	super()
	if interaccion_area.label:
		_texto_de_la_etiqueta = interaccion_area.label.text
	nodos_pos.push_back(nodo_ing_1)
	nodos_pos.push_back(nodo_ing_2)
	nodos_pos.push_back(nodo_ing_3)

# con q se dejan los ingredientes en la mesa
@rpc("any_peer", "call_local", "reliable")
func _execute_interaction_q() -> void:
	#calcular lo necesario
	print("ejecutando interaccion q")
	if not recibe_ingredientes:
		print("no recibe ings")
		return
	
	if not multiplayer.is_server():
		print("no tenia la autoridad")
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	var player = _get_player_by_peer_id(sender_id)
	
	if player == null or not player.objeto_en_mano:
		print("objeto o player no encontrado")
		return
	
	if len(ingredientes) >= max_ingredientes:
		print("demasiados ingredientes")
		return
	
	var obj: Ingrediente = player.objeto_en_mano
	if obj.nombre_ingrediente in nom_ingredientes:
		print("ingrediente ya en la mesa")
		return
	
	var index_actual = len(ingredientes)
	var pos = nodos_pos[len(ingredientes)].global_position
	
	print("Servidor: cediendo objeto de ", player.name)
	# actualizar objetos
	_ceder_objeto_localmente(player, obj, pos)
	print("cediendo en clientes")
	# sincronizar
	rpc("_sync_deposito", obj.get_path(), pos, index_actual, player.name)
	
func _ceder_objeto_localmente(player: Player, obj: Ingrediente, pos: Vector3) -> void:
	print("cediendo objeto localmente desde", player.get_instance_id())
	
	player.ceder_objeto(pos)
	ingredientes.push_back(obj)
	nom_ingredientes.push_back(obj.nombre_ingrediente)
	print("ya cedido")
		
@rpc("authority", "call_remote", "reliable")
func _sync_deposito(obj_path: NodePath, pos: Vector3, index: int, player_name: String) -> void:
	var obj = get_node_or_null(obj_path) as Ingrediente
	if obj and obj is Ingrediente:
		obj.held_by = -1
		obj.freeze = true
		obj.global_position = pos
		obj.global_rotation = nodos_pos[index].global_rotation
		if index >= len(ingredientes):
			ingredientes.resize(index + 1)
			nom_ingredientes.resize(index + 1)
		ingredientes[index] = obj
		nom_ingredientes[index] = obj.nombre_ingrediente
	
	var p = get_node_or_null("../Players/" + player_name)
	if p and "objeto_en_mano" in p:
		p.objeto_en_mano = null
	
func _get_player_by_peer_id(peer_id: int) -> Player:
	for p in get_tree().get_nodes_in_group("players"):
		if p.get_multiplayer_authority() == peer_id:
			return p
	return null

# con e se cocina y se toma el resultado
@rpc("any_peer", "call_local", "reliable")
func _execute_interaction() -> void:
	if not is_multiplayer_authority():
		return
	
	var next = _buscar_en_pasos()
	# si hay paso que hacer, hacerlo
	if next != null and next != dummy_ing:
		# La panadería solo prepara lo que ya compró en la tienda.
		var bloqueada: RecetaDef = _receta_sin_comprar()
		if bloqueada != null:
			var id_del_que_apreto: int = multiplayer.get_remote_sender_id()
			if id_del_que_apreto == 0:
				id_del_que_apreto = 1
			_avisar_receta_bloqueada.rpc_id(id_del_que_apreto, bloqueada.nombre)
			return
		print("existe siguiente paso")
		# borrar ingredientes
		recibe_ingredientes = false
		
		var rutas_a_borrar: Array = []
		for ing in ingredientes:
			rutas_a_borrar.append(ing.get_path())
			
		ingredientes.clear()
		nom_ingredientes.clear()
		# spawnear el siguiente
		var nombre_unico = "Ingrediente_" + str(Time.get_ticks_msec())
		
		_procesar_cocina_en_todos.rpc(rutas_a_borrar, next.resource_path, nombre_unico)
		return
	# soltar el ingrediente
	else:
		print("next == dummy o no hay receta")
		
		#if ingredientes.size() > 0:
			#print("Recuperando ingrediente base.")
			# todo
			
		# Obtenemos quién hizo la interacción
		var sender_id = multiplayer.get_remote_sender_id()
		# Si fue el servidor el que interactuó localmente, su ID de emisor remoto puede ser 0 o 1
		if sender_id == 0:
			sender_id = 1
		
		var player = _get_player_by_peer_id(sender_id)
		if player == null:
			print("Jugador no encontrado para entregar el objeto.")
			return
			
		#_sync_retirar_ingrediente_listo.rpc(sender_id)
		_sync_retirar_ingrediente_listo.rpc(sender_id)

# Qué receta falta comprar para poder preparar lo que hay sobre la mesa. Devuelve null
# cuando la receta ya está desbloqueada y también cuando la combinación no corresponde a
# ninguna receta, porque esos casos los sigue resolviendo la lista de pasos de la mesa.
func _receta_sin_comprar() -> RecetaDef:
	if Recetario.instance == null or Recetario.instance.recetas == null:
		return null
	if Recetario.instance.buscar_desbloqueada(nom_ingredientes) != null:
		return null
	return Recetario.instance.recetas.buscar_por_ingredientes(nom_ingredientes)


# Le avisa al jugador que apretó que esa receta todavía tiene candado. Va solo a su
# máquina porque la etiqueta de la mesa la ve únicamente quien está parado al lado.
@rpc("authority", "reliable")
func _avisar_receta_bloqueada(nombre_receta: String) -> void:
	var etiqueta: Label3D = interaccion_area.label
	if etiqueta == null:
		return
	_avisos_mostrados += 1
	var este_aviso: int = _avisos_mostrados
	etiqueta.text = "Falta comprar
" + nombre_receta
	await get_tree().create_timer(SEGUNDOS_DE_AVISO).timeout
	if este_aviso == _avisos_mostrados and is_instance_valid(etiqueta):
		etiqueta.text = _texto_de_la_etiqueta


# llamar solo si hay ingredientes en la mesa
func _buscar_en_pasos() -> PackedScene:
	var llave: String = _llave_de_la_mesa()
	print("llave: ", llave)
	if llave in pasos.keys():
		return pasos[llave]
	return dummy_ing


# Los nombres de lo que hay sobre la mesa, ordenados y unidos con +, que es la forma en
# que están escritas las llaves de la lista de pasos.
func _llave_de_la_mesa() -> String:
	nom_ingredientes.sort()
	return "+".join(PackedStringArray(nom_ingredientes))


func texto_de_ayuda(jugador: Player) -> String:
	var lineas: Array[String] = []
	if jugador.objeto_en_mano and recibe_ingredientes and ingredientes.size() < max_ingredientes:
		lineas.push_back("Presionar Q para dejar")
	if pasos.get(_llave_de_la_mesa(), dummy_ing) != dummy_ing:
		lineas.push_back("Presionar E para preparar")
	elif ingredientes.size() > 0:
		lineas.push_back("Presionar E para tomar")
	if lineas.is_empty():
		return "Mesa de preparación"
	return "
".join(PackedStringArray(lineas))


@rpc("authority", "call_local", "reliable")
func _procesar_cocina_en_todos(rutas_a_borrar: Array, scene_path: String, nombre_unico: String) -> void:
	# 1. Borrar los ingredientes en cada máquina (servidor y clientes)
	for ruta in rutas_a_borrar:
		print("ruta a borrar: ", ruta)
		var nodo_a_borrar = get_node_or_null(ruta)
		if nodo_a_borrar:
			print("Eliminando ingrediente visualmente: ", ruta)
			nodo_a_borrar.queue_free()
			
		ingredientes.clear()
		nom_ingredientes.clear()

	# 2. Spawnear el nuevo ingrediente resultante en cada máquina
	var scene = load(scene_path) as PackedScene
	if scene:
		var nuevo_ingrediente: Ingrediente = scene.instantiate()
		print("Spawneando resultado: ", nuevo_ingrediente.nombre_ingrediente)
		nuevo_ingrediente.name = nombre_unico
		get_tree().current_scene.add_child(nuevo_ingrediente)
		nuevo_ingrediente.freeze = true
		nuevo_ingrediente.global_position = nodo_ing_1.global_position
		ingrediente_listo = nuevo_ingrediente
	
	recibe_ingredientes = false

@rpc("authority", "call_local", "reliable")
func _sync_retirar_ingrediente_listo(sender_id: int) -> void:
	if ingrediente_listo == null:
		return
		
	var obj = ingrediente_listo
	ingrediente_listo = null
	obj.freeze = false
	recibe_ingredientes = true # La mesa vuelve a aceptar ingredientes

	if multiplayer.is_server():
		obj.request_tomar.rpc_id(1, sender_id)

@rpc("authority", "call_local", "reliable")
func _sync_retirar_y_tomar(sender_id: int) -> void:
	
	if ingredientes.size() == 0:
		print("No hay ingredientes en la mesa para tomar.")
		return
	
	var ing_a_recuperar: Ingrediente = ingredientes.pop_back()
	if ing_a_recuperar:
		nom_ingredientes.erase(ing_a_recuperar.nombre_ingrediente)
		ing_a_recuperar.freeze = false

	#ing_a_recuperar.global_position = nodo_listo.global_position
	if multiplayer.is_server():
		ing_a_recuperar.request_tomar.rpc_id(1, sender_id)
