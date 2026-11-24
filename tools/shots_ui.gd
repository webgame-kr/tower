extends SceneTree
## UI 시안 비교용: 타이틀·준비·전투·일시정지·설정·로비·결과를 PNG 로 저장한다.
## 사용: godot --path . --resolution 1280x720 -s res://tools/shots_ui.gd -- <출력 폴더>

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
	g._menu_focus = 1
	await _save("ui_title")

	var play := GSession.new(null, "민수", "me")
	play.open_host(true)
	play.m.players[1]["name"] = "지우"
	g.s = play
	g._enter_game()
	var m: GMatch = play.m
	m.apply(0, {"op": "build", "type": "cannon", "x": 6, "y": 7})
	m.apply(0, {"op": "build", "type": "gun", "x": 3, "y": 9})
	play._add_chat({"seat": 1, "col": 1, "name": "지우", "text": "대포 감싸게 돌릴게"})
	play._add_chat({"seat": 0, "col": 0, "name": "민수", "text": "좋아, 1번엔 냉각탑"})
	g.mode = "build:cannon"
	await _save("ui_prep_build")
	g.mode = ""
	g.selected = m.tower_cells()[Vector2i(6, 7)]
	m.apply(0, {"op": "draft", "e": 0, "i": 1, "kind": "detour", "side": 1})
	await _save("ui_prep_select")
	m.apply(0, {"op": "draft"})

	while m.wave < 5:
		if m.phase == "prep":
			GBot.play_prep(m, 0)
			GBot.play_prep(m, 1)
			m.apply(0, {"op": "ready", "v": true})
			m.apply(1, {"op": "ready", "v": true})
		else:
			m.step()
			m.hp = maxi(m.hp, 74)
	GBot.play_prep(m, 0)
	GBot.play_prep(m, 1)
	m.apply(0, {"op": "ready", "v": true})
	m.apply(1, {"op": "ready", "v": true})
	for _i in 200:
		m.step()
	var cold := -1
	for id in m.towers:
		if m.towers[id]["type"] == "cold" and int(m.towers[id]["owner"]) == 0:
			cold = id
	g.selected = cold
	g.mode = "ability"
	await _save("ui_battle")
	g.mode = ""
	g._toggle_pause()
	await _save("ui_pause")
	g._open_settings()
	await _save("ui_settings")
	g._close_panel()
	g._toggle_pause()

	while m.phase != "over":
		if m.phase == "prep":
			m.apply(0, {"op": "ready", "v": true})
			m.apply(1, {"op": "ready", "v": true})
		else:
			m.hp = mini(m.hp, 3)
			m.step()
	await _save("ui_result")

	var lobby := GSession.new(null, "민수", "a")
	lobby.open_host()
	lobby.seats.append({"peer": "", "token": "b", "tab": "", "name": "지우", "online": true, "col": 1, "ready": true})
	g.s = lobby
	g._show("lobby")
	await _save("ui_lobby")
	quit()
