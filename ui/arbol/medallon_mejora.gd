class_name MedallonMejora
extends Control

# Un medallón del árbol: el marco que dice en qué estado está la mejora, el dibujo de lo
# que hace y la etiqueta con lo que cuesta.
#
# El medallón no sabe de dinero ni de compras. Muestra lo que le pasan y avisa cuando lo
# aprietan, igual que las cartas de la tienda. Quien decide es el panel, y antes que él
# el servidor.

enum Estado {BLOQUEADA, DISPONIBLE, COMPRADA}

## Se emite cuando el jugador aprieta un medallón que se puede comprar.
signal compra_pedida(id_mejora: StringName)
## Se emiten al pasar el mouse por encima, para que el panel mueva su globo de ayuda.
signal apuntada(medallon: MedallonMejora)
signal soltada

@export var dibujo_bloqueada: Texture2D
@export var dibujo_disponible: Texture2D
@export var dibujo_comprada: Texture2D

## Qué parte del medallón ocupa el dibujo de la mejora.
const PARTE_DEL_ICONO: float = 0.54

## Lo mismo cuando la mejora está bloqueada. Ahí el dibujo se achica y sube un poco,
## porque el candado del marco va abajo y si no se le encima.
const PARTE_DEL_ICONO_BLOQUEADO: float = 0.40
const SUBIDA_DEL_ICONO_BLOQUEADO: float = 0.09

## Lo que late el marco de una mejora que ya se puede comprar, y cuánto dura cada ida o
## vuelta del latido. Es lo único que se mueve en todo el panel, así que alcanza para
## llevarle el ojo al jugador sin tener que escribirle nada.
const BRILLO_DEL_PULSO: Color = Color(1.22, 1.14, 0.9)
const DURACION_DEL_PULSO: float = 0.65

@onready var marco: TextureRect = %Marco
@onready var icono: TextureRect = %Icono
@onready var etiqueta: TextureRect = %Etiqueta
@onready var precio: Label = %Precio
@onready var insignia: TextureRect = %Insignia
@onready var boton: Button = %Boton

var mejora: MejoraDef
var _estado: Estado = Estado.BLOQUEADA
var _pulso: Tween


func _ready() -> void:
	boton.pressed.connect(_al_apretar)
	boton.mouse_entered.connect(func() -> void: apuntada.emit(self))
	boton.mouse_exited.connect(func() -> void: soltada.emit())


func mostrar(def: MejoraDef) -> void:
	mejora = def
	icono.texture = def.icono
	precio.text = "$%d" % def.precio
	_acomodar_icono()


# El dibujo se acomoda al porte del medallón, no al porte del archivo, para que todos se
# vean iguales aunque sus imágenes vengan de distinto tamaño.
func _acomodar_icono() -> void:
	var bloqueado: bool = _estado == Estado.BLOQUEADA
	var parte: float = PARTE_DEL_ICONO_BLOQUEADO if bloqueado else PARTE_DEL_ICONO
	var lado: float = size.x * parte
	var sube: float = size.y * SUBIDA_DEL_ICONO_BLOQUEADO if bloqueado else 0.0
	icono.offset_left = -lado * 0.5
	icono.offset_right = lado * 0.5
	icono.offset_top = -lado * 0.5 - sube
	icono.offset_bottom = lado * 0.5 - sube


func cambiar_estado(nuevo: Estado) -> void:
	_estado = nuevo
	match nuevo:
		Estado.BLOQUEADA:
			marco.texture = dibujo_bloqueada
		Estado.DISPONIBLE:
			marco.texture = dibujo_disponible
		Estado.COMPRADA:
			marco.texture = dibujo_comprada
	# Lo comprado muestra su cinta y deja de mostrar el precio, porque ya no se paga.
	var comprada: bool = nuevo == Estado.COMPRADA
	insignia.visible = comprada
	etiqueta.visible = not comprada
	# El dibujo de una mejora que todavía no se puede comprar se apaga y se achica, para
	# que el candado del marco se lea antes que el ícono y no se le encime.
	icono.modulate.a = 0.45 if nuevo == Estado.BLOQUEADA else 1.0
	_acomodar_icono()
	boton.disabled = nuevo != Estado.DISPONIBLE
	_latir(nuevo == Estado.DISPONIBLE)


# El marco late mientras la mejora esté al alcance. Se apaga al comprarla o si deja de
# estarlo, y el latido se corta antes de empezar otro para que no se superpongan dos.
func _latir(encender: bool) -> void:
	if _pulso:
		_pulso.kill()
		_pulso = null
	marco.modulate = Color.WHITE
	if not encender:
		return
	_pulso = create_tween().set_loops()
	_pulso.tween_property(marco, "modulate", BRILLO_DEL_PULSO, DURACION_DEL_PULSO).set_trans(Tween.TRANS_SINE)
	_pulso.tween_property(marco, "modulate", Color.WHITE, DURACION_DEL_PULSO).set_trans(Tween.TRANS_SINE)


func _al_apretar() -> void:
	if mejora and _estado == Estado.DISPONIBLE:
		compra_pedida.emit(mejora.id)
