class_name PanelArbol
extends Control

# Panel del árbol de mejoras. Muestra lo que la panadería puede comprar para mejorarse y
# deja apretar lo que ya esté al alcance.
#
# El panel no compra ni cobra nada por su cuenta. Le pide la compra a Mejoras, que la
# valida en el servidor y después avisa a todas las máquinas. Por eso el panel se refresca
# escuchando esa confirmación y no en el momento en que alguien aprieta, igual que la
# tienda de recetas.
#
# El árbol se dibuja a partir de los datos y no a mano en la escena: las ramas y los
# escalones salen de la ficha de cada mejora, así que agregar una no obliga a tocar esta
# escena ni a reacomodar nada.

## Se emite al cerrar el panel, para que quien lo abrió devuelva el control al juego.
signal cerrada

## La escena de medallón con que se arma cada nodo.
@export var escena_medallon: PackedScene

## Los dibujos con que se unen los medallones.
@export var dibujo_rama_vertical: Texture2D
@export var dibujo_rama_horizontal: Texture2D

## Cuánto mide un medallón en pantalla, y cuánto separa a uno de otro.
const MEDALLON: float = 110.0
const ANCHO_DE_RAMA: float = 240.0
const ALTO_DE_ESCALON: float = 140.0

## Dónde empieza el árbol dentro del lienzo, y cuánto queda el tronco por encima de la
## primera fila de medallones.
const MARGEN_SUPERIOR: float = 255.0
const ALTURA_DEL_TRONCO: float = 100.0

## A qué tamaño se dibujan las ramas respecto de su archivo. Sale del medallón para que
## el grosor del trazo y el porte de los nodos queden en la misma proporción en que los
## dibujaron.
const ESCALA_DE_LAS_RAMAS: float = MEDALLON / 581.0

## Cuánto miden los topes ensanchados de las puntas de las rectas, en píxeles del
## archivo. Las rectas se dibujan sin esos topes, estirando solo el trozo del medio: si
## se dejan, cada tramo marca sus dos puntas y la rama queda llena de escalones donde se
## junta con una esquina o con un medallón. Quien cierra el dibujo es la pieza de unión.
const TOPE_VERTICAL: int = 75
const TOPE_HORIZONTAL: int = 80

## Cómo se apaga un tramo que todavía no se recorrió. Un camino solo se prende cuando la
## mejora a la que lleva está comprada, así el árbol se va encendiendo a medida que
## alguien avanza.
const RAMA_APAGADA: Color = Color(0.62, 0.60, 0.57, 0.85)

## Cuánto sobresale la barra del tronco más allá del brazo de los extremos, para que sus
## topes queden como remate a los lados en vez de cortados a ras.
const VUELO_DEL_TRONCO: float = 26.0

## Cuánto queda el globo de ayuda por encima del medallón al que apunta.
const SEPARACION_DEL_GLOBO: float = 14.0

@onready var lienzo: Control = %Lienzo
@onready var ramas: Control = %Ramas
@onready var dinero_mostrado: Label = %Dinero
@onready var boton_cerrar: Button = %BotonCerrar
@onready var globo: TextureRect = %Globo
@onready var nombre_mostrado: Label = %NombreMejora
@onready var detalle_mostrado: Label = %DetalleMejora

var _medallones: Array[MedallonMejora] = []
# Qué tramos de rama llevan a cada mejora, para apagarlos mientras no esté comprada.
var _caminos: Dictionary[StringName, Array] = {}
var _dinero: int = 0


func _ready() -> void:
	hide()
	_esconder_globo()
	boton_cerrar.pressed.connect(cerrar)
	if Mejoras.instance:
		Mejoras.instance.mejora_comprada.connect(_al_comprarse_una_mejora)
	if GameManager.instance:
		_conectar_game_manager()
	else:
		await get_tree().process_frame
		if GameManager.instance:
			_conectar_game_manager()
	_armar_el_arbol()


# Con el panel abierto se consume todo lo que no haya usado la interfaz. Si no, el gato
# seguiría girando la cámara y tomando objetos por detrás del panel.
func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento.is_action_pressed("ui_cancel"):
		cerrar()
	get_viewport().set_input_as_handled()


func abrir() -> void:
	_esconder_globo()
	show()
	_refrescar()


func cerrar() -> void:
	_esconder_globo()
	hide()
	cerrada.emit()


# ---- armado ----

# Se arma una sola vez. Lo que cambia después es el estado de cada medallón, no dónde
# está puesto, así que no hace falta rehacer nodos cada vez que alguien compra.
func _armar_el_arbol() -> void:
	var arbol: MejoraSet = _datos()
	if arbol == null or escena_medallon == null:
		return
	var cuantas: int = arbol.cuantas_ramas()
	if cuantas <= 0:
		return
	for numero: int in cuantas:
		var escalones: Array[MejoraDef] = arbol.de_la_rama(numero)
		for i: int in escalones.size():
			_crear_medallon(escalones[i], _centro(numero, i))
		_unir_escalones(numero, escalones)
	_dibujar_tronco(cuantas)


