extends SceneTree
## 플레이 평가 반영 확인용: 포탑 감싸기 추천·보스 체력·보상 투표·웨이브 결과를 PNG 로 저장한다.

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
	var play := GSession.new(null, "민수", "me")
	play.open_host(true)
	play.m.players[1]["name"] = "지우"
	g.s = play
	g._enter_game()
	var m: GMatch = play.m
	for _i in 3:
		play.tick(0.05)
	await _save("ev_prep_botsuggest")
	m.apply(0, {"op": "build", "type": "cannon", "x": 3, "y": 10})
	g.selected = m.tower_cells()[Vector2i(3, 10)]
	g._set_mode("road:detour")
	for _i in 3:
		play.tick(0.05)
	await _save("ev_autowrap")
	g.mode = ""
	while m.wave < 5:
		if m.phase == "reward":
			for k in 2:
				m.apply(k, {"op": "vote", "v": "gold"})
		elif m.phase == "prep":
			GBot.play_prep(m, 0)
			GBot.play_prep(m, 1)
			m.apply(0, {"op": "ready", "v": true})
			m.apply(1, {"op": "ready", "v": true})
		else:
			m.step()
	await _save("ev_summary")
	GBot.play_prep(m, 0)
	GBot.play_prep(m, 1)
	m.apply(0, {"op": "ready", "v": true})
	m.apply(1, {"op": "ready", "v": true})
	var guard := 0
	while guard < 4000 and not m.enemies.any(func(e): return e["type"] == "boss" and float(e["dist"]) > 6.0):
		m.step()
		guard += 1
	g.selected = -1
	await _save("ev_boss")
	while m.phase == "combat":
		m.step()
	await _save("ev_reward")
	for vk in 2:
		m.apply(vk, {"op": "vote", "v": "gold"})
	GBot.play_prep(m, 0)
	GBot.play_prep(m, 1)
	m.apply(0, {"op": "ready", "v": true})
	m.apply(1, {"op": "ready", "v": true})
	guard = 0
	while not m.can_call() and guard < 6000:
		m.step()
		guard += 1
	await _save("ev_call")
	play.command({"op": "call", "v": true})
	for _i in 3:
		play.tick(0.05)
	await _save("ev_called")
	quit()
