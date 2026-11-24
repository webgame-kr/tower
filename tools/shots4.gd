extends SceneTree
## 4인 화면 확인용: 로비·준비·전투·결과를 PNG 로 저장한다.
## 사용: godot --path . --resolution 1280x720 -s res://tools/shots4.gd -- <출력 폴더>

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


func _play(m: GMatch, wave: int) -> void:
	while m.wave < wave and m.phase != "over":
		if m.phase == "prep":
			for k in 4:
				if m.phase == "prep":
					GBot.play_prep(m, k)
			for k in 4:
				if m.phase == "prep":
					m.apply(k, {"op": "ready", "v": true})
		else:
			m.step()
			m.hp = maxi(m.hp, 55)


func _run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	var s := GSession.new(null, "민수", "a")
	s.open_host()
	for row in [["지우", 1], ["하린", 2], ["도윤", 3]]:
		s.seats.append({"peer": "", "token": row[0], "tab": "", "name": row[0], "online": true, "col": row[1], "ready": row[1] != 3})
	s.seats[0]["ready"] = true
	s._add_chat({"seat": 0, "col": 0, "name": "민수", "text": "1번은 내가 맡을게"})
	s._add_chat({"seat": 2, "col": 2, "name": "하린", "text": "3번 입구 갈게"})
	g.s = s
	g._show("lobby")
	await _save("lobby4")

	s.solo = true
	s._begin()
	var m: GMatch = s.m
	g._enter_game()
	await _save("prep4")
	for theme_wave in [6, 16]:
		_play(m, theme_wave)
		g._theme = GData.theme_of(theme_wave)
		g._theme_goal = g._theme
		g._trans_t = 0.0
		for k in 4:
			if m.phase == "prep":
				GBot.play_prep(m, k)
		for k in 4:
			if m.phase == "prep":
				m.apply(k, {"op": "ready", "v": true})
		for _i in 170:
			m.step()
		await _save("combat4_%d" % theme_wave)
	while m.phase != "over":
		if m.phase == "prep":
			for k in 4:
				m.apply(k, {"op": "ready", "v": true})
		else:
			m.hp = mini(m.hp, 4)
			m.step()
	await _save("result4")
	quit()
