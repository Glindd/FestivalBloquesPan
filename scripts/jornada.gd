class_name Jornada
extends Node

# Lleva la cuenta del día de la panadería: en qué día va, cuánto se juntó, a cuántos
# clientes se atendió y cuántos panes salieron. Cuando el reloj llega a cero cierra el
# día y avisa, para que la interfaz muestre el resumen.
#
# No calcula nada del juego por su cuenta. Los demás sistemas le avisan lo que pasó con
# anotar_cliente_atendido y anotar_pan_entregado, y ella solo suma. Así llevar la cuenta
# no obliga a nadie a conocer la pantalla de cierre.
#
# El día lo cierra y lo arranca siempre el servidor, igual que la compra de recetas, para
# que todas las máquinas pasen de día al mismo tiempo y con los mismos números.

static var instance: Jornada

## Cuánto dura un día en segundos. Es un número de relleno hasta que el equipo decida
## la dificultad.
@export var duracion_del_dia: int = 240

## Cuántas monedas hay que juntar para cumplir el día. También es de relleno.
@export var meta_de_monedas: int = 50

## Se emite en todas las máquinas cuando termina el día, con las cifras ya calculadas.
signal dia_terminado(numero_de_dia: int, monedas: int, clientes: int, panes: int, perdidos: int, meta: int)

## Se emite cada vez que cambia lo juntado, para que el HUD mueva su barra de meta.
signal avance_cambiado(monedas: int, meta: int)

## Por cuánto se multiplica lo que paga cada pan según el largo de la racha. La primera
## entrega paga normal y de ahí sube, hasta quedarse en el último valor de la lista.
const MULTIPLICADORES_DE_RACHA: Array[float] = [1.0, 1.5, 2.0, 3.0]

## Cuántos segundos hay para encadenar la siguiente entrega antes de que la racha se
## corte. Va casillero a casillero con la lista de multiplicadores y se acorta a
## propósito: mientras más alto el multiplicador, menos margen queda. Si no, llegar una
## vez al x3 alcanzaba para quedarse ahí el resto del día entregando sin apuro, y el
## premio por arriesgarse dejaba de ser un premio.
##
## Las dos listas se leen con el mismo índice, así que un escalón nuevo se agrega en las
## dos a la vez.
const SEGUNDOS_DE_RACHA: Array[float] = [8.0, 6.0, 4.5, 3.5]

## Se emite en todas las máquinas cuando cambia la racha, para que el HUD la muestre. Los
## segundos que manda son los de la racha recién alcanzada, que es el plazo con el que
## queda el jugador de ahí en adelante.
signal racha_cambiada(entregas_seguidas: int, multiplicador: float, segundos: float)

var numero_de_dia: int = 1

# La caja del GameManager es acumulada, así que lo del día sale de restar con cuánto se
# empezó. Si alguien compra una receta, esa plata también se descuenta del día.
var _caja_al_empezar: int = 0
var _clientes_atendidos: int = 0
var _panes_entregados: int = 0
var _clientes_perdidos: int = 0
var _dia_cerrado: bool = false

# Cuántas entregas seguidas lleva la panadería sin que se le enfríe la racha.
var _racha: int = 0

# Cuándo fue la última entrega. Solo lo usa el servidor, que es el que decide si la
# siguiente encadena o si la racha ya se cortó.
var _momento_de_la_ultima_entrega: float = 0.0


func _ready() -> void:
	if instance == null:
		instance = self
	else:
		queue_free()
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	if GameManager.instance:
		_conectar_game_manager()
	else:
		await get_tree().process_frame
		if GameManager.instance:
			_conectar_game_manager()

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_sincronizar_jornada.rpc_id(id, numero_de_dia, _caja_al_empezar, _clientes_atendidos, _panes_entregados, _clientes_perdidos, _dia_cerrado)

@rpc("authority", "call_local", "reliable")
func _sincronizar_jornada(dia: int, caja: int, clientes: int, panes: int, perdidos: int, cerrado: bool) -> void:
	numero_de_dia = dia
	_caja_al_empezar = caja
	_clientes_atendidos = clientes
	_panes_entregados = panes
	_clientes_perdidos = perdidos
	_dia_cerrado = cerrado
	avance_cambiado.emit(monedas_del_dia(), meta_de_monedas)
	
	# Si el día ya estaba cerrado cuando el jugador entró, emitimos la señal
	# para que su interfaz abra la pantalla de resumen.
	if _dia_cerrado:
		dia_terminado.emit(numero_de_dia, monedas_del_dia(), _clientes_atendidos, _panes_entregados, _clientes_perdidos, meta_de_monedas)
## Cuántas monedas lleva juntadas el día, descontando lo que se haya gastado.
func monedas_del_dia() -> int:
	if GameManager.instance == null:
		return 0
	return GameManager.instance.dinero_recaudado - _caja_al_empezar


func clientes_atendidos() -> int:
	return _clientes_atendidos


func panes_entregados() -> int:
	return _panes_entregados


## Cuántos clientes se fueron sin que los atendieran.
func clientes_perdidos() -> int:
	return _clientes_perdidos


## Lo llama quien atienda a un cliente. Cualquiera puede avisar, el servidor lleva la
## cuenta de verdad y la reparte.
func anotar_cliente_atendido() -> void:
	_anotar.rpc(1, 0, 0)


