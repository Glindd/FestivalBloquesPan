extends Node

# Banco de pruebas de la panadería. Es una herramienta de desarrollo y solo responde en
# las corridas de prueba, así que en el juego exportado para jugar no hace nada.
#
# Está porque hay cosas que cuestan bastante más de armar que de revisar. La racha de
# entregas seguidas es el caso: para verla subir hacen falta varios panes listos y varios
# clientes esperando con el pedido a la vista, y llegar a eso cocinando toma mucho más que
# los segundos que dura la racha.
#
# Las teclas las atiende el servidor, que es el que decide el estado de la cocina:
#
#   F9   llena los mostradores libres con un cliente y le revela el pedido al tiro. Sin el
#        pedido revelado hay que subirse arriba de otro gato para preguntarlo, que es
#        justo lo que no se puede hacer probando solo.
#   F10  deja una tanda de panes recién hechos alrededor del gato de esta máquina.
#   F11  prende y apaga el modo cadena, que vuelve a llenar cada mostrador apenas se
#        desocupa. Los mostradores son tres, así que sin esto la racha se queda en tres
#        entregas seguidas y nunca se alcanza a ver el multiplicador más alto.
#
# Los panes salen de la receta misma, del campo resultado, y no de una lista de rutas
# escrita acá. Así una receta nueva queda probable sin tener que tocar este archivo.


## Cuántos panes deja cada tanda.
const PANES_POR_TANDA: int = 6

## A qué distancia del gato aparecen los panes y desde qué altura caen, para que no salgan
## todos en el mismo punto ni encajados dentro del piso.
const RADIO_DE_LA_TANDA: float = 0.9
const ALTURA_DE_LA_TANDA: float = 1.2

# Con el modo cadena prendido los mostradores no descansan: apenas uno se desocupa vuelve
# a tener cliente, y el pedido se revela sin que nadie tenga que preguntarlo.
var _modo_cadena: bool = false

# Para que cada pan de prueba tenga un nombre distinto. Los nombres los reparte el
# servidor y viajan dentro del rpc, así que el mismo pan se llama igual en todas las
# máquinas y los cambios de estado siguen encontrándolo.
var _panes_soltados: int = 0

# Los mostradores quedan guardados porque el modo cadena los revisa cuadro a cuadro, y
# buscarlos cada vez significa recorrer la escena entera. La lista se rehace sola cuando
# queda vacía o cuando alguno de sus nodos ya no existe, que es lo que pasa al cambiar de
# escena.
var _puestos: Array[PuestoCliente] = []


func _ready() -> void:
	set_process(false)
	if not OS.is_debug_build():
		set_process_unhandled_input(false)


func _unhandled_input(evento: InputEvent) -> void:
	if not _atiende_las_teclas():
		return
	var tecla: InputEventKey = evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	match tecla.keycode:
		KEY_F9:
			dejar_los_mostradores_listos()
			get_viewport().set_input_as_handled()
		KEY_F10:
			soltar_tanda_de_panes()
			get_viewport().set_input_as_handled()
		KEY_F11:
			cambiar_modo_cadena()
			get_viewport().set_input_as_handled()


# El modo cadena revisa los mostradores cuadro a cuadro en vez de esperar un aviso, porque
# el puesto no avisa cuando se desocupa y no se gana nada agregándole una señal que el
# juego de verdad no va a usar.
func _process(_delta: float) -> void:
	if not _atiende_las_teclas() or not _modo_cadena:
		return
	_llenar_los_mostradores()


## Llena cada mostrador libre con un cliente y le revela el pedido de inmediato.
func dejar_los_mostradores_listos() -> void:
	if not _atiende_las_teclas():
		return
	var listos: int = _llenar_los_mostradores()
	Debug.log("Banco de pruebas: %d mostradores listos para recibir" % listos)


## Deja una tanda de panes terminados alrededor del gato de esta máquina. Los panes calzan
## con lo que están pidiendo los mostradores ocupados, y el resto de la tanda se llena con
## la primera receta que la panadería sepa hacer.
func soltar_tanda_de_panes() -> void:
	if not _atiende_las_teclas():
		return
	if Recetario.instance == null or Recetario.instance.recetas == null:
		return
	var gato: Node3D = _gato_de_esta_maquina()
	if gato == null:
		Debug.log("Banco de pruebas: no aparece el gato de esta máquina")
		return
	var pedidos: Array[StringName] = _recetas_de_la_tanda()
	if pedidos.is_empty():
		Debug.log("Banco de pruebas: ninguna receta desbloqueada tiene pan terminado")
		return
	var centro: Vector3 = gato.global_position + Vector3(0.0, ALTURA_DE_LA_TANDA, 0.0)
	var soltados: int = 0
	for i: int in pedidos.size():
		var receta: RecetaDef = Recetario.instance.recetas.buscar_por_id(pedidos[i])
		if receta == null or not receta.tiene_resultado():
			continue
		var angulo: float = TAU * float(i) / float(pedidos.size())
		var donde: Vector3 = centro + Vector3(cos(angulo), 0.0, sin(angulo)) * RADIO_DE_LA_TANDA
		_panes_soltados += 1
		soltados += 1
		_soltar_pan.rpc(receta.resultado.resource_path, donde, "PanDePrueba_%d" % _panes_soltados)
	Debug.log("Banco de pruebas: %d panes al lado del gato" % soltados)


