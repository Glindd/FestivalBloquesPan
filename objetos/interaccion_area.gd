class_name InteraccionArea
extends Area3D

signal interact

@export var label: Label3D

var players: Array[Player]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if label:
		label.hide()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("E_Interactuar"):
		for player: Player in players:
			if player.get_multiplayer_authority() == multiplayer.get_unique_id():
				interact.emit()
				print("E")
				pass

func _on_body_entered(body: Node3D) -> void:
	print("entro algo")
	var player: Player = body as Player
	if player:
		print("es jugador")
		players.push_back(player)
		
		if player.get_multiplayer_authority() == multiplayer.get_unique_id():
			print("es autoridad")
			label.show()
		
func _on_body_exited(body: Node3D) -> void:
	var player: Player = body as Player
	if player:
		players.erase(player)
		if player.get_multiplayer_authority() == multiplayer.get_unique_id():
			print("me fui")
			label.hide()
			
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
