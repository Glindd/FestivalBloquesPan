class_name MesaCocina
extends ObjetoInteractuable

# Mesa de preparación. El estado de la mesa, o sea qué hay encima y si quedó algo listo,
# lo decide siempre el servidor, y cada cambio viaja como un rpc que corre igual en todas
# las máquinas. Los clientes no deciden nada por su cuenta: solo aplican lo que llega.
#
# Los cambios se hacen por nodo y no por índice. Antes el servidor mandaba la posición
# dentro del arreglo, pero el servidor reordenaba su copia al calcular la llave de la
# receta, así que ese índice dejaba de apuntar al mismo casillero en el cliente y las dos
# máquinas terminaban con mesas distintas sin forma de volver a cuadrarse.

@onready var area_interaccion: CollisionShape3D = $Interaccion_area/CollisionShape3D2
@onready var nodo_ing_1: Marker3D = $Ingrediente1
@onready var nodo_ing_2: Marker3D = $Ingrediente2
@onready var nodo_ing_3: Marker3D = $Ingrediente3
@onready var nodo_listo: Marker3D = $IngredienteListo

var ingredientes: Array[Ingrediente]
var max_ingredientes: int = 3
var nodos_pos: Array[Marker3D]
var nom_ingredientes: Array[String]
var recibe_ingredientes: bool = true
var dummy_ing: PackedScene = preload("res://objetos/ingredientes/dummy_ing.tscn") as PackedScene

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
	if not multiplayer.is_server():
		return
	if not recibe_ingredientes:
		return

	var jugador: Player = _get_player_by_peer_id(_quien_apreto())
	if jugador == null or jugador.objeto_en_mano == null:
		return
	if ingredientes.size() >= max_ingredientes:
		return

	var traido: Ingrediente = jugador.objeto_en_mano
	if traido.nombre_ingrediente in nom_ingredientes:
		return

	_poner_en_la_mesa.rpc(traido.get_path(), nodos_pos[ingredientes.size()].global_position)


# con e se cocina, se saca lo que quedó listo, o se recupera lo que uno mismo dejó
@rpc("any_peer", "call_local", "reliable")
func _execute_interaction() -> void:
	if not multiplayer.is_server():
		return

	var quien: int = _quien_apreto()
	var siguiente: PackedScene = _buscar_en_pasos()

	if siguiente != null and siguiente != dummy_ing:
		var bloqueada: RecetaDef = _receta_sin_comprar()
		if bloqueada != null:
			_avisar_receta_bloqueada.rpc_id(quien, bloqueada.nombre)
			return
		var rutas_a_borrar: Array = []
		for ing: Ingrediente in ingredientes:
			if is_instance_valid(ing):
				rutas_a_borrar.append(ing.get_path())
		_cocinar_en_todos.rpc(rutas_a_borrar, siguiente.resource_path, "Ingrediente_" + str(Time.get_ticks_msec()))
		return

	# Si hay algo listo sobre la mesa se lo lleva quien apretó. Antes esto se mandaba ante
	# cualquier E, incluso con la mesa vacía, y por eso el pan recién hecho se le
	# teletransportaba a la mano al que apretaba desde el otro lado de la cocina.
	if is_instance_valid(ingrediente_listo):
		var listo: Ingrediente = ingrediente_listo
		_sacar_el_listo.rpc()
		listo.request_tomar(quien)
		return

	# Y si no, se devuelve lo último que alguien dejó, para que la mesa no se quede con
	# ingredientes atrapados cuando la combinación no corresponde a ninguna receta.
	if ingredientes.is_empty():
		return
	var ultimo: Ingrediente = ingredientes[ingredientes.size() - 1]
	if not is_instance_valid(ultimo):
		return
	_quitar_de_la_mesa.rpc(ultimo.get_path())
	ultimo.request_tomar(quien)


# ---- los cambios de estado, que corren igual en todas las máquinas ----