func _crear_medallon(def: MejoraDef, centro: Vector2) -> void:
	var medallon: MedallonMejora = escena_medallon.instantiate()
	lienzo.add_child(medallon)
	medallon.size = Vector2(MEDALLON, MEDALLON)
	medallon.position = centro - Vector2(MEDALLON, MEDALLON) * 0.5
	medallon.mostrar(def)
	medallon.compra_pedida.connect(_al_pedir_compra)
	medallon.apuntada.connect(_mostrar_globo)
	medallon.soltada.connect(_esconder_globo)
	_medallones.push_back(medallon)


# El centro en pantalla del escalón de una rama. El árbol queda centrado en el lienzo,
# así que agregar una rama no deja todo corrido hacia un lado.
func _centro(rama: int, escalon: int) -> Vector2:
	var cuantas: int = _datos().cuantas_ramas()
	var ancho_total: float = float(cuantas - 1) * ANCHO_DE_RAMA
	var x: float = (lienzo.size.x - ancho_total) * 0.5 + float(rama) * ANCHO_DE_RAMA
	var y: float = MARGEN_SUPERIOR + float(escalon) * ALTO_DE_ESCALON
	return Vector2(x, y)


# Cada tramo queda anotado a nombre de la mejora a la que lleva, para poder apagarlo
# mientras esa mejora no esté comprada.
func _unir_escalones(rama: int, escalones: Array[MejoraDef]) -> void:
	for i: int in maxi(escalones.size() - 1, 0):
		var arriba: Vector2 = _centro(rama, i)
		var abajo: Vector2 = _centro(rama, i + 1)
		var tramo: Control = _rama_vertical(arriba.x, arriba.y + MEDALLON * 0.5 - 8.0, abajo.y - MEDALLON * 0.5 + 8.0)
		_anotar_camino(escalones[i + 1].id, tramo)


func _anotar_camino(id_mejora: StringName, tramo: Control) -> void:
	if tramo == null:
		return
	if not _caminos.has(id_mejora):
		_caminos[id_mejora] = [] as Array[Control]
	_caminos[id_mejora].push_back(tramo)


# El tronco cruza por arriba y de él bajan las ramas. Las esquinas y el cruce vienen
# dibujados con el brazo hacia arriba, así que se dan vuelta para que salga hacia abajo.
# El tronco va de una sola barra y los brazos pasan por debajo.
#
# Antes lo armaba con la esquina y el cruce, y se veía mal en cada unión. El motivo es que
# cada pieza trae su propio contorno cerrado: junten como se junten, siempre se ven los dos
# contornos encontrándose. No hay forma de empalmar dos piezas de este kit sin que se note.
# Dibujando una barra entera el problema desaparece, porque no hay nada que empalmar, y los
# brazos saliendo de abajo se leen como corresponde.
func _dibujar_tronco(cuantas: int) -> void:
	var y: float = _centro(0, 0).y - ALTURA_DEL_TRONCO
	# Los brazos van primero, para que la barra se dibuje encima y les tape la punta.
	for numero: int in cuantas:
		var bajada: Control = _rama_vertical(_centro(numero, 0).x, y, _centro(numero, 0).y - MEDALLON * 0.5 + 8.0)
		var raices: Array[MejoraDef] = _datos().de_la_rama(numero)
		if not raices.is_empty():
			_anotar_camino(raices[0].id, bajada)
	if cuantas > 1:
		_rama_horizontal(
				_centro(0, 0).x - VUELO_DEL_TRONCO,
				_centro(cuantas - 1, 0).x + VUELO_DEL_TRONCO,
				y, true)


# Una rama recta que se estira entre dos puntos. Se dibuja con 9 cortes para que los
# topes de las puntas queden del mismo porte sea cual sea el largo, y se escala entera
# para que el grosor calce con el de los medallones.
func _rama_vertical(x: float, y0: float, y1: float) -> Control:
	var largo: float = y1 - y0
	if largo <= 1.0 or dibujo_rama_vertical == null:
		return null
	var ancho: float = float(dibujo_rama_vertical.get_width())
	var alto: float = float(dibujo_rama_vertical.get_height())
	var pieza: NinePatchRect = NinePatchRect.new()
	pieza.texture = dibujo_rama_vertical
	pieza.region_rect = Rect2(0.0, float(TOPE_VERTICAL), ancho, alto - float(TOPE_VERTICAL * 2))
	pieza.scale = Vector2(ESCALA_DE_LAS_RAMAS, ESCALA_DE_LAS_RAMAS)
	pieza.size = Vector2(ancho, largo / ESCALA_DE_LAS_RAMAS)
	pieza.position = Vector2(x - ancho * ESCALA_DE_LAS_RAMAS * 0.5, y0)
	pieza.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ramas.add_child(pieza)
	return pieza


