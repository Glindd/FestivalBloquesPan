class_name InteraccionArea
extends Area3D

signal interact
#signal players_nearby

@export var meshInstance: MeshInstance3D
@export var label: Label3D
@export var Objeto_Interactuable: ObjetoInteractuable
@export var duracion_animacion = 0


var players: Array[Player]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	duracion_animacion = Objeto_Interactuable.tiempo_accion
	if label:
		label.hide()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("E_Interactuar"):
		for player: Player in players:
			if player.get_multiplayer_authority() == multiplayer.get_unique_id():
				interact.emit()
				player.trigger_emotiza.rpc(duracion_animacion)
				pass



func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player:
		players.push_back(player)
		
		if player.get_multiplayer_authority() == multiplayer.get_unique_id():
			label.show()
			
		
func _on_body_exited(body: Node3D) -> void:
	var player: Player = body as Player
	if player:
		players.erase(player)
		if player.get_multiplayer_authority() == multiplayer.get_unique_id():
			label.hide()
			
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
