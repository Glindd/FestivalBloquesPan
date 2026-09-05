class_name GameManager
extends Node

static var instance: GameManager

@export var game_time: int = 120
@export var dinero_recaudado: int = 0

signal timer_updated(new_time: int)
signal money_updated(new_cantidad: int)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if instance == null:
		instance = self
	else:
		queue_free()
		return
	if multiplayer.is_server():
		var timer: Timer = Timer.new()
		timer.wait_time = 1.0
		timer.autostart = true
		timer.timeout.connect(_on_timer_timeout)
		add_child(timer)
 # Replace with function body.

func _on_timer_timeout() -> void:
	if not multiplayer.is_server():return
	if game_time > 0:
		game_time -= 1
		update_time_rpc.rpc(game_time)

func añadir_dinero(cantidad:int) -> void:
	if not multiplayer.is_server(): return
	dinero_recaudado += cantidad
	update_money_rpc.rpc(dinero_recaudado)
func quitar_dinero(cantidad:int) -> void:
	if not multiplayer.is_server(): return
	dinero_recaudado -= cantidad
	update_money_rpc.rpc(dinero_recaudado)

@rpc("authority", "call_local", "reliable")
func update_time_rpc(new_time: int) -> void:
	game_time = new_time
	timer_updated.emit(game_time)

@rpc("authority", "call_local", "reliable")
func update_money_rpc(new_amount: int) -> void:
	dinero_recaudado = new_amount
	money_updated.emit(dinero_recaudado)
