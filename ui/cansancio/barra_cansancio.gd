class_name BarraCansancio
extends Control

# Cuánto aguante le queda al gato de esta máquina mientras carga a otro encima.
#
# Aparece sola cuando hace falta y se va cuando no: con el gato suelto y entero no hay
# nada que mirar, y el HUD de la cocina ya tiene bastante. Se queda a la vista mientras
# se recupera, para que el jugador sepa cuándo puede volver a cargar.
#
# El número lo lleva el gato, no esta barra. Acá solo se lee y se pinta, igual que el
# resto del HUD.

## Los mismos colores y los mismos cortes que usa la paciencia del cliente, para que en
## toda la pantalla el verde, el naranjo y el rojo signifiquen lo mismo.
const COLOR_TRANQUILO: Color = Color(0.4313726, 0.56078434, 0.33333334)
const COLOR_APURADO: Color = Color(0.8784314, 0.5921569, 0.22745098)
const COLOR_ENOJADO: Color = Color(0.6117647, 0.18431373, 0.13333334)

const AGUANTE_APURADO: float = 0.5
const AGUANTE_ENOJADO: float = 0.25

const DURACION_DEL_FUNDIDO: float = 0.25

@onready var barra: TextureProgressBar = %Barra

var _jugador: Player
var _a_la_vista: bool = false
var _fundido: Tween


func _ready() -> void:
	modulate.a = 0.0
	set_process(false)


## Lo llama el HUD con el gato de esta máquina. Sin gato no hay nada que seguir.
func seguir(jugador: Player) -> void:
	_jugador = jugador
	set_process(jugador != null)


func _process(_delta: float) -> void:
	if not is_instance_valid(_jugador):
		return
	var queda: float = _jugador.fraccion_de_aguante()
	barra.value = queda * 100.0
	barra.tint_progress = _color_del_aguante(queda)
	_mostrar(_jugador.esta_cargando() or queda < 1.0)


func _color_del_aguante(queda: float) -> Color:
	if queda <= AGUANTE_ENOJADO:
		return COLOR_ENOJADO
	if queda <= AGUANTE_APURADO:
		return COLOR_APURADO
	return COLOR_TRANQUILO


func _mostrar(quiero_verla: bool) -> void:
	if quiero_verla == _a_la_vista:
		return
	_a_la_vista = quiero_verla
	if _fundido and _fundido.is_running():
		_fundido.kill()
	_fundido = create_tween()
	_fundido.tween_property(self, "modulate:a", 1.0 if quiero_verla else 0.0, DURACION_DEL_FUNDIDO)
