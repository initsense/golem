extends GdUnitTestSuite

const PLAYER := "res://addons/golem/player/player.tscn"


func test_debug_hud_starts_hidden() -> void:
	var player: Node = auto_free(load(PLAYER).instantiate())
	var hud: CanvasLayer = player.get_node("DebugHUD")
	assert_bool(hud.visible).is_false()
