extends Node3D
## Main — Top-level game scene
##
## Wires together the TestRoom, Player, and HUD.
## Sets up initial game state.

@onready var hud: CanvasLayer = $HUD
@onready var test_room: Node3D = $TestRoom

func _ready() -> void:
	# Set game state
	GameManager.change_state(GameManager.GameState.DUNGEON_RUN)

	# Find player and connect to HUD
	var player := test_room.get_node("Player")
	if player:
		player.add_to_group("player")
		hud.connect_to_player(player)

		# Register enemies with CombatSystem
		var enemies: Array[Node] = []
		for child in test_room.get_children():
			if child.has_method("take_damage") and child != player:
				enemies.append(child)

		if enemies.size() > 0:
			CombatSystem.start_combat(player, enemies)

	print("[Main] Scene ready — %d enemies spawned" % test_room.get_children().filter(
		func(c): return c.has_method("take_damage") and c.name != "Player"
	).size())
