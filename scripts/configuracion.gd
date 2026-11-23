class_name Configuracion
extends Node

# Las preferencias de quien está jugando, guardadas en su propio computador. No tienen
# nada que ver con la partida ni viajan por la red: cada uno ajusta su volumen, su
# sensibilidad y si juega en pantalla completa, y eso no le cambia nada a los demás.
#
# Vive como autoload para que el menú de pausa y el gato lean lo mismo, y para que las
# preferencias ya estén puestas antes de que empiece la partida.

const RUTA: String = "user://configuracion.cfg"
const SECCION: String = "juego"

const VOLUMEN_POR_DEFECTO: float = 0.8
const SENSIBILIDAD_POR_DEFECTO: float = 0.005
## Entre qué valores se mueve la sensibilidad del mouse. El número que usa el gato es
## chico, así que el menú muestra un porcentaje dentro de este rango y no el número.
const SENSIBILIDAD_MINIMA: float = 0.001
const SENSIBILIDAD_MAXIMA: float = 0.015

static var instance: Configuracion

## Se emite cuando cambia cualquier preferencia, para que quien dependa de ellas se
## entere sin tener que preguntar en cada cuadro.
signal cambiada

var volumen: float = VOLUMEN_POR_DEFECTO
var sensibilidad_del_mouse: float = SENSIBILIDAD_POR_DEFECTO
var pantalla_completa: bool = false


func _ready() -> void:
	if instance == null:
		instance = self
	else:
		queue_free()
		return
	_cargar()
	_aplicar_volumen()
	# Al arrancar desde el editor la ventana no se toca. Las pruebas se corren con tres
	# ventanas repartidas en la pantalla, y una que se va a pantalla completa tapa a las
	# otras dos. El botón del menú de pausa la sigue cambiando en el momento, así que la
	# preferencia se puede probar igual.
	if not OS.has_feature("editor"):
		_aplicar_pantalla_completa()
	cambiada.emit()


## Qué tan lejos está la sensibilidad de su mínimo, de 0 a 1. Es lo que muestra el menú,
## porque el número de verdad no le dice nada a nadie.
func sensibilidad_en_fraccion() -> float:
	var ancho: float = SENSIBILIDAD_MAXIMA - SENSIBILIDAD_MINIMA
	if is_zero_approx(ancho):
		return 0.0
	return clampf((sensibilidad_del_mouse - SENSIBILIDAD_MINIMA) / ancho, 0.0, 1.0)


func fijar_volumen(nuevo: float) -> void:
	volumen = clampf(nuevo, 0.0, 1.0)
	_aplicar()
	_guardar()


func fijar_sensibilidad_en_fraccion(fraccion: float) -> void:
	var f: float = clampf(fraccion, 0.0, 1.0)
	sensibilidad_del_mouse = SENSIBILIDAD_MINIMA + f * (SENSIBILIDAD_MAXIMA - SENSIBILIDAD_MINIMA)
	_aplicar()
	_guardar()


func fijar_pantalla_completa(activada: bool) -> void:
	pantalla_completa = activada
	_aplicar()
	_guardar()


func _aplicar() -> void:
	_aplicar_volumen()
	_aplicar_pantalla_completa()
	cambiada.emit()


func _aplicar_volumen() -> void:
	var bus: int = AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, is_zero_approx(volumen))
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volumen, 0.0001)))


# En headless no hay ventana que cambiar, y pedirlo igual llena la consola de avisos.
func _aplicar_pantalla_completa() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var modo: int = DisplayServer.WINDOW_MODE_FULLSCREEN if pantalla_completa else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != modo:
		DisplayServer.window_set_mode(modo)


func _cargar() -> void:
	var archivo: ConfigFile = ConfigFile.new()
	if archivo.load(RUTA) != OK:
		return
	volumen = clampf(float(archivo.get_value(SECCION, "volumen", VOLUMEN_POR_DEFECTO)), 0.0, 1.0)
	sensibilidad_del_mouse = clampf(
		float(archivo.get_value(SECCION, "sensibilidad", SENSIBILIDAD_POR_DEFECTO)),
		SENSIBILIDAD_MINIMA, SENSIBILIDAD_MAXIMA)
	pantalla_completa = bool(archivo.get_value(SECCION, "pantalla_completa", false))


func _guardar() -> void:
	var archivo: ConfigFile = ConfigFile.new()
	archivo.set_value(SECCION, "volumen", volumen)
	archivo.set_value(SECCION, "sensibilidad", sensibilidad_del_mouse)
	archivo.set_value(SECCION, "pantalla_completa", pantalla_completa)
	archivo.save(RUTA)
