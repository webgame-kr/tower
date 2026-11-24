extends SceneTree
## 도트 통일 확인용: 타이틀·로비·준비(건설 중)·전투(2인·4인)·일시정지·결과를 PNG 로 저장한다.
## 사용: godot --path . --resolution 1280x720 -s res://tools/shots_dot.gd -- <출력 폴더>

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
		if m.phase == "reward":
			for k in m.players.size():
				m.apply(k, {"op": "vote", "v": "gold"})
		elif m.phase == "prep":
			for k in m.players.size():
				if m.phase == "prep":
					GBot.play_prep(m, k, true)
			for k in m.players.size():
				if m.phase == "prep":
					m.apply(k, {"op": "ready", "v": true})
		else:
			m.step()
			m.hp = maxi(m.hp, 60)


func _run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	await _save("d_title")
	var lob := GSession.new(null, "민수", "a")
	lob.open_host()
	lob.seats.append({"peer": "", "token": "b", "tab": "", "name": "지우", "online": true, "col": 1, "ready": true, "kit": ["cannon", "cold", "oil", "flame", "shock"]})
	g.s = lob
	g._show("lobby")
	await _save("d_lobby")
	var p := GSession.new(null, "민수", "me")
	p.open_host(true)
	p.set_seat({"role": "fire"})
	p.start_match()
	g.s = p
	g._enter_game()
	g._tut = -1
	var m: GMatch = p.m
	m.apply(0, {"op": "build", "type": "cannon", "x": 6, "y": 3})
	g.mode = "build:gun"
	g.hover = Vector2(11.5, 2.5)
	await _save("d_prep_build")
	g.mode = ""
	g.selected = m.tower_cells()[Vector2i(6, 3)]
	await _save("d_prep_select")
	g.selected = -1
	_play_to(m, 3)
	for k in 2:
		if m.phase == "prep":
			GBot.play_prep(m, k, true)
	m.apply(0, {"op": "ready", "v": true})
	m.apply(1, {"op": "ready", "v": true})
	for _i in 220:
		m.step()
	await _save("d_combat2")
	g._paused = true
	g._toggle_pause()
	await _save("d_pause")
	g._toggle_pause()
	var four := GSession.new(null, "민수", "a")
	four.open_host()
	for row in [["지우", 1], ["하린", 2], ["도윤", 3]]:
		four.seats.append({"peer": "", "token": row[0], "tab": "", "name": row[0], "online": true, "col": row[1], "ready": true})
	four.solo = true
	four._begin()
	g.s = four
	g._enter_game()
	g._tut = -1
	var m4: GMatch = four.m
	_play_to(m4, 3)
	for k in 4:
		if m4.phase == "prep":
			GBot.play_prep(m4, k, true)
	for k in 4:
		m4.apply(k, {"op": "ready", "v": true})
	for _i in 260:
		m4.step()
	await _save("d_combat4")
	while m4.phase != "over":
		if m4.phase == "reward":
			for k in 4:
				m4.apply(k, {"op": "vote", "v": "gold"})
		elif m4.phase == "prep":
			for k in 4:
				m4.apply(k, {"op": "ready", "v": true})
		else:
			m4.hp = mini(m4.hp, 3)
			m4.step()
	four.state = "game"
	g._show("result")
	await _save("d_result")
	quit()