@rpc("authority", "call_local", "reliable")
func _poner_en_la_mesa(ruta: NodePath, pos: Vector3) -> void:
	var ing: Ingrediente = get_node_or_null(ruta) as Ingrediente
	if ing == null or ingredientes.has(ing):
		return
	ingredientes.push_back(ing)
	nom_ingredientes.push_back(ing.nombre_ingrediente)
	ing.dejar_en_mueble(pos)


@rpc("authority", "call_local", "reliable")
func _quitar_de_la_mesa(ruta: NodePath) -> void:
	var ing: Ingrediente = get_node_or_null(ruta) as Ingrediente
	var donde: int = ingredientes.find(ing)
	if donde < 0:
		return
	ingredientes.remove_at(donde)
	nom_ingredientes.remove_at(donde)


@rpc("authority", "call_local", "reliable")
func _sacar_el_listo() -> void:
	ingrediente_listo = null
	recibe_ingredientes = true


@rpc("authority", "call_local", "reliable")
func _cocinar_en_todos(rutas_a_borrar: Array, ruta_escena: String, nombre_unico: String) -> void:
	for ruta: NodePath in rutas_a_borrar:
		var viejo: Node = get_node_or_null(ruta)
		if viejo:
			viejo.queue_free()
	ingredientes.clear()
	nom_ingredientes.clear()

	var escena: PackedScene = load(ruta_escena) as PackedScene
	if escena == null:
		recibe_ingredientes = true
		return
	var nuevo: Ingrediente = escena.instantiate() as Ingrediente
	nuevo.name = nombre_unico
	get_tree().current_scene.add_child(nuevo)
	nuevo.dejar_en_mueble(nodo_listo.global_position)
	ingrediente_listo = nuevo
	recibe_ingredientes = false


# ---- consultas ----

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
	etiqueta.text = "Falta comprar\n" + nombre_receta
	await get_tree().create_timer(SEGUNDOS_DE_AVISO).timeout
	if este_aviso == _avisos_mostrados and is_instance_valid(etiqueta):
		etiqueta.text = _texto_de_la_etiqueta


func _buscar_en_pasos() -> PackedScene:
	var llave: String = _llave_de_la_mesa()
	if llave in pasos.keys():
		return pasos[llave]
	return dummy_ing


# Los nombres de lo que hay sobre la mesa, ordenados y unidos con +, que es la forma en
# que están escritas las llaves de la lista de pasos. Se ordena una copia y no el arreglo
# de la mesa, porque ese arreglo tiene que quedar en el mismo orden en todas las máquinas.
func _llave_de_la_mesa() -> String:
	var nombres: Array[String] = nom_ingredientes.duplicate()
	nombres.sort()
	return "+".join(PackedStringArray(nombres))


func texto_de_ayuda(jugador: Player) -> String:
	var lineas: Array[String] = []
	if jugador.objeto_en_mano and recibe_ingredientes and ingredientes.size() < max_ingredientes:
		lineas.push_back("Presionar Q para dejar")
	if pasos.get(_llave_de_la_mesa(), dummy_ing) != dummy_ing:
		lineas.push_back("Presionar E para preparar")
	elif is_instance_valid(ingrediente_listo):
		lineas.push_back("Presionar E para tomar")
	elif ingredientes.size() > 0:
		lineas.push_back("Presionar E para recuperar")
	if lineas.is_empty():
		return "Mesa de preparación"
	return "\n".join(PackedStringArray(lineas))


# Quién apretó la tecla. En la llamada local del servidor el emisor remoto llega en cero.
func _quien_apreto() -> int:
	var quien: int = multiplayer.get_remote_sender_id()
	return 1 if quien == 0 else quien


func _get_player_by_peer_id(peer_id: int) -> Player:
	for p: Node in get_tree().get_nodes_in_group("players"):
		if p.get_multiplayer_authority() == peer_id:
			return p as Player
	return null
