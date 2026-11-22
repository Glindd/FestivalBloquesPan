extends Control

@onready var hud: Control = $"."


@onready var mostradorDinero: Label = %Dinero
@export var jugador: Player
## El panel de la tienda que abre el botón del toldo. Vive fuera del HUD porque tapa
## la pantalla entera, así que se enlaza desde la escena del gato.
@export var tienda: Tienda
## El panel que resume la jornada cuando se acaba el día. También vive fuera del HUD
## porque tapa la pantalla entera.
@export var cierre: CierreDeDia
## El menú de pausa, que también tapa la pantalla entera y vive fuera del HUD.
@export var pausa: MenuPausa
@onready var barra_trabajo: TextureProgressBar = %BarraTrabajo
@onready var boton_tienda: Button = %BotonTienda
@onready var barra_meta: TextureProgressBar = %BarraMeta
@onready var barra_cansancio: BarraCansancio = $BarraCansancio

func _ready() -> void:
	if GameManager.instance:
		_conectar_game_manager()
	else:
		await  get_tree().process_frame
		if GameManager.instance:
			_conectar_game_manager()
	if not is_multiplayer_authority():
		hud.hide()
		barra_trabajo.visible = false
	_preparar_tienda()
	_preparar_pausa()
	_preparar_cansancio()
	_preparar_jornada()

# La barra de aguante solo la sigue el HUD del gato de esta máquina. Los otros gatos traen
# su propio HUD escondido, y no tiene sentido que anden calculando una barra que nadie ve.
func _preparar_cansancio() -> void:
	if not is_multiplayer_authority():
		return
	barra_cansancio.seguir(jugador)
	
# El botón solo aparece si la escena trae una tienda enlazada. Mientras está abierta el
# gato deja de caminar, porque el jugador está mirando el panel y no la cocina.
func _preparar_tienda() -> void:
	boton_tienda.visible = tienda != null
	if tienda == null:
		return
	boton_tienda.pressed.connect(_abrir_tienda)
	tienda.cerrada.connect(_al_cerrar_tienda)

# El HUD se esconde entero mientras dura la tienda. El panel lo tapaba a medias y el
# reloj quedaba cortado por el borde, y además la tienda ya muestra el dinero.
func _abrir_tienda() -> void:
	tienda.abrir()
	_cambiar_marca_de_interfaz(true)
	hud.hide()

func _al_cerrar_tienda() -> void:
	_cambiar_marca_de_interfaz(false)
	hud.visible = is_multiplayer_authority()

# El menú de pausa se comporta igual que la tienda: tapa la pantalla, así que mientras
# está abierto el HUD se esconde y el gato deja de caminar.
func _preparar_pausa() -> void:
	if pausa == null:
		return
	pausa.abierto.connect(_al_abrir_la_pausa)
	pausa.cerrado.connect(_al_cerrar_la_pausa)

func _al_abrir_la_pausa() -> void:
	_cambiar_marca_de_interfaz(true)
	hud.hide()

func _al_cerrar_la_pausa() -> void:
	_cambiar_marca_de_interfaz(false)
	hud.visible = is_multiplayer_authority()

# La jornada avisa cuándo se acaba el día y cuánto se lleva juntado. El HUD solo
# muestra: no decide cuándo termina ni cuánto falta.
#
# Cada gato de la partida trae su propio HUD, también los de los demás jugadores. Solo
# el del jugador de esta máquina escucha a la jornada, porque si no se abriría un panel
# de cierre por gato y habría que cerrarlos todos de a uno.
func _preparar_jornada() -> void:
	if not is_multiplayer_authority():
		return
	if Jornada.instance == null:
		return
	Jornada.instance.avance_cambiado.connect(_al_cambiar_el_avance)
	_al_cambiar_el_avance(Jornada.instance.monedas_del_dia(), Jornada.instance.meta_de_monedas)
	if cierre == null:
		return
	Jornada.instance.dia_terminado.connect(_al_terminar_el_dia)
	cierre.continuado.connect(_al_empezar_otro_dia)

func _al_cambiar_el_avance(monedas: int, meta: int) -> void:
	if meta <= 0:
		barra_meta.value = 0.0
		return
	barra_meta.value = clampf(float(monedas) / float(meta) * 100.0, 0.0, 100.0)

# El HUD se esconde igual que con la tienda, porque el panel de cierre tapa todo.
func _al_terminar_el_dia(numero_de_dia: int, monedas: int, clientes: int, panes: int, perdidos: int, meta: int) -> void:
	cierre.mostrar(numero_de_dia, monedas, clientes, panes, perdidos, meta)
	_cambiar_marca_de_interfaz(true)
	hud.hide()

func _al_empezar_otro_dia() -> void:
	_cambiar_marca_de_interfaz(false)
	hud.visible = is_multiplayer_authority()
	if Jornada.instance:
		Jornada.instance.pedir_siguiente_dia()

func _cambiar_marca_de_interfaz(abierta: bool) -> void:
	if jugador and jugador.input_synchronizer:
		jugador.input_synchronizer.interfaz_abierta = abierta

func _conectar_game_manager() -> void:
	var gm:GameManager = GameManager.instance
	gm.money_updated.connect(_on_dinero_actualizado)
	# La barra de trabajo depende del gato. Sin gato asignado el resto del HUD igual sirve.
	if jugador:
		jugador.tiempo_trabajando.connect(_trabajando)
	_on_dinero_actualizado(gm.dinero_recaudado)

func _trabajando(tiempo:int) -> void:
	barra_trabajo.visible = true
	barra_trabajo.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(barra_trabajo, "modulate:a", 1.0, 0.3)
	tween.tween_property(barra_trabajo, "value", 100, tiempo-0.4)
	await tween.finished
	
	var fade_tween: Tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN)
	
	fade_tween.tween_property(barra_trabajo, "modulate:a", 0.0, 0.4)
	await fade_tween.finished
	barra_trabajo.visible = false
	barra_trabajo.value = 0

func _on_dinero_actualizado(nuevo_dinero:int) -> void:
	mostradorDinero.text = "%d" % nuevo_dinero
