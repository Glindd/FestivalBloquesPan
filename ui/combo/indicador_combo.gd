class_name IndicadorCombo
extends Control

# Muestra por cuánto se está multiplicando lo que paga cada pan mientras la panadería
# entrega varios seguidos, y cuánto queda para que se corte la racha.
#
# La cuenta regresiva la lleva cada máquina por su lado desde que le avisan de una
# entrega. No hace falta que ese reloj viaje por la red: quien decide cuándo se corta la
# racha es el servidor, y cuando lo decide avisa igual que con cualquier otro cambio.

## Desde cuántas entregas seguidas se muestra el indicador. Con una sola el pan se paga
## a precio normal, así que no hay nada que mostrar.
const RACHA_MINIMA: int = 2

const DURACION_DEL_LATIDO: float = 0.18
## El salto lo da la placa entera y no solo el número, así que con menos alcanza: a ese
## tamaño un 1.3 se sale de donde está parada y se come el reloj de arriba.
const ESCALA_DEL_LATIDO: float = 1.2
const DURACION_DEL_FUNDIDO: float = 0.25

@onready var placa: Control = %Placa
@onready var numero: Label = %Numero
@onready var barra: TextureProgressBar = %BarraRacha

var _segundos_de_ventana: float = 0.0
var _segundos_restantes: float = 0.0
var _latido: Tween
var _fundido: Tween


func _ready() -> void:
	modulate.a = 0.0
	placa.pivot_offset = placa.size * 0.5
	if Jornada.instance:
		Jornada.instance.racha_cambiada.connect(_al_cambiar_la_racha)
		return
	await get_tree().process_frame
	if Jornada.instance:
		Jornada.instance.racha_cambiada.connect(_al_cambiar_la_racha)


func _process(delta: float) -> void:
	if _segundos_restantes <= 0.0:
		return
	_segundos_restantes = maxf(_segundos_restantes - delta, 0.0)
	if _segundos_de_ventana > 0.0:
		barra.value = _segundos_restantes / _segundos_de_ventana * 100.0
	if _segundos_restantes <= 0.0:
		_apagar()


func _al_cambiar_la_racha(entregas_seguidas: int, multiplicador: float, segundos: float) -> void:
	if entregas_seguidas < RACHA_MINIMA:
		_apagar()
		return
	numero.text = _texto_del_multiplicador(multiplicador)
	_segundos_de_ventana = segundos
	_segundos_restantes = segundos
	barra.value = 100.0
	_encender()
	_latir()


# Un x2 se lee mejor que un x2.0, pero el x1.5 necesita su decimal.
func _texto_del_multiplicador(multiplicador: float) -> String:
	if is_equal_approx(multiplicador, roundf(multiplicador)):
		return "x%d" % int(roundf(multiplicador))
	return "x%.1f" % multiplicador


func _encender() -> void:
	if _fundido and _fundido.is_running():
		_fundido.kill()
	_fundido = create_tween()
	_fundido.tween_property(self, "modulate:a", 1.0, DURACION_DEL_FUNDIDO)


func _apagar() -> void:
	_segundos_restantes = 0.0
	if is_zero_approx(modulate.a):
		return
	if _fundido and _fundido.is_running():
		_fundido.kill()
	_fundido = create_tween()
	_fundido.tween_property(self, "modulate:a", 0.0, DURACION_DEL_FUNDIDO)


# Un salto corto cada vez que sube la racha, para que se note sin tener que leer.
func _latir() -> void:
	if _latido and _latido.is_running():
		_latido.kill()
	placa.pivot_offset = placa.size * 0.5
	placa.scale = Vector2.ONE * ESCALA_DEL_LATIDO
	_latido = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_latido.tween_property(placa, "scale", Vector2.ONE, DURACION_DEL_LATIDO)
