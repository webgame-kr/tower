extends SceneTree
## 길 합류·교차·본부 확인용: 합류 전체(x1)·합류 제안 카드·공동 구간 전투·교차로·본부 3단계
## 사용: godot --path . --resolution 1280x720 -s res://tools/shots_merge.gd -- <출력 폴더>

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


static func _walk(pts: Array) -> Array:
	var o: Array = [pts[0]]
	for i in range(1, pts.size()):
		var a: Vector2i = pts[i - 1]
		var b: Vector2i = pts[i]
		var d := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var c := a
		while c != b:
			c += d
			o.append(c)
	return o


func _session() -> GSession:
	var p := GSession.new(null, "플레이어", "me")
	p.open_host(true)
	p.set_seat({"role": "fire"})
	p.start_match()
	return p


func _run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	var p := _session()
	g.s = p
	g._enter_game()
	g._tut = -1
	g._kit_open = false
	g._overview_t = 0.0
	var m: GMatch = p.m
	m.players[1]["bot"] = false
	m.players[0]["kit"] = ["gun", "cannon", "cold", "magnet"]
	m.players[1]["kit"] = ["oil", "flame", "shock", "sniper"]
	m.players[0]["gold"] = 3000
	m.players[1]["gold"] = 3000
	m.players[0]["mat"] = 12
	m.players[1]["mat"] = 12
	var a: Array = m.board.paths[0]
	var join := _walk([Vector2i(0, 16), Vector2i(0, 12), Vector2i(5, 12), Vector2i(5, 10)]) + a.slice(a.find(Vector2i(6, 10)))
	print("propose: ", m.apply(1, {"op": "edit", "e": 1, "path": Board.flat(join)}))
	g._cam = Vector2(8, 8)
	g._kit_open = false
	await _save("m_proposal")
	print("accept: ", m.apply(0, {"op": "edit", "e": 1, "path": Board.flat(join)}))
	for row in [[0, "gun", 8, 8], [0, "cannon", 14, 9], [1, "flame", 4, 11], [1, "oil", 9, 11], [0, "cold", 18, 6], [1, "shock", 24, 6], [0, "magnet", 28, 4], [1, "sniper", 30, 7]]:
		m.apply(int(row[0]), {"op": "build", "type": row[1], "x": row[2], "y": row[3]})
	g._zoom = 1
	m.board.paths[1] = join
	g._cam = Vector2(20, 12)
	g._kit_open = false
	await _save("m_overview")
	g._zoom = 2
	m.board.paths[1] = join      # 화면을 기다리는 사이 연습 동료가 길을 바꿨을 수 있다
	for k in 2:
		m.apply(k, {"op": "ready", "v": true})
	for _i in 300:
		m.step()
		m.hp = maxi(m.hp, 60)
	g._last_phase = m.phase
	g._cam = Vector2(10, 8)
	g._kit_open = false
	await _save("m_shared")
	# 교차로: 새 판에서 2번 길이 1번 길을 두 번 가로지른다
	var q := _session()
	g.s = q
	g._enter_game()
	g._tut = -1
	g._kit_open = false
	g._overview_t = 0.0
	var n: GMatch = q.m
	n.players[1]["mat"] = 99
	var two := _walk([Vector2i(0, 16), Vector2i(17, 16), Vector2i(17, 2), Vector2i(22, 2), Vector2i(22, 12), Vector2i(31, 12)])
	print("cross: ", n.apply(1, {"op": "edit", "e": 1, "path": Board.flat(two)}))
	n.players[0]["kit"] = ["gun", "cannon", "cold", "magnet"]
	n.players[0]["gold"] = 3000
	n.apply(0, {"op": "build", "type": "gun", "x": 18, "y": 6})
	n.apply(0, {"op": "build", "type": "cannon", "x": 23, "y": 4})
	g._cam = Vector2(22, 7)
	g._kit_open = false
	await _save("m_cross")
	n.hp = 40
	g._cam = Vector2(31, 10)
	g._kit_open = false
	await _save("m_hq_mid")
	n.hp = 12
	g._kit_open = false
	await _save("m_hq_low")
	quit()
