extends Node3D

@export var player_scene: PackedScene
@onready var spawn_points: Node3D = $SpawnPoints
@onready var players: Node3D = $Players

func _ready() -> void:
	for i: int in Game.instance.players.size():
		var player_data: Statics.PlayerData = Game.instance.players[i]
		var player_inst = player_scene.instantiate()
		player_inst.name = str(player_data.id)
		players.add_child(player_inst)
		player_inst.setup(player_data)
		player_inst.global_position = spawn_points.get_child(i).global_position