## Prende y apaga el relleno automático de los mostradores.
func cambiar_modo_cadena() -> void:
	if not _atiende_las_teclas():
		return
	_modo_cadena = not _modo_cadena
	set_process(_modo_cadena)
	if _modo_cadena:
		_llenar_los_mostradores()
		Debug.log("Banco de pruebas: modo cadena prendido")
	else:
		Debug.log("Banco de pruebas: modo cadena apagado")


# Cuántos mostradores quedaron esperando con el pedido a la vista.
func _llenar_los_mostradores() -> int:
	var listos: int = 0
	for puesto: PuestoCliente in _mostradores():
		if not puesto.ocupado:
			var receta: StringName = _receta_para_pedir()
			if receta == &"":
				break
			puesto.configurar_pedido_rpc.rpc(true, String(receta))
			puesto.revelar_pedido_rpc.rpc()
			listos += 1
		elif not puesto.pedido_revelado:
			puesto.revelar_pedido_rpc.rpc()
			listos += 1
	return listos


# El pan de la tanda tiene que calzar con lo que el cliente está pidiendo, así que primero
# se copian los pedidos que hay en el mostrador y recién después se rellena.
func _recetas_de_la_tanda() -> Array[StringName]:
	var pedidos: Array[StringName] = []
	for puesto: PuestoCliente in _mostradores():
		if puesto.ocupado and puesto.receta_actual != "":
			pedidos.push_back(StringName(puesto.receta_actual))
	var relleno: StringName = _receta_para_pedir()
	if relleno == &"":
		return pedidos
	while pedidos.size() < PANES_POR_TANDA:
		pedidos.push_back(relleno)
	return pedidos


# Qué receta se le pide al cliente de prueba. Solo sirven las que tienen pan terminado,
# porque si no el banco pediría algo que después no se le puede entregar a nadie.
func _receta_para_pedir() -> StringName:
	if Recetario.instance == null or Recetario.instance.recetas == null:
		return &""
	for id: StringName in Recetario.instance.desbloqueadas():
		var receta: RecetaDef = Recetario.instance.recetas.buscar_por_id(id)
		if receta != null and receta.tiene_resultado():
			return receta.id
	return &""


func _mostradores() -> Array[PuestoCliente]:
	if not _puestos.is_empty() and _la_lista_sigue_sirviendo():
		return _puestos
	_puestos.clear()
	var escena: Node = get_tree().current_scene
	if escena == null:
		return _puestos
	for nodo: Node in escena.find_children("*", "Node3D", true, false):
		var puesto: PuestoCliente = nodo as PuestoCliente
		if puesto != null:
			_puestos.push_back(puesto)
	return _puestos


func _la_lista_sigue_sirviendo() -> bool:
	for puesto: PuestoCliente in _puestos:
		if not is_instance_valid(puesto):
			return false
	return true


func _gato_de_esta_maquina() -> Node3D:
	for nodo: Node in get_tree().get_nodes_in_group("players"):
		if nodo.get_multiplayer_authority() == multiplayer.get_unique_id():
			return nodo as Node3D
	return null


# El pan se crea en todas las máquinas, igual que los ingredientes que reparte el estante:
# nadie los sincroniza por nosotros, así que el que no lo cree se queda sin verlo.
@rpc("authority", "call_local", "reliable")
func _soltar_pan(ruta_escena: String, donde: Vector3, nombre: String) -> void:
	var escena: PackedScene = load(ruta_escena) as PackedScene
	if escena == null:
		return
	var pan: Ingrediente = escena.instantiate() as Ingrediente
	if pan == null:
		return
	pan.name = nombre
	get_tree().current_scene.add_child(pan)
	pan.global_position = donde


# El banco solo contesta en las corridas de prueba y solo en la máquina que hace de
# servidor, que es la única que puede cambiar el estado de la cocina.
func _atiende_las_teclas() -> bool:
	if not OS.is_debug_build():
		return false
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return false
	return get_tree().current_scene != null