func _rama_horizontal(x0: float, x1: float, y: float, con_topes: bool = false) -> Control:
	var largo: float = x1 - x0
	if largo <= 1.0 or dibujo_rama_horizontal == null:
		return null
	var ancho: float = float(dibujo_rama_horizontal.get_width())
	var alto: float = float(dibujo_rama_horizontal.get_height())
	var pieza: NinePatchRect = NinePatchRect.new()
	pieza.texture = dibujo_rama_horizontal
	# Con topes se dibuja entera y se estira solo el centro. Sin ellos se usa nada más el
	# trozo del medio, que es lo que hace falta cuando otra cosa va a cerrar la punta.
	if con_topes:
		pieza.patch_margin_left = TOPE_HORIZONTAL
		pieza.patch_margin_right = TOPE_HORIZONTAL
	else:
		pieza.region_rect = Rect2(float(TOPE_HORIZONTAL), 0.0, ancho - float(TOPE_HORIZONTAL * 2), alto)
	pieza.scale = Vector2(ESCALA_DE_LAS_RAMAS, ESCALA_DE_LAS_RAMAS)
	pieza.size = Vector2(largo / ESCALA_DE_LAS_RAMAS, alto)
	pieza.position = Vector2(x0, y - alto * ESCALA_DE_LAS_RAMAS * 0.5)
	pieza.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ramas.add_child(pieza)
	return pieza


# Las esquinas y el cruce van a tamaño fijo, y se dan vuelta porque vienen dibujados con
# el brazo hacia arriba.
#
# El punto por el que se cuelgan no es una esquina de la imagen sino el cruce de sus dos
# brazos, medido en píxeles del archivo. Antes las colgaba de su borde y por eso el tronco
# quedaba desarmado: el brazo horizontal no toca el borde de la pieza, le quedan los topes
# ensanchados por fuera.
# ---- estado ----

func _refrescar() -> void:
	if not is_inside_tree() or Mejoras.instance == null:
		return
	for medallon: MedallonMejora in _medallones:
		if medallon.mejora == null:
			continue
		medallon.cambiar_estado(_estado_de(medallon.mejora))
	for id_mejora: StringName in _caminos:
		var encendido: bool = Mejoras.instance.esta_comprada(id_mejora)
		for tramo: Control in _caminos[id_mejora]:
			tramo.modulate = Color.WHITE if encendido else RAMA_APAGADA


# Una mejora comprada se muestra comprada aunque no alcance la plata. Una que el árbol
# todavía no abrió se muestra bloqueada. Y la que está abierta pero no se puede pagar
# igual se muestra disponible, con su precio a la vista: el jugador tiene que poder ver
# cuánto le falta.
func _estado_de(def: MejoraDef) -> MedallonMejora.Estado:
	if Mejoras.instance.esta_comprada(def.id):
		return MedallonMejora.Estado.COMPRADA
	if Mejoras.instance.esta_disponible(def.id):
		return MedallonMejora.Estado.DISPONIBLE
	return MedallonMejora.Estado.BLOQUEADA


func _al_pedir_compra(id_mejora: StringName) -> void:
	if Mejoras.instance == null:
		return
	var def: MejoraDef = _datos().buscar_por_id(id_mejora)
	if def == null or _dinero < def.precio:
		return
	Mejoras.instance.pedir_compra.rpc(id_mejora)


# Llega cuando el servidor confirmó una compra, sea de este jugador o de otro.
func _al_comprarse_una_mejora(_id_mejora: StringName) -> void:
	_refrescar()


func _conectar_game_manager() -> void:
	var gestor: GameManager = GameManager.instance
	gestor.money_updated.connect(_al_cambiar_el_dinero)
	_al_cambiar_el_dinero(gestor.dinero_recaudado)


func _al_cambiar_el_dinero(cantidad: int) -> void:
	_dinero = cantidad
	dinero_mostrado.text = "%d" % cantidad
	_refrescar()


# ---- el globo de ayuda ----

func _mostrar_globo(medallon: MedallonMejora) -> void:
	if medallon.mejora == null:
		return
	nombre_mostrado.text = medallon.mejora.nombre
	detalle_mostrado.text = medallon.mejora.descripcion
	globo.show()
	# Se acomoda después de que el globo midió su texto, para que quede centrado sobre el
	# medallón y no corrido por el ancho que tenía antes.
	await get_tree().process_frame
	if not globo.visible:
		return
	var centro: Vector2 = medallon.global_position + medallon.size * 0.5
	globo.global_position = Vector2(
			centro.x - globo.size.x * 0.5,
			centro.y - medallon.size.y * 0.5 - globo.size.y - SEPARACION_DEL_GLOBO)


func _esconder_globo() -> void:
	globo.hide()


func _datos() -> MejoraSet:
	return Mejoras.instance.arbol if Mejoras.instance else null
