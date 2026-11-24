extends SceneTree
## 포탑 정보 버튼을 실제 마우스 이벤트로 눌러 본다 (판매·강화)

var g


func _initialize() -> void:
	_run()


func _press(at: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv)
	await process_frame
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		root.push_input(ev)
		await process_frame
	for _i in 4:
		await process_frame


func _run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	var p := GSession.new(null, "플레이어", "me")
	p.open_host(true)
	g.s = p
	g._enter_game()
	g._tut = -1
	var m: GMatch = p.m
	m.players[0]["gold"] = 2000
	print("build: ", m.apply(0, {"op": "build", "type": "cannon", "x": 6, "y": 3}))
	for _i in 4:
		await process_frame
	var cell: Vector2 = g._off + g.MAP + Vector2(6.5, 3.5) * g.CELL
	await _press(cell)
	print("selected=", g.selected, " mode=", g.mode, " drag=", g._drag)
	var id: int = g.selected
	var up: Button = g.up_btn
	print("up visible=", up.visible, " disabled=", up.disabled, " pos=", up.position, " size=", up.size, " global=", up.get_global_rect())
	await _press(up.get_global_rect().get_center())
	print("after up: lv=", m.towers[id]["lv"] if m.towers.has(id) else -1, " selected=", g.selected, " mode=", g.mode)
	# MK-3: [강화] 누르면 갈래 카드, A 카드 누르기
	await _press(up.get_global_rect().get_center())
	print("branch pick=", g._branch_pick, " a visible=", g.a_btn.visible)
	await _press(g.a_btn.get_global_rect().get_center())
	print("after A: lv=", m.towers[id]["lv"], " branch=", m.towers[id]["branch"])
	# 우선순위
	await _press(g.prio_btns["strong"].get_global_rect().get_center())
	print("prio=", m.towers[id]["prio"])
	# 함정 수리
	var pc: Vector2i = m.board.paths[0][6]
	print("trap: ", m.apply(0, {"op": "build", "type": "spike", "x": pc.x, "y": pc.y}))
	var sp := -1
	for k in m.towers:
		if m.towers[k]["type"] == "spike":
			sp = k
	if sp >= 0:
		m.towers[sp]["uses"] = 1
		await _press(g._off + g.MAP + Vector2(float(m.towers[sp]["x"]) + 0.5, float(m.towers[sp]["y"]) + 0.5) * g.CELL)
		print("selected trap=", g.selected == sp, " fix visible=", g.fix_btn.visible)
		await _press(g.fix_btn.get_global_rect().get_center())
		print("uses after fix=", m.towers[sp]["uses"])
		g.selected = id
		for _i in 3:
			await process_frame
	var sell: Button = g.sell_btn
	print("sell visible=", sell.visible, " global=", sell.get_global_rect())
	await _press(sell.get_global_rect().get_center())
	print("after sell: exists=", m.towers.has(id), " selected=", g.selected)
	quit()


func _probe(n: Node, at: Vector2) -> void:
	for c in n.get_children():
		if c is Control and c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(at):
			print("  hit ", at, " ", c.name, " ", c.get_class(), " ", (c as Control).get_global_rect(), " text=", c.get("text"))
		_probe(c, at)
