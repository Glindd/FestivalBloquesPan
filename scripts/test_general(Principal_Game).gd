extends Node3D

@export var player_scene: PackedScene
@onready var spawn_points: Node3D = $SpawnPoints
@onready var players: Node3D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner


func _ready() -> void:
	player_spawner.spawn_function = _spawn_player
	if not multiplayer.is_server():
		return
	else:
		await get_tree().create_timer(0.5).timeout
	for player_data: Statics.PlayerData in Game.instance.players:
		player_spawner.spawn(player_data.to_dict())
		

func _spawn_player(data: Dictionary) -> Node:
	var player_data:Statics.PlayerData = Statics.PlayerData.from_dict(data)
	
	var player_inst: Player = player_scene.instantiate()
	player_inst.set_multiplayer_authority(player_data.id)
	
	player_inst.name = str(player_data.id)
	var spawn_point: Node3D = spawn_points.get_child(player_data.index)
	player_inst.position = spawn_point.global_position
	return player_inst

	
	
