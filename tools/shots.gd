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
	for _i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name_ + ".png"))
	print("saved ", name_)


func _run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _save("menu")

	var lobby := GSession.new(null, "민수", "a")
	lobby.open_host()
	lobby.seats.append({"peer": "", "token": "b", "name": "지우", "online": true, "col": 1, "ready": false})
	lobby.seats[0]["ready"] = true
	lobby._add_chat({"seat": 0, "name": "민수", "text": "나 왼쪽 1번 맡을게"})
	lobby._add_chat({"seat": 1, "name": "지우", "text": "ㅇㅋ 그럼 나 2번"})
	g.s = lobby
	g._show("lobby")
	await _save("lobby")

	var play := GSession.new(null, "민수", "me")
	play.open_host(true)
	play.seats[1]["name"] = "지우"
	play.m.players[1]["name"] = "지우"
	g.s = play
	g._enter_game()
	var m: GMatch = play.m
	m.apply(0, {"op": "build", "type": "cannon", "x": 6, "y": 7})
	m.apply(0, {"op": "build", "type": "gun", "x": 3, "y": 9})
	g.selected = m.tower_cells()[Vector2i(6, 7)]
	play._add_chat({"seat": 1, "name": "지우", "text": "네 대포 감싸게 돌려볼게"})
	play.command({"op": "ping", "kind": "road", "x": 5.5, "y": 3.5})
	m.apply(0, {"op": "draft", "e": 0, "i": 8, "kind": "bend", "side": 1})
	await _save("prep")
	m.apply(0, {"op": "draft"})

	while m.wave < GData.THEME_LEN and m.phase != "over":
		if m.phase == "prep":
			GBot.play_prep(m, 0)
			GBot.play_prep(m, 1)
			m.apply(0, {"op": "ready", "v": true})
			m.apply(1, {"op": "ready", "v": true})
		else:
			m.step()
	GBot.play_prep(m, 0)
	GBot.play_prep(m, 1)
	m.apply(0, {"op": "ready", "v": true})
	m.apply(1, {"op": "ready", "v": true})
	for _i in 260:
		m.step()
	g.selected = m.towers.keys()[0]
	await _save("combat")

	m.hp = 5
	while m.phase != "over":
		if m.phase == "prep":
			m.apply(0, {"op": "ready", "v": true})
			m.apply(1, {"op": "ready", "v": true})
		else:
			m.step()
	await _save("result")
	quit()
