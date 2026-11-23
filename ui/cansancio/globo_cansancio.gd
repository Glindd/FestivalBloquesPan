class_name GloboCansancio
extends Node3D

# Barra de aguante que flota sobre la torre de gatos, para los demás jugadores.
#
# El que carga ve su propia barra en el HUD, pero los demás no tenían cómo saber cuánto le
# quedaba, y la torre se les caía encima sin aviso. Esto lo muestra desde afuera: cuánto
# aguanta todavía el de abajo, y después, cuando quedan sueltos, cuánto lleva recuperado.
#
# Cuelga del gato de arriba y no del de abajo. Al armarse la torre el de abajo se esconde
# entero, y en Godot un hijo de algo escondido tampoco se dibuja, así que un globo colgado
# ahí no se vería nunca.
#
# La barra se vacía de derecha a izquierda escalando un pivote que está pegado a su borde
# izquierdo, igual que la paciencia del cliente. Y el globo entero gira para quedar de
# frente a la cámara, en vez de que cada dibujo mire por su cuenta: así la barra se vacía
# derecho y no torcida.

## Los mismos colores y cortes que usan la barra del HUD y la paciencia del cliente, para
## que el verde, el naranjo y el rojo signifiquen lo mismo en toda la pantalla.
const COLOR_TRANQUILO: Color = Color(0.4313726, 0.56078434, 0.33333334)
const COLOR_APURADO: Color = Color(0.8784314, 0.5921569, 0.22745098)
const COLOR_ENOJADO: Color = Color(0.6117647, 0.18431373, 0.13333334)

const AGUANTE_APURADO: float = 0.5
const AGUANTE_ENOJADO: float = 0.25

@onready var pivote: Node3D = $Pivote
@onready var relleno: Sprite3D = $Pivote/Relleno


func _ready() -> void:
	hide()


func _process(_delta: float) -> void:
	if not visible:
		return
	var camara: Camera3D = get_viewport().get_camera_3d()
	if camara == null:
		return
	# Se gira solo en el eje vertical para que quede de frente sin inclinarse. look_at deja
	# la espalda mirando a la cámara, así que después se da vuelta.
	var hacia: Vector3 = camara.global_position
	hacia.y = global_position.y
	if hacia.is_equal_approx(global_position):
		return
	look_at(hacia, Vector3.UP)
	rotate_object_local(Vector3.UP, PI)


## Cuánto aguante le queda a quien se está mostrando, de 1 a 0.
func mostrar(fraccion: float) -> void:
	var avance: float = clampf(fraccion, 0.0, 1.0)
	show()
	pivote.scale.x = maxf(avance, 0.001)
	relleno.visible = avance > 0.0
	relleno.modulate = _color_del_aguante(avance)


func esconder() -> void:
	hide()


func _color_del_aguante(avance: float) -> Color:
	if avance <= AGUANTE_ENOJADO:
		return COLOR_ENOJADO
	if avance <= AGUANTE_APURADO:
		return COLOR_APURADO
	return COLOR_TRANQUILO
