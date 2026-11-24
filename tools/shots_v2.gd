extends SceneTree
## 개편 확인용: 새 맵(2인·4인), 길 그리기, 새 포탑·적, 테마 지형 사건을 PNG 로 저장한다.
## 사용: godot --path . --resolution 1280x720 -s res://tools/shots_v2.gd -- <출력 폴더>

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


func _play_to(m: GMatch, wave: int, roads := true) -> void:
	while m.wave < wave and m.phase != "over":
		if m.phase == "reward":
			for k in m.players.size():
				m.apply(k, {"op": "vote", "v": "gold"})
		elif m.phase == "prep":
			for k in m.players.size():
				if m.phase == "prep":
					GBot.play_prep(m, k, roads)
			for k in m.players.size():
				if m.phase == "prep":
					m.apply(k, {"op": "ready", "v": true})
		else:
			m.step()
			m.hp = maxi(m.hp, 60)


func _theme_now(m: GMatch) -> void:
	g._theme = GData.theme_of(m.wave)
	g._theme_goal = g._theme
	g._trans_t = 0.0
	g._notice_t = 0.0


func _run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	# 2인 혼자 연습
	var play := GSession.new(null, "민수", "me")
	play.open_host(true)
	play.m.players[1]["name"] = "지우"
	g.s = play
	g._enter_game()
	g._tut = -1
	var m: GMatch = play.m
	await _save("v2_prep")
	m.apply(0, {"op": "build", "type": "cannon", "x": 4, "y": 6})
	m.apply(0, {"op": "build", "type": "gun", "x": 6, "y": 7})
	m.apply(0, {"op": "build", "type": "spike", "x": 2, "y": 8})
	g.selected = m.tower_cells()[Vector2i(4, 6)]
	g._set_mode("road:draw")
	for _i in 3:
		play.tick(0.05)
	await _save("v2_autowrap")
	g.mode = ""
	g.selected = -1
	play.command({"op": "draft"})
	# 직접 끌어 그리기: 1번 길 (5,1)에서 (5,4)까지를 오른쪽으로 크게 돌린다
	g.mode = "road:draw"
	g._trail = {"e": 0, "i": 5, "cells": [], "j": -1}
	for c in [Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1), Vector2i(8, 0)]:
		pass
	for c in [Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0), Vector2i(8, 1), Vector2i(8, 2), Vector2i(8, 3), Vector2i(8, 4), Vector2i(7, 4), Vector2i(6, 4), Vector2i(5, 4)]:
		g._trail_step(m, c)
	await _save("v2_drag")
	g._trail = {}
	g.mode = ""
	_play_to(m, 7)
	for k in 2:
		if m.phase == "prep":
			GBot.play_prep(m, k, true)
	_theme_now(m)
	await _save("v2_snow_prep")
	m.apply(0, {"op": "ready", "v": true})
	m.apply(1, {"op": "ready", "v": true})
	for _i in 260:
		m.step()
	await _save("v2_snow_combat")
	_play_to(m, 12)
	_theme_now(m)
	await _save("v2_sand_prep")
	_play_to(m, 17)
	_theme_now(m)
	for k in 2:
		if m.phase == "prep":
			GBot.play_prep(m, k, true)
	for _i in 3:
		await process_frame
	await _save("v2_lava_prep")
	_play_to(m, 21)
	_theme_now(m)
	await _save("v2_ghost_prep")
	_play_to(m, 25)
	_theme_now(m)
	if m.phase == "prep":
		for k in 2:
			GBot.play_prep(m, k, true)
		m.apply(0, {"op": "ready", "v": true})
		m.apply(1, {"op": "ready", "v": true})
	var guard := 0
	while guard < 4000 and not m.enemies.any(func(e): return GData.is_boss(e["type"]) and float(e["dist"]) > 6.0):
		m.step()
		m.hp = maxi(m.hp, 60)
		guard += 1
	await _save("v2_ghost_boss")
	# 4인
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
	for k in 4:
		GBot.play_prep(m4, k, true)
	await _save("v4_prep")
	for k in 4:
		m4.apply(k, {"op": "ready", "v": true})
	_play_to(m4, 4)
	for k in 4:
		if m4.phase == "prep":
			GBot.play_prep(m4, k, true)
	for k in 4:
		m4.apply(k, {"op": "ready", "v": true})
	for _i in 300:
		m4.step()
	await _save("v4_combat")
	quit()
