extends SceneTree
## 새 테마·적 확인: 대기실(무한 모드) · 늪 · 폭풍 · 고철 전투
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


func _run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	var lob := GSession.new(null, "플레이어", "a")
	lob.open_host()
	lob.endless = true
	g.s = lob
	g._show("lobby")
	await _save("t_lobby")
	for pack in [[5, ["toad", "sludge", "leech", "dredger"]], [6, ["rod", "kite", "stormship"]], [7, ["scav", "repair", "crusher"]], [1, ["sled", "shield", "walker"]], [3, ["golem", "splitter", "giant"]]]:
		GData.fixed_order = true
		var p := GSession.new(null, "플레이어", "me")
		p.open_host(true)
		p.set_seat({"role": "fire"})
		p.start_match()
		var m: GMatch = p.m
		GData.ORDER = [0, int(pack[0]), 2, 3, 4]
		m.wave = 6
		g.s = p
		g._enter_game()
		g._tut = -1
		g._kit_open = false
		g._theme = int(pack[0])
		g._theme_goal = int(pack[0])
		g._overview_t = 0.0
		m.phase = "combat"
		var i := 0
		for t in pack[1]:
			for n in (1 if GData.is_boss(t) else 3):
				var en := m._spawn(t, i % m.board.paths.size(), 8.0 + n * 1.6 + i * 2.5)
				i += 1
		if int(pack[0]) == 6:
			m.bolts = [[m.board.paths[0][14], 0.8], [m.board.paths[1][10], 0.5]]
		for _k in 6:
			m.step()
		var e0: Dictionary = m.enemies[0]
		var pos: Vector2 = m._pos(e0)
		g._cam = pos + Vector2(2, 0)
		await _save("t_theme_%d" % int(pack[0]))
	quit()