## Lo llama quien entregue un pan.
func anotar_pan_entregado() -> void:
	_anotar.rpc(0, 1, 0)


## Lo llama el puesto cuando un cliente se cansa de esperar y se va.
func anotar_cliente_perdido() -> void:
	_anotar.rpc(0, 0, 1)


## Lo llama la interfaz cuando el jugador aprieta seguir en la pantalla de cierre.
func pedir_siguiente_dia() -> void:
	_pedir_siguiente_dia.rpc()


## Lo llama el puesto justo antes de cobrar un pan. Suma esa entrega a la racha y
## devuelve por cuánto hay que multiplicar su precio. Solo tiene sentido en el servidor,
## que es el único que mueve el dinero, así que en los demás devuelve el multiplicador
## neutro y no toca nada.
func encadenar_entrega() -> float:
	if not multiplayer.is_server():
		return 1.0
	var ahora: float = _ahora()
	# El plazo que se mira es el de la racha como está ahora, que es el que el jugador
	# venía viendo correr en la barra, y no el de la entrega que recién llega.
	var sigue_la_racha: bool = _racha > 0 and ahora - _momento_de_la_ultima_entrega <= segundos_de_racha(_racha)
	_momento_de_la_ultima_entrega = ahora
	var largo: int = _racha + 1 if sigue_la_racha else 1
	_fijar_racha.rpc(largo)
	return multiplicador_de_racha(largo)


## Cuántas entregas seguidas lleva la panadería.
func racha() -> int:
	return _racha


## Por cuánto multiplica una racha de ese largo.
func multiplicador_de_racha(largo: int) -> float:
	if largo <= 0:
		return 1.0
	return MULTIPLICADORES_DE_RACHA[mini(largo - 1, MULTIPLICADORES_DE_RACHA.size() - 1)]


## Cuántos segundos quedan para encadenar cuando la racha va en ese largo. Sin racha
## devuelve el plazo más ancho, que es con el que arranca la primera entrega.
func segundos_de_racha(largo: int) -> float:
	if largo <= 0:
		return SEGUNDOS_DE_RACHA[0]
	return SEGUNDOS_DE_RACHA[mini(largo - 1, SEGUNDOS_DE_RACHA.size() - 1)]


# La racha se enfría sola. El que lleva el reloj es el servidor, y cuando se le acaba el
# plazo avisa a todas las máquinas, igual que con cualquier otro cambio del día.
func _process(_delta: float) -> void:
	if not multiplayer.is_server() or _racha <= 0:
		return
	if _ahora() - _momento_de_la_ultima_entrega > segundos_de_racha(_racha):
		_fijar_racha.rpc(0)


@rpc("authority", "call_local", "reliable")
func _fijar_racha(largo: int) -> void:
	_racha = largo
	racha_cambiada.emit(_racha, multiplicador_de_racha(_racha), segundos_de_racha(_racha))


func _ahora() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _conectar_game_manager() -> void:
	var gestor: GameManager = GameManager.instance
	gestor.timer_updated.connect(_al_cambiar_el_reloj)
	gestor.money_updated.connect(_al_cambiar_la_caja)
	_caja_al_empezar = gestor.dinero_recaudado


@rpc("any_peer", "call_local", "reliable")
func _anotar(clientes: int, panes: int, perdidos: int) -> void:
	if not multiplayer.is_server():
		return
	_sumar.rpc(clientes, panes, perdidos)


@rpc("authority", "call_local", "reliable")
func _sumar(clientes: int, panes: int, perdidos: int) -> void:
	_clientes_atendidos += clientes
	_panes_entregados += panes
	_clientes_perdidos += perdidos


@rpc("any_peer", "call_local", "reliable")
func _pedir_siguiente_dia() -> void:
	if not multiplayer.is_server():
		return
	if not _dia_cerrado:
		return
	_empezar_dia.rpc(numero_de_dia + 1)
	if GameManager.instance:
		GameManager.instance.update_time_rpc.rpc(duracion_del_dia)


@rpc("authority", "call_local", "reliable")
func _empezar_dia(numero: int) -> void:
	numero_de_dia = numero
	_clientes_atendidos = 0
	_panes_entregados = 0
	_clientes_perdidos = 0
	_dia_cerrado = false
	_racha = 0
	racha_cambiada.emit(0, 1.0, segundos_de_racha(0))
	if GameManager.instance:
		_caja_al_empezar = GameManager.instance.dinero_recaudado
	avance_cambiado.emit(0, meta_de_monedas)


func _al_cambiar_el_reloj(segundos_restantes: int) -> void:
	if segundos_restantes > 0 or _dia_cerrado:
		return
	if not multiplayer.is_server():
		return
	_cerrar_dia.rpc(numero_de_dia, monedas_del_dia(), _clientes_atendidos, _panes_entregados, _clientes_perdidos)


@rpc("authority", "call_local", "reliable")
func _cerrar_dia(numero: int, monedas: int, clientes: int, panes: int, perdidos: int) -> void:
	_dia_cerrado = true
	dia_terminado.emit(numero, monedas, clientes, panes, perdidos, meta_de_monedas)


func _al_cambiar_la_caja(_cantidad: int) -> void:
	avance_cambiado.emit(monedas_del_dia(), meta_de_monedas)
