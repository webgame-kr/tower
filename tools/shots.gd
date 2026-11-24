extends SceneTree
## 화면 확인용: 실제 게임 화면을 상태별로 PNG 로 저장한다.
## 사용: godot --path . --resolution 1280x720 -s res://tools/shots.gd -- <출력 폴더>

var out := ""
var g


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://"
	_run()


func _save(name_: String) -> void:
	for _i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name_ + ".png"))
	print("saved ", name_)


func _play_to(m: GMatch, wave: int) -> void:
	while m.wave < wave and m.phase != "over":
		if m.phase == "prep":
			GBot.play_prep(m, 0)
			GBot.play_prep(m, 1)
			m.apply(0, {"op": "ready", "v": true})
			m.apply(1, {"op": "ready", "v": true})
		else:
			m.step()
			m.hp = maxi(m.hp, 60)


func _run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame

	var play := GSession.new(null, "민수", "me")
	play.open_host(true)
	play.m.players[1]["name"] = "지우"
	g.s = play
	g._enter_game()
	var m: GMatch = play.m
	await _save("t0_grass_prep")

	g.mode = "build:cannon"
	await _save("t0_grass_build")
	g.mode = ""

	for theme in range(1, 5):
		_play_to(m, theme * GData.THEME_LEN + 1)
		for _i in 3:
			await process_frame
		g._theme = theme
		g._theme_goal = theme
		g._trans_t = 0.0
		g._notice_t = 3.0
		g.selected = -1
		await _save("t%d_prep" % theme)
		GBot.play_prep(m, 0)
		GBot.play_prep(m, 1)
		m.apply(0, {"op": "ready", "v": true})
		m.apply(1, {"op": "ready", "v": true})
		for _i in 150:
			m.step()
		await _save("t%d_combat" % theme)
		while m.phase == "combat":
			m.step()
			m.hp = maxi(m.hp, 40)

	m.hp = 28
	await _save("damaged")
	g._theme_goal = 2
	for _i in 5:
		g._trans_t = 1.5
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("transition.png"))
	g._trans_t = 0.0
	g._theme_goal = g._theme

	while m.phase != "over":
		if m.phase == "prep":
			m.apply(0, {"op": "ready", "v": true})
			m.apply(1, {"op": "ready", "v": true})
		else:
			m.hp = mini(m.hp, 3)
			m.step()
	await _save("result")
	quit()
