extends SceneTree
## UI 개편 확인용: 타이틀·코드 참가·대기실·준비(튜토리얼·제안)·짓기·포탑 정보·전투·보상·일시정지·설정·4인·결과
## 사용: godot --path . --resolution 1280x720 -s res://tools/shots_ui5.gd -- <출력 폴더>

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
	await _save("u_title")
	g._code_open = true
	g._code_len = 12
	await _save("u_join")
	g._code_open = false
	var lob := GSession.new(null, "플레이어", "a")
	lob.open_host()
	lob.seats.append({"peer": "", "token": "b", "tab": "", "name": "민준", "online": true, "col": 1, "ready": false, "kit": ["oil", "flame", "shock", "sniper", "signal"]})
	g.s = lob
	g._show("lobby")
	await _save("u_lobby")
	var p := GSession.new(null, "플레이어", "me")
	p.open_host(true)
	g.s = p
	g._enter_game()
	g._tut = 0
	g._overview_t = 0.0
	g._cam = Vector2(10, 7)
	var m: GMatch = p.m
	m.apply(0, {"op": "build", "type": "cannon", "x": 6, "y": 3})
	GBot.play_prep(m, 1, true, true)
	print("drafts ", m.drafts.keys())
	await _save("u_prep")
	print("prep 한글 글줄: ", g._hangul_drawn)
	g._tut = -1
	g.mode = "build:cannon"
	g.hover = Vector2(9.5, 6.5)
	await _save("u_build")
	g.mode = ""
	var id: int = m.tower_cells()[Vector2i(6, 3)]
	m.players[0]["gold"] = 2000
	m.apply(0, {"op": "upgrade", "id": id, "branch": ""})
	g.selected = id
	await _save("u_inspect")
	g.selected = -1
	_play_to(m, 5)
	for k in 2:
		if m.phase == "prep":
			GBot.play_prep(m, k, true)
	m.apply(0, {"op": "ready", "v": true})
	m.apply(1, {"op": "ready", "v": true})
	for _i in 520:
		m.step()
		m.hp = maxi(m.hp, 40)
	g._overview_t = 0.0
	g._last_phase = m.phase
	g._cam = Vector2(18, 10)
	await _save("u_combat")
	g._toggle_pause()
	await _save("u_pause")
	g._open_settings()
	g._tab = 3
	g._place()
	await _save("u_settings")
	g._close_panel()
	g._toggle_pause()
	while m.phase == "combat":
		m.step()
		m.hp = maxi(m.hp, 40)
	if m.phase == "reward":
		m.apply(0, {"op": "vote", "v": "gold"})
		await _save("u_reward")
	var four := GSession.new(null, "플레이어", "a")
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
	g._overview_t = 0.0
	g._last_phase = m4.phase
	await _save("u_combat4")
	g._zoom = 1
	await _save("u_combat4_x1")
	g._zoom = 2
	while m4.phase != "over":
		if m4.phase == "reward":
			for k in 4:
				m4.apply(k, {"op": "vote", "v": "gold"})
		elif m4.phase == "prep":
			for k in 4:
				m4.apply(k, {"op": "ready", "v": true})
		else:
			m4.hp = mini(m4.hp, 3) if m4.wave >= 4 else m4.hp
			m4.step()
	four.state = "game"
	g._show("result")
	await _save("u_result4")
	g.s = p
	while m.phase != "over":
		if m.phase == "reward":
			for k in 2:
				m.apply(k, {"op": "vote", "v": "gold"})
		elif m.phase == "prep":
			for k in 2:
				GBot.play_prep(m, k, true)
				m.apply(k, {"op": "ready", "v": true})
		else:
			if m.wave >= 8:
				m.hp = mini(m.hp, 3)
			m.step()
	p.state = "game"
	g._show("result")
	await _save("u_result")
	quit()
