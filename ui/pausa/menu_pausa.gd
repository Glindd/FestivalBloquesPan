class_name MenuPausa
extends Control

# Menú de pausa de la partida, con sus ajustes adentro.
#
# No pausa nada. En un juego de varios no se puede parar el mundo, porque los otros tres
# gatos siguen cocinando y el día sigue corriendo. Lo que hace es tapar la pantalla y
# soltarle el control al jugador, igual que la tienda: su gato deja de caminar y deja de
# girar la cámara mientras el panel está abierto.
#
# Los ajustes no son de la partida sino de quien juega, así que se guardan en su
# computador a través de Configuracion y no se le avisan a nadie más.

## Se emite al abrirse, para que el HUD se esconda y suelte el control del gato.
signal abierto
## Se emite al cerrarse, para devolverle el control al gato.
signal cerrado

@onready var pagina_principal: Control = %PaginaPrincipal
@onready var pagina_ajustes: Control = %PaginaAjustes
@onready var titulo: Label = %Titulo

@onready var boton_continuar: Button = %BotonContinuar
@onready var boton_ajustes: Button = %BotonAjustes
@onready var boton_salir: Button = %BotonSalir
@onready var boton_volver: Button = %BotonVolver

@onready var barra_volumen: HSlider = %BarraVolumen
@onready var barra_sensibilidad: HSlider = %BarraSensibilidad
@onready var marca_pantalla_completa: CheckButton = %PantallaCompleta


func _ready() -> void:
	hide()
	boton_continuar.pressed.connect(cerrar)
	boton_ajustes.pressed.connect(_mostrar_ajustes.bind(true))
	boton_volver.pressed.connect(_mostrar_ajustes.bind(false))
	boton_salir.pressed.connect(_salir_al_menu)
	barra_volumen.value_changed.connect(_al_mover_volumen)
	barra_sensibilidad.value_changed.connect(_al_mover_sensibilidad)
	marca_pantalla_completa.toggled.connect(_al_marcar_pantalla_completa)


# Se escucha en _unhandled_input a propósito: así los paneles que ya están abiertos, como
# la tienda o la rueda de emotes, se quedan con la tecla antes y Escape cierra lo de más
# arriba en vez de abrir el menú por encima de todo.
func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		if evento.is_action_pressed("Menu"):
			abrir()
			get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("Menu"):
		if pagina_ajustes.visible:
			_mostrar_ajustes(false)
		else:
			cerrar()
	get_viewport().set_input_as_handled()


func abrir() -> void:
	_leer_configuracion()
	_mostrar_ajustes(false)
	show()
	boton_continuar.grab_focus()
	abierto.emit()


func cerrar() -> void:
	hide()
	cerrado.emit()


func _mostrar_ajustes(mostrar: bool) -> void:
	pagina_ajustes.visible = mostrar
	pagina_principal.visible = not mostrar
	titulo.text = "Ajustes" if mostrar else "Pausa"
	if mostrar:
		barra_volumen.grab_focus()
	else:
		boton_continuar.grab_focus()


# Las barras se llenan con lo que ya estaba guardado, sin disparar los avisos de cambio:
# si no, abrir el menú contaría como mover la barra y volvería a guardar lo mismo.
func _leer_configuracion() -> void:
	if Configuracion.instance == null:
		return
	barra_volumen.set_value_no_signal(Configuracion.instance.volumen * 100.0)
	barra_sensibilidad.set_value_no_signal(Configuracion.instance.sensibilidad_en_fraccion() * 100.0)
	marca_pantalla_completa.set_pressed_no_signal(Configuracion.instance.pantalla_completa)


func _al_mover_volumen(valor: float) -> void:
	if Configuracion.instance:
		Configuracion.instance.fijar_volumen(valor / 100.0)


func _al_mover_sensibilidad(valor: float) -> void:
	if Configuracion.instance:
		Configuracion.instance.fijar_sensibilidad_en_fraccion(valor / 100.0)


func _al_marcar_pantalla_completa(activada: bool) -> void:
	if Configuracion.instance:
		Configuracion.instance.fijar_pantalla_completa(activada)


func _salir_al_menu() -> void:
	cerrar()
	if Lobby.instance:
		Lobby.instance.go_to_menu()
