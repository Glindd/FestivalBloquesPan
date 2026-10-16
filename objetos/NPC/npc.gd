class_name PuestoCliente
extends ObjetoInteractuable

@export var ocupado: bool = false:
	set(value):
		if ocupado != value:
			ocupado = value
			_actualizar_animacion()
			if interaccion_area:
				interaccion_area.activar_interaccion(ocupado)
var receta_actual: String = ""

@onready var globo: GloboPedido = $GloboPedido
var pedido_revelado: bool = false

## Cuántos segundos aguanta el cliente antes de irse sin que lo atiendan.
@export var segundos_de_paciencia: float = 90.0

# Se descuenta en todas las máquinas para que la barra se mueva parejo, pero el que
# decide que el cliente se fue es el servidor.
var paciencia_restante: float = 0.0

@onready var modelo: Node3D = $modelo
var pos_visible: Vector3
var pos_oculta: Vector3

func _ready() -> void:
	super._ready()
	
	pos_visible = modelo.position
	pos_oculta = pos_visible - Vector3(0, 2, 0) 
	modelo.position = pos_oculta
	if interaccion_area:
		interaccion_area.activar_interaccion(ocupado)

func _actualizar_animacion() -> void:
	if not is_inside_tree(): return
	var tween: Tween = create_tween()
	
	if ocupado:
		tween.tween_property(modelo, "position", pos_visible, 0.6).set_trans(Tween.TRANS_SPRING)
	else:
		globo.esconder()
		tween.tween_property(modelo, "position", pos_oculta, 0.4).set_trans(Tween.TRANS_SINE)

# La paciencia baja en todas las máquinas para que la barra se vea igual en todas, pero
# solo el servidor da por perdido al cliente, para que no se vaya dos veces.
func _process(delta: float) -> void:
	if not ocupado or paciencia_restante <= 0.0:
		return
	paciencia_restante = maxf(paciencia_restante - delta, 0.0)
	globo.mostrar_paciencia(paciencia_restante / segundos_de_paciencia)
	if paciencia_restante > 0.0 or not multiplayer.is_server():
		return
	print("Servidor: el cliente de ", name, " se cansó de esperar")
	Jornada.instance.anotar_cliente_perdido()
	configurar_pedido_rpc.rpc(false, "")


# El parámetro atendido distingue al cliente que se va contento con su pan del que se
# va porque se cansó de esperar, para que el globo muestre la carita que corresponde.
@rpc("call_local", "reliable")
func configurar_pedido_rpc(estado: bool, receta: String = "", atendido: bool = false) -> void:
	receta_actual = receta
	pedido_revelado = false
	ocupado = estado
	
	paciencia_restante = segundos_de_paciencia if estado else 0.0
	if ocupado:
		globo.mostrar_incognita()
		globo.mostrar_paciencia(1.0)
		print("Puesto actualizó su receta a: ", receta_actual)
	elif atendido:
		globo.celebrar()

func texto_de_ayuda(_jugador: Player) -> String:
	if not ocupado:
		return "Mostrador"
	if not pedido_revelado:
		return "Presionar E para preguntar
(subido sobre otro gato)"
	return "Presionar E para entregar"


@rpc("call_local", "reliable")
func revelar_pedido_rpc() -> void:
	pedido_revelado = true
	# El globo pasa de la interrogación al dibujo del pan que pidió.
	var receta: RecetaDef = Recetario.instance.recetas.buscar_por_id(StringName(receta_actual))
	globo.mostrar_receta(receta.icono if receta else null)
	print("PuestoCliente: ¡Pedido revelado! Quiere: ", receta_actual)

@rpc("any_peer", "call_local", "reliable")
func _execute_interaction() -> void:
	if not multiplayer.is_server(): return
	print("miau")
	if not ocupado: return
	
	var peer_id = multiplayer.get_remote_sender_id()
	if peer_id == 0: peer_id = multiplayer.get_unique_id()
	
	# Buscar al jugador que interactuó
	var nodo_jugador = get_tree().root.find_child(str(peer_id), true, false)
	var jugador = nodo_jugador as Player
	
	if not jugador:
		print("Servidor: No se pudo encontrar al jugador ", peer_id)
		return
		
	if not pedido_revelado:
		if jugador.posicion_actual == jugador.Posicion.ARRIBA_DE:
			revelar_pedido_rpc.rpc()
		else:
			print("Servidor: Jugador en el suelo intentó hablar, pero no alcanza. ¡Necesitas subirte arriba de otro!")
		return

	if pedido_revelado:
		if jugador.objeto_en_mano != null:
			var plato_entregado:String = jugador.objeto_en_mano.nombre_ingrediente # O jugador.objeto_en_mano.id_receta
			
			if plato_entregado == receta_actual:
				print("Servidor: ¡Entrega Exitosa! El jugador ", peer_id, " entregó ", plato_entregado)
				
				# Quitar el plato de la mano, en todas las máquinas
				jugador.objeto_en_mano.desaparecer.rpc()
				jugador.objeto_en_mano = null
				#jugador.vaciar_manos_rpc.rpc()
				
				# El pan terminado se llama igual que la receta, así que el precio sale del
				# recetario y no de un número escrito a mano.
				var receta_pedida: RecetaDef = Recetario.instance.recetas.buscar_por_id(plato_entregado)
				if receta_pedida:
					GameManager.instance.añadir_dinero(receta_pedida.precio_venta)
				Jornada.instance.anotar_cliente_atendido()
				Jornada.instance.anotar_pan_entregado()
				
				# Quitar al cliente (poner ocupado en false)
				configurar_pedido_rpc.rpc(false, "", true)
			else:
				print("Servidor: Comida incorrecta. El cliente quiere: ", receta_actual, " pero le diste: ", plato_entregado)
		else:
			print("Servidor: El pedido ya fue revelado, pero no llevas comida para entregar.")
