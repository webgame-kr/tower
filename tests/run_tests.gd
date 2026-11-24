extends SceneTree
## 규칙 테스트. 실패가 있으면 종료 코드 1.

var fails := 0
var total := 0


func ok(cond: bool, label: String) -> void:
	total += 1
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	_layout()
	_roads()
	_merge()
	_economy()
	_flow()
	_towers()
	_enemies()
	_themes()
	_waves()
	_rewards()
	_early()
	_reactions()
	_picks()
	_new_towers()
	_sync()
	print("%d/%d passed" % [total - fails, total])
	quit(1 if fails > 0 else 0)


func _layout() -> void:
	for n in [2, 3, 4]:
		var m := GMatch.new(_names(n), [], 1)
		ok(m.board.paths.size() == GData.lanes_for(n), "%d인 입구 수" % n)
		var lens := []
		var cells := 0
		for e in m.board.paths.size():
			lens.append(m.board.paths[e].size())
			cells += m.board.paths[e].size()
			ok(m.board.validate(e, m.board.paths[e], {}, 0, m.cap()) == "", "%d인 %d번 기본 길 유효" % [n, e + 1])
		ok(lens.max() - lens.min() <= 3, "%d인 길 길이가 비슷함" % n)
		var ratio := float(cells) / float(GData.W * GData.H)
		ok(ratio >= 0.06, "%d인 길 비율 %.0f%%" % [n, ratio * 100])
		var board := Board.new(GData.lanes_for(n))
		for extra in GData.EXTRA_PATHS:
			board.paths.append(extra)
			board.extra += 1
			ok(board.validate(board.paths.size() - 1, extra, {}, 4, 99) == "", "%d인 새 입구 %d번 길 유효" % [n, board.paths.size()])
		ok(board.paths.size() == (4 if n == 2 else 6), "%d인 입구 최대 수" % n)
	GData.use_layout(4)
	ok(GData.W == 52 and GData.H == 30, "4인 52x30")
	GData.use_layout(2)
	ok(GData.W == 40 and GData.H == 24, "2인 40x24")
	var free := 0
	var m2 := GMatch.new(["A", "B"])
	for y in GData.H:
		for x in GData.W:
			if m2.board.can_build(Vector2i(x, y), {}, 0) == "":
				free += 1
	ok(free >= 700, "2인 건설 가능 칸 %d" % free)


func _names(n: int) -> Array:
	var out := []
	for i in n:
		out.append("P%d" % i)
	return out


func _detour(m: GMatch) -> Array:
	return m.board.candidate(0, 8, "detour", -1)     # 1번 길 가운데 직선을 위로 ㄷ자 (+4칸)


func _roads() -> void:
	var m := GMatch.new(["A", "B"])
	var before: int = m.board.paths[0].size()
	var path := _detour(m)
	ok(path.size() == before + 4, "후보 경로 +4칸")
	ok(m.apply(1, {"op": "draft", "e": 0, "path": Board.flat(path)}) == "" and m.drafts.has(1), "미리보기는 누구나")
	ok(int(m.drafts[1]["cost"]) == 4 and int(m.players[1]["mat"]) == GData.MAT_START and m.board.paths[0].size() == before, "미리보기는 자재와 길을 바꾸지 않음")
	ok(m.apply(0, {"op": "draft", "e": 0, "path": Board.flat(path)}) != "", "남이 그리는 길은 잠김")
	ok(m.apply(0, {"op": "edit", "e": 0, "path": Board.flat(path)}) == "", "동료의 제안을 내 자재로 확정")
	ok(m.board.paths[0].size() == before + 4 and int(m.players[0]["mat"]) == GData.MAT_START - 4 and int(m.players[1]["mat"]) == GData.MAT_START, "늘어난 칸만큼 확정한 사람 자재 사용")
	ok(m.drafts.is_empty(), "확정하면 미리보기 제거")
	ok(m.apply(0, {"op": "undo"}) == "" and m.board.paths[0].size() == before and int(m.players[0]["mat"]) == GData.MAT_START, "되돌리기는 자재를 돌려줌")
	ok(m.apply(0, {"op": "undo"}) != "", "되돌릴 것이 없으면 불가")
	m.apply(0, {"op": "edit", "e": 0, "path": Board.flat(path)})
	var straight: Array = GData.BASE_PATHS[0]
	ok(m.apply(1, {"op": "edit", "e": 0, "path": Board.flat(straight)}) == "" and int(m.players[1]["mat"]) == mini(GData.MAT_START + 4, GData.MAT_MAX), "길을 줄이면 자재를 돌려받음")
	var poor := GMatch.new(["A", "B"])
	poor.players[0]["mat"] = 2
	ok(poor.apply(0, {"op": "edit", "e": 0, "path": Board.flat(_detour(poor))}) != "", "자재가 모자라면 확정 불가")
	# 포탑이 막을 때
	var own := GMatch.new(["A", "B"])
	var nc := Vector2i(-1, -1)
	for c in _detour(own):
		if not own.board.paths[0].has(c):
			nc = c
			break
	own.apply(0, {"op": "build", "type": "gun", "x": nc.x, "y": nc.y})
	var r := own.check_route(0, 0, _detour(own))
	ok(not r.has("err") and (r["moves"] as Array).size() == 1, "내 포탑이 막으면 옆 칸으로 옮길 자리를 제안")
	ok(own.apply(0, {"op": "edit", "e": 0, "path": Board.flat(_detour(own))}) == "", "옮기고 길 내기")
	var t: Dictionary = own.towers.values()[0]
	ok(not own.board.is_path(Vector2i(int(t["x"]), int(t["y"]))), "옮긴 포탑은 길 밖")
	ok(own.apply(0, {"op": "undo"}) == "" and int(own.towers.values()[0]["x"]) == nc.x and int(own.towers.values()[0]["y"]) == nc.y, "되돌리면 포탑도 제자리")
	var other := GMatch.new(["A", "B"])
	other.apply(1, {"op": "build", "type": "gun", "x": nc.x, "y": nc.y})
	ok(other.check_route(0, 0, _detour(other)).has("err"), "남의 포탑이 막으면 불가")
	# 그 밖의 조건
	var e := GMatch.new(["A", "B"])
	var long_path: Array = (GData.BASE_PATHS[0] as Array).duplicate()
	while long_path.size() <= e.cap():
		long_path.append(Vector2i(0, 0))
	ok(e.board.validate(0, long_path, {}, 0, e.cap()) != "", "길이 상한 초과 불가")
	var broken: Array = (GData.BASE_PATHS[0] as Array).duplicate()
	broken.remove_at(5)
	ok(e.board.validate(0, broken, {}, 0, e.cap()) != "", "끊긴 길 불가")
	var spliced := e.board.spliced(0, 3, 1, [Vector2i(2, 5)])
	ok(spliced.size() == (GData.BASE_PATHS[0] as Array).size() and spliced[2] == Vector2i(2, 5) and spliced[3] == Vector2i(3, 4), "끝점 순서가 반대여도 이어 붙임")


func _merge() -> void:
	var m := GMatch.new(["A", "B"])
	m.players[0]["mat"] = GData.MAT_MAX
	m.players[1]["mat"] = GData.MAT_MAX
	var a: Array = m.board.paths[0]
	# 2번 길이 1번 길 (6,9) 로 들어와 합류한 장면
	var side := [Vector2i(0, 11), Vector2i(1, 11), Vector2i(2, 11), Vector2i(3, 11), Vector2i(4, 11), Vector2i(5, 11), Vector2i(5, 10), Vector2i(5, 9)]
	var lane1: Array = side + a.slice(a.find(Vector2i(6, 9)))
	m.board.paths[1] = lane1
	ok(m.board.junctions().size() == 1 and m.board.junctions()[0][0] == Vector2i(6, 9), "합류 지점")
	var path := m.board.merged(1, lane1.find(Vector2i(5, 9)), [Vector2i(5, 8)], 0, a.find(Vector2i(6, 8)))
	ok(m.apply(1, {"op": "edit", "e": 1, "path": Board.flat(path)}) == "", "다른 길 위로 그리면 더 일찍 합류")
	ok(m.board.paths[1].slice(-5) == m.board.paths[0].slice(-5) and m.board.junctions()[0][0] == Vector2i(6, 8), "합류 뒤로는 같은 길")
	ok(m.board.validate(1, [Vector2i(0, 11), Vector2i(6, 8), Vector2i(6, 7)], {}, 0, 99) != "", "겹친 뒤 갈라지면 불가")
	m.phase = "combat"
	m.enemies = []
	var en := m._spawn("grunt", 1)
	while m.enemies.has(en):
		m._move_enemies(0.5)
	ok(m.gate_dmg[1] == 1, "합류한 길로도 적이 본부에 닿음")
	m.phase = "prep"
	var lane0_old: Array = m.board.paths[0]
	ok(m.apply(1, {"op": "edit", "e": 1, "path": Board.flat(lane1)}) == "" and m.board.junctions()[0][0] == Vector2i(6, 9) and m.board.paths[0] == lane0_old, "다시 그려 늦게 합류해도 다른 길은 그대로")
	ok(m.apply(1, {"op": "undo"}) == "" and m.board.junctions()[0][0] == Vector2i(6, 8), "합류 바꾼 것도 되돌리기")
	# 합류한 뒤 공유 구간을 바꾸면 합류한 길도 따라간다
	var l0: Array = m.board.paths[0]
	var np: Array = l0.slice(0, l0.find(Vector2i(17, 10)) + 1)
	np.append_array([Vector2i(18, 10), Vector2i(18, 11)])
	ok(m.apply(0, {"op": "edit", "e": 0, "path": Board.flat(np)}) == "", "합류한 공유 구간 다시 그리기")
	ok(m.board.paths[1].slice(-3) == np.slice(-3) and m.board.junctions().size() == 1, "합류한 길도 함께 바뀜")
	ok(m.apply(0, {"op": "undo"}) == "" and m.board.paths[1].slice(-2) == [Vector2i(17, 12), Vector2i(18, 12)], "되돌리면 둘 다 제자리")
	var copy := GMatch.new()
	copy.load_data(JSON.parse_string(JSON.stringify(m.to_data())))
	ok(copy.board.junctions().size() == 1, "합류 상태 동기화")


func _economy() -> void:
	var m := GMatch.new(["A", "B"])
	ok(m.apply(0, {"op": "build", "type": "gun", "x": 5, "y": 4}) != "", "길 위 건설 불가")
	ok(m.apply(0, {"op": "build", "type": "gun", "x": 5, "y": 3}) == "", "건설")
	var gun_cost: int = GData.TOWERS["gun"]["cost"]
	ok(m.players[0]["gold"] == GData.START_GOLD - gun_cost, "골드 차감")
	var failed := m.apply(1, {"op": "build", "type": "gun", "x": 5, "y": 3})
	ok(failed != "" and m.players[1]["gold"] == GData.START_GOLD, "같은 칸 두 번째 요청은 실패하고 골드 유지")
	var id: int = m.towers.keys()[0]
	ok(m.apply(1, {"op": "sell", "id": id}) != "", "남의 포탑 판매 불가")
	ok(m.apply(1, {"op": "move", "id": id, "x": 7, "y": 3}) != "", "남의 포탑 이동 불가")
	ok(m.apply(0, {"op": "move", "id": id, "x": 7, "y": 3}) == "", "내 포탑 이동")
	ok(m.players[0]["gold"] == GData.START_GOLD - gun_cost, "이동은 무료")
	ok(m.apply(0, {"op": "sell", "id": id}) == "" and m.players[0]["gold"] == GData.START_GOLD, "같은 준비 단계에 지은 포탑은 전액 환불")
	m.apply(0, {"op": "build", "type": "gun", "x": 5, "y": 3})
	id = m.towers.keys()[0]
	ok(m.apply(0, {"op": "upgrade", "id": id}) == "", "2단계 강화")
	ok(m.apply(0, {"op": "upgrade", "id": id}) != "", "3단계는 방향 필수")
	m.players[0]["gold"] = 500
	ok(m.apply(0, {"op": "upgrade", "id": id, "branch": "b"}) == "", "3단계 방향 선택")
	m.towers[id]["fresh"] = false
	var spent: int = m.towers[id]["spent"]
	var g: int = m.players[0]["gold"]
	ok(m.apply(0, {"op": "sell", "id": id}) == "" and m.players[0]["gold"] == g + int(floor(spent * 0.8)), "지난 웨이브 포탑은 80% 환급")
	ok(m.apply(0, {"op": "build", "type": "shock", "x": 5, "y": 3}) != "", "공구함에 없는 포탑은 못 지음")
	m.players[0]["hand"] = ["shock", "sniper", "oil", "flame", "spike", "cold"]
	ok(m.apply(0, {"op": "pick", "v": ["spike", "cold", "shock", "sniper"]}) == "" and bool(m.players[0]["picked"]), "카드 4장 골라 공구함")
	ok(m.apply(0, {"op": "build", "type": "shock", "x": 5, "y": 3}) == "", "고른 카드 포탑 건설")
	ok(m.apply(0, {"op": "pick", "v": ["spike", "spike", "cold", "oil"]}) != "", "같은 카드 두 번 불가")
	ok(m.apply(0, {"op": "pick", "v": ["magnet", "cold", "oil", "spike"]}) != "", "손에 없는 카드 불가")
	ok(m.apply(0, {"op": "pick", "v": ["cold", "oil", "spike"]}) != "", "4장이 아니면 불가")
	ok(m.apply(0, {"op": "build", "type": "spike", "x": 5, "y": 2}) != "", "함정은 길 밖에 못 놓음")
	ok(m.apply(0, {"op": "build", "type": "spike", "x": 5, "y": 4}) == "", "함정은 길 칸에")
	ok(m.check_route(0, 0, _detour(m)).has("err") == false, "함정이 있어도 길은 다시 그릴 수 있음")
	var r := GMatch.new(["A", "B"])
	r.apply(0, {"op": "ready", "v": true})
	r.apply(0, {"op": "build", "type": "gun", "x": 5, "y": 3})
	ok(r.players[0]["ready"] == false, "건설을 바꾸면 준비 해제")


func _flow() -> void:
	var m := GMatch.new(["A", "B"], [], 5)
	var total_enemies := 0
	for g in m.plan:
		total_enemies += int(g[2])
	m.apply(0, {"op": "ready"})
	ok(m.phase == "prep", "한 명만 준비하면 시작 안 함")
	m.apply(1, {"op": "ready"})
	ok(m.phase == "combat", "전원 준비 시 전투")
	ok(m.apply(0, {"op": "build", "type": "gun", "x": 5, "y": 3}) != "", "전투 중 건설 불가")
	ok(m.apply(0, {"op": "ability", "x": 3.0, "y": 1.5}) == "", "긴급 냉각 사용")
	ok(m.apply(0, {"op": "ability", "x": 3.0, "y": 1.5}) != "", "웨이브당 1회")
	var en := _enemy(999, 1.0)
	for _i in 4:
		m._chill(en, 0.55, 1.0, 0)
	m._chill(en, 0.9, 1.0, 0)
	ok(float(en["slow"]) <= GData.SLOW_CAP, "감속 상한")
	var guard := 0
	while m.phase == "combat" and guard < 40000:
		m.step()
		guard += 1
	ok(m.phase == "prep" and m.wave == 2, "웨이브 종료 후 다음 준비")
	ok(m.hp == GData.CASTLE_HP - total_enemies, "포탑 없으면 모두 도착 (%d)" % total_enemies)
	ok(int(m.players[0]["mat"]) == GData.MAT_START + GData.MAT_WAVE, "웨이브마다 자재 +3")
	var leaked := 0
	for v in m.summary["leaks"]:
		leaked += int(v)
	ok(int(m.summary["wave"]) == 1 and leaked == total_enemies, "웨이브 결과에 입구별 새어 나간 적 수")
	m.apply(0, {"op": "draft", "e": 0, "path": Board.flat(_detour(m))})
	m.set_online(0, false)
	ok(m.drafts.is_empty(), "끊긴 사람의 미리보기는 정리")
	m.apply(1, {"op": "ready"})
	ok(m.phase == "combat", "끊긴 사람은 준비 판정 제외")
	m.hp = 1
	guard = 0
	while m.phase == "combat" and guard < 40000:
		m.step()
		guard += 1
	ok(m.phase == "over" and not m.cleared and m.failed_wave == 2, "성 붕괴로 패배")


func _towers() -> void:
	var cold := GMatch.new(["A", "B"])
	cold.apply(0, {"op": "build", "type": "cold", "x": 5, "y": 3})
	cold.enemies = [_enemy(1, 4.0), _enemy(2, 5.0), _enemy(3, 6.0)]
	cold.phase = "combat"
	cold._fire(0.05)
	ok(cold.enemies.all(func(e): return (e["st"] as Dictionary).has("cold") and is_equal_approx(cold.move_slow(e), 0.3)), "냉각탑은 범위 안 전부 냉기 (30% 감속)")
	var ap := GMatch.new(["A", "B"])
	ap.phase = "combat"
	var hv := _enemy(1, 2.0)
	hv["type"] = "heavy"
	ap.enemies = [hv]
	ap._hurt(hv, GData.tower_stats("gun", 3, "b"), 0)
	ok(is_equal_approx(100.0 - float(hv["hp"]), 16.0), "철갑탄은 방어 무시")
	# 전기탑: 연쇄, 감속된 적은 2배
	var sh := GMatch.new(["A", "B"], [["shock", "cold", "gun", "oil", "flame"]])
	sh.apply(0, {"op": "build", "type": "shock", "x": 5, "y": 3})
	sh.enemies = [_enemy(1, 4.0), _enemy(2, 5.0), _enemy(3, 6.0)]
	sh.enemies[2]["slow"] = 0.3
	sh.phase = "combat"
	sh._fire(0.05)
	ok(sh.enemies.all(func(e): return float(e["hp"]) < 100.0), "전기탑 번개가 세 명에게 튐")
	ok(sh.enemies.all(func(e): return (e["st"] as Dictionary).has("shock")), "번개 맞은 적은 감전")
	# 불꽃 + 기름
	var f := GMatch.new(["A", "B"])
	f.phase = "combat"
	var a := _enemy(1, 2.0)
	var b := _enemy(2, 2.0)
	f.enemies = [a, b]
	f._apply_status(b, "oil", 1)
	var flame := GData.tower_stats("flame", 1, "")
	f._hurt(a, flame, 0)
	f._hurt(b, flame, 0)
	ok((a["st"] as Dictionary).has("burn") and 100.0 - float(b["hp"]) >= 30.0 and int(f.rx_log.get("ignite", 0)) == 1, "기름 + 화상 = 인화 폭발")
	var golem := _enemy(3, 2.0)
	golem["type"] = "golem"
	f.enemies.append(golem)
	f._hurt(golem, flame, 0)
	ok(float(golem["hp"]) == 100.0 and not (golem["st"] as Dictionary).has("burn"), "내열 골렘은 불·화상 면역")
	var oil := GMatch.new(["A", "B"])
	oil.phase = "combat"
	var c := _enemy(1, 2.0)
	oil.enemies = [c]
	oil._hurt(c, GData.tower_stats("oil", 1, ""), 0)
	ok((c["st"] as Dictionary).has("oil"), "기름분사탑은 기름 상태를 묻힘")
	# 신호탑: 주변 사거리 +15%, 유령 실체화
	var sg := GMatch.new(["A", "B"], [["gun", "signal", "cold", "oil", "flame"]])
	sg.apply(0, {"op": "build", "type": "gun", "x": 5, "y": 3})
	var gun_id: int = sg.towers.keys()[0]
	var base := sg.tower_range(sg.towers[gun_id])
	sg.apply(0, {"op": "build", "type": "signal", "x": 6, "y": 3})
	ok(is_equal_approx(sg.tower_range(sg.towers[gun_id]), base * 1.15), "신호탑 옆 포탑 사거리 +15%")
	# 저격탑 기본 우선순위는 강한 적
	var sn := GMatch.new(["A", "B"], [["sniper", "signal", "cold", "oil", "flame"]])
	sn.apply(0, {"op": "build", "type": "sniper", "x": 5, "y": 3})
	ok(str(sn.towers.values()[0]["prio"]) == "strong" and float(sn.tower_range(sn.towers.values()[0])) >= 6.0, "저격탑: 먼 사거리, 강한 적 우선")
	# 가시 덫개: 지나가는 적마다 피해, 내구 감소, 수리
	var sp := GMatch.new(["A", "B"])
	sp.apply(0, {"op": "build", "type": "spike", "x": 1, "y": 4})
	var trap: Dictionary = sp.towers.values()[0]
	sp.phase = "combat"
	var walker := _enemy(1, 1.0)
	sp.enemies = [walker]
	for _i in 30:
		sp._move_enemies(0.05)
	ok(float(walker["hp"]) < 100.0 and int(trap["uses"]) == 29, "가시 덫개는 밟은 적에게 피해, 내구 1 감소")
	sp.phase = "prep"
	ok(sp.apply(0, {"op": "repair", "id": trap["id"]}) == "" and int(trap["uses"]) == 30 and int(sp.players[0]["mat"]) == GData.MAT_START - 1, "수리는 자재 1")
	var one := GMatch.new(["A", "B"])
	one.apply(0, {"op": "ability", "x": 1.0, "y": 1.0})
	ok(GData.ABILITY_RADIUS == 1.5 and GData.ABILITY_SLOW == 0.4, "긴급 냉각 시안 수치")


func _enemies() -> void:
	var m := GMatch.new(["A", "B"])
	m.phase = "combat"
	var healer := _enemy(1, 3.0)
	healer["type"] = "healer"
	var hurt := _enemy(2, 3.5)
	hurt["hp"] = 50.0
	m.enemies = [healer, hurt]
	m._enemy_skills(1.0)
	ok(float(hurt["hp"]) > 50.0, "치유사는 주변 적을 회복")
	var sp := _enemy(3, 4.0)
	sp["type"] = "splitter"
	m.enemies = [sp]
	m._hurt(sp, {"dmg": 500.0, "pierce": 0.0, "slow": 0.0}, 0)
	ok(m.enemies.size() == 2 and m.enemies.all(func(e): return e["type"] == "mini"), "분열체는 죽으면 작은 적 2개")
	var ph := _enemy(4, 5.0)
	ph["type"] = "phantom"
	m.enemies = [ph]
	m.time = 0.0
	var hidden_at := -1.0
	for k in 50:
		m.time = k * 0.1
		if m.is_hidden(ph):
			hidden_at = m.time
			break
	ok(hidden_at >= 0.0, "유령병은 주기적으로 조준 불가")
	m.phase = "prep"
	m.players[0]["kit"] = ["gun", "signal", "cold", "oil"]
	m.apply(0, {"op": "build", "type": "signal", "x": 5, "y": 3})
	m.time = hidden_at
	ok(not m.is_hidden(ph), "신호탑 근처의 유령병은 실체화")
	var shield := _enemy(5, 2.0)
	shield["type"] = "shield"
	var plain := _enemy(6, 2.0)
	m.phase = "combat"
	m.enemies = [shield, plain]
	shield["slow"] = 0.4
	plain["slow"] = 0.4
	m._move_enemies(1.0)
	var adv_s := float(shield["dist"]) - 2.0
	var adv_p := float(plain["dist"]) - 2.0
	ok(adv_s / float(GData.ENEMIES["shield"]["speed"]) > adv_p / float(GData.ENEMIES["grunt"]["speed"]), "방패병은 감속을 절반만 받음")
	var carrier := _enemy(7, 3.0)
	carrier["type"] = "carrier"
	var near := _enemy(8, 3.2)
	m.enemies = [carrier, near]
	m._enemy_skills(1.0)
	ok(float(near["sh"]) > 0.0, "방패 수송차는 주변 적에게 보호막")
	var boss := _enemy(9, 3.0)
	boss["type"] = "fortress"
	boss["hp"] = 100.0
	boss["max"] = 100.0
	m.enemies = [boss]
	m._hurt(boss, {"dmg": 60.0, "pierce": 99.0, "slow": 0.0}, 0)
	m._enemy_skills(0.05)
	ok(m.enemies.filter(func(e): return e["type"] == "swarm").size() == 8, "모래 수송 요새는 체력 50%에서 떼거리 8명")
	var giant := _enemy(10, 5.0)
	giant["type"] = "giant"
	var gm := GMatch.new(["A", "B"])
	gm.apply(0, {"op": "build", "type": "gun", "x": 5, "y": 3})
	gm.phase = "combat"
	gm.enemies = [giant]
	gm._enemy_skills(8.1)
	ok(float(gm.towers.values()[0]["heat"]) > 0.0, "용광로 거인은 주변 포탑을 과열")


func _themes() -> void:
	ok(GData.theme_of(5) == 0 and GData.theme_of(6) == 1 and GData.theme_of(21) == 4 and GData.theme_of(25) == 4, "5웨이브마다 테마 전환")
	ok(GData.max_path(1) == 64 and GData.max_path(21) == 96, "길이 상한 64 → 테마마다 +8")
	var m := GMatch.new(["A", "B"])
	ok(m.apply(0, {"op": "build", "type": "gun", "x": 5, "y": 13}) != "", "랜드마크 구역 건설 불가")
	ok(m.apply(0, {"op": "build", "type": "gun", "x": 1, "y": 10}) != "", "바위 자리에 건설 불가")
	ok(m.apply(0, {"op": "build", "type": "gun", "x": 3, "y": 2}) != "", "강에 건설 불가")
	ok(m.board.ground_err(Vector2i(3, 4), 0, true) == "" and m.board.ground_err(Vector2i(3, 4), 0, false) != "", "다리는 길만")
	m.players[0]["gold"] = 999
	m.apply(0, {"op": "build", "type": "gun", "x": 14, "y": 6})
	m.apply(0, {"op": "build", "type": "gun", "x": 10, "y": 6})
	var hi: Dictionary = m.towers.values()[0]
	var lo: Dictionary = m.towers.values()[1]
	ok(is_equal_approx(m.tower_range(hi), m.tower_range(lo) + GData.HIGH_RANGE), "높은 땅은 사거리 +1칸")
	var four := GMatch.new(["A", "B", "C", "D"])
	ok(four.apply(0, {"op": "build", "type": "gun", "x": 3, "y": 14}) != "", "초원 연못에 건설 불가")
	ok(four.board.ground_err(Vector2i(3, 14), 1, true) == "" and four.board.ground_err(Vector2i(3, 14), 1, false) != "", "설원 얼음 연못은 길만")
	ok(four.board.ground_err(Vector2i(3, 14), 2, false) == "", "사막 마른 연못은 건설 가능")
	GData.use_layout(2)
	m.wave = 6
	m.phase = "combat"
	var ice := _enemy(1, 8.0)
	m.enemies = [ice]
	var cell: Vector2i = m.board.paths[0][8]
	m.ice_t[cell] = 5.0
	m._move_enemies(1.0)
	ok(is_equal_approx(float(ice["dist"]), 8.0 + 1.25 * GData.SPEED_MUL * GData.ICE_SPEED), "빙판 칸은 적 가속")
	m.wave = 16
	var hot := _enemy(2, 7.2)        # (6,5) 균열 칸
	m.enemies = [hot]
	m._move_enemies(0.5)
	ok(float(hot["hp"]) < 100.0, "화산 균열 길은 적에게 지속 피해")
	m.phase = "prep"
	ok(m.board.can_build(Vector2i(7, 5), m.tower_cells(), 3) != "" and m.board.can_build(Vector2i(7, 5), m.tower_cells(), 0) == "", "균열 옆 칸은 화산부터 건설 금지")
	var sand := GMatch.new(["A", "B"])
	sand.wave = 11
	var old_road: Rect2i = GData.OLD_ROADS[0]
	ok(GData.is_old_road(old_road.position, 2) and not GData.is_old_road(old_road.position, 1), "옛 도로는 사막부터")
	ok(sand.sand_spot().x > -50 and GMatch.new(["A", "B"]).sand_spot().x < -50, "모래바람은 사막에서만")
	var g := GMatch.new(["A", "B"])
	g.wave = 5
	g._advance()
	ok(g.wave == 6 and g.board.paths.size() == 3 and g.board.opened and g.gate_dmg.size() == 3, "설원에서 새 입구 하나")
	g.wave = 20
	g._advance()
	ok(g.board.paths.size() == 4 and g.gate_dmg.size() == 4, "2인은 입구 최대 4")
	var g4 := GMatch.new(["A", "B", "C", "D"])
	g4.wave = 20
	g4._advance()
	ok(g4.board.paths.size() == 6, "4인은 입구 최대 6")
	GData.use_layout(2)


func _waves() -> void:
	var a := GData.make_wave(7, 2, 2, 42)
	var b := GData.make_wave(7, 2, 2, 42)
	ok(a == b, "같은 시드면 같은 웨이브")
	for w in [5, 10, 15, 20, 25]:
		var boss: String = GData.THEME_BOSS[GData.theme_of(w)]
		ok(GData.make_wave(w, 2, 2 if w < 21 else 3, 1).any(func(g): return g[1] == boss), "%d웨이브 보스 %s" % [w, GData.ENEMIES[boss]["name"]])
	var bosses := {}
	for k in GData.THEME_BOSS:
		bosses[k] = true
	ok(bosses.size() == 5, "보스 5종이 모두 다름")
	var first := GData.make_wave(6, 2, 2, 3)
	var lanes := {}
	for g in first:
		if GData.THEME_FOES[1].has(g[1]):
			lanes[g[0]] = true
	ok(lanes.size() == 1, "테마 첫 웨이브 전용 적은 입구 하나")
	var budget := 0.0
	for g in GData.make_wave(12, 4, 4, 9):
		budget += float(GData.ENEMIES[g[1]]["price"]) * int(g[2])
	ok(budget <= GData.wave_budget(12, 4) + 0.01 and budget >= GData.wave_budget(12, 4) * 0.8, "위협 예산 안에서 웨이브 구성")


func _rewards() -> void:
	var m := GMatch.new(["A", "B"])
	m.wave = GData.THEME_LEN
	m.hp = 80
	m._finish_wave()
	ok(m.phase == "reward", "보스 뒤에는 보상 투표")
	ok(m.apply(0, {"op": "build", "type": "gun", "x": 5, "y": 3}) != "", "보상 투표 중에는 건설 불가")
	m.apply(0, {"op": "vote", "v": "heal"})
	ok(m.phase == "reward", "한 명만 투표하면 그대로")
	m.apply(1, {"op": "vote", "v": "gold"})
	ok(m.phase == "prep" and m.hp == 90 and m.summary["reward"] == "heal", "동점이면 목록 앞쪽(본부 회복)")
	var g := GMatch.new(["A", "B"])
	g.phase = "reward"
	g.apply(0, {"op": "vote", "v": "up"})
	g.apply(1, {"op": "vote", "v": "up"})
	g.apply(0, {"op": "build", "type": "gun", "x": 5, "y": 3})
	var id: int = g.towers.keys()[0]
	var gold: int = g.players[0]["gold"]
	ok(g.apply(0, {"op": "upgrade", "id": id}) == "" and int(g.players[0]["gold"]) == gold and int(g.players[0]["free_up"]) == 0, "무료 강화 1회")
	var mag := GMatch.new(["A", "B"])
	mag.phase = "combat"
	var heavy := _enemy(7, 1.0)
	heavy["type"] = "heavy"
	mag.enemies = [heavy]
	var gun := GData.tower_stats("gun", 1, "")
	mag._hurt(heavy, gun, 0)
	var plain := 100.0 - float(heavy["hp"])
	heavy["hp"] = 100.0
	mag._hurt(heavy, GData.tower_stats("magnet", 1, ""), 0)
	heavy["hp"] = 100.0
	mag._hurt(heavy, gun, 0)
	ok(100.0 - float(heavy["hp"]) > plain, "자석탑이 방어력을 깎으면 기관포 피해 증가")


func _early() -> void:
	var m := GMatch.new(["A", "B"], [], 4)
	m.apply(0, {"op": "ready", "v": true})
	m.apply(1, {"op": "ready", "v": true})
	ok(m.apply(0, {"op": "call", "v": true}) != "" and not m.can_call(), "적이 다 나오기 전에는 일찍 부를 수 없음")
	var guard := 0
	while not m._queue.is_empty() and guard < 5000:
		m.step()
		guard += 1
	ok(m.can_call(), "적이 다 나오고 남아 있으면 일찍 부르기 가능")
	var alive := m.enemies.size()
	var gold: int = m.players[0]["gold"]
	m.apply(0, {"op": "call", "v": true})
	ok(m.wave == 1 and m.phase == "combat", "한 명만 부르면 그대로")
	m.apply(1, {"op": "call", "v": true})
	var want := GData.wave_gold(1) + GData.early_bonus(alive)
	ok(m.wave == 2 and m.phase == "combat" and m.enemies.size() >= alive, "전원 동의하면 남은 적을 둔 채 다음 웨이브 시작")
	ok(int(m.players[0]["gold"]) == gold + want and int(m.summary["early"]) == GData.early_bonus(alive), "웨이브 골드 + 일찍 부르기 보너스")
	ok(not bool(m.players[0]["call"]) and not bool(m.players[1]["call"]), "부르기 표는 초기화")
	var b := GMatch.new(["A"])
	b.wave = GData.THEME_LEN
	b.phase = "combat"
	b.enemies = [_enemy(1, 1.0)]
	ok(not b.can_call(), "보스 웨이브는 일찍 부를 수 없음")
	ok(GData.early_bonus(1) == GData.EARLY_MIN and GData.early_bonus(99) == GData.EARLY_MAX, "보너스 하한·상한")


func _enemy(id: int, dist: float) -> Dictionary:
	return {"id": id, "type": "grunt", "e": 0, "dist": dist, "hp": 100.0, "max": 100.0, "slow": 0.0, "slow_t": 0.0,
		"sh": 0.0, "cell": -1, "sk": 0.0, "done": [], "st": {}, "rx_t": 0.0, "stun": 0.0, "arm_dn": 0.0, "brit_t": 0.0, "melt_t": 0.0}


## 반응 한 번: a 상태를 o1 이, b 상태를 o2 가
func _rx(a: String, b: String, o1 := 0, o2 := 0) -> Array:
	var m := GMatch.new(["A", "B"])
	m.phase = "combat"
	var en := _enemy(1, 6.0)
	en["hp"] = 1000.0
	en["max"] = 1000.0
	var near := _enemy(2, 6.3)
	near["hp"] = 1000.0
	near["max"] = 1000.0
	m.enemies = [en, near]
	m._apply_status(en, a, o1)
	m._apply_status(en, b, o2)
	return [m, en, near]


func _new_towers() -> void:
	ok(GData.unlocked(6).size() == 13 and GData.unlocked(11).size() == 16 and GData.unlocked(16).size() == 18, "포탑 열림: 초원 10 → 설원 +3 → 사막 +3 → 화산 +2")
	ok(GData.fresh_unlocks(6) == ["steam", "cryo", "searchlight"] and GData.fresh_unlocks(7).is_empty(), "새로 열린 포탑은 테마 첫 웨이브에")
	# 증기탑: 혼자서 냉기·화상 번갈아 → 열충격
	var st := GMatch.new(["A", "B"], [["steam", "gun", "cold", "spike"]])
	st.apply(0, {"op": "build", "type": "steam", "x": 5, "y": 3})
	st.phase = "combat"
	var a := _enemy(1, 5.0)
	a["hp"] = 1000.0
	st.enemies = [a]
	for _i in 30:
		st._fire(0.05)
	ok(int(st.rx_log.get("thermal", 0)) >= 1, "증기탑 혼자서 열충격")
	# 크레인 A: 기절
	var cr := GMatch.new(["A", "B"])
	cr.phase = "combat"
	var b := _enemy(1, 5.0)
	cr.enemies = [b]
	cr._hurt(b, GData.tower_stats("crane", 3, "a"), 0)
	ok(float(b["stun"]) >= 1.0, "크레인 들었다 놓기: 기절")
	# 발전기: 주변 전기 피해 +
	var gn := GMatch.new(["A", "B"], [["shock", "generator", "cold", "spike"]])
	gn.apply(0, {"op": "build", "type": "shock", "x": 5, "y": 3})
	gn.apply(0, {"op": "build", "type": "generator", "x": 7, "y": 3})
	ok(is_equal_approx(float(gn._volt_at(Vector2(5.5, 3.5))[0]), 0.2), "발전기 근처 전기 피해 +20%")
	# 비상 배터리: 긴급 냉각 +1
	var bt := GMatch.new(["A", "B"], [["generator", "gun", "cold", "spike"]])
	bt.players[0]["gold"] = 2000
	bt.apply(0, {"op": "build", "type": "generator", "x": 7, "y": 3})
	var gid: int = bt.towers.keys()[0]
	bt.apply(0, {"op": "upgrade", "id": gid})
	bt.apply(0, {"op": "upgrade", "id": gid, "branch": "b"})
	bt.apply(0, {"op": "ready", "v": true})
	bt.apply(1, {"op": "ready", "v": true})
	ok(bt.apply(0, {"op": "ability", "x": 5.0, "y": 4.0}) == "" and bt.apply(0, {"op": "ability", "x": 6.0, "y": 4.0}) == "" and bt.apply(0, {"op": "ability", "x": 6.0, "y": 4.0}) != "", "비상 배터리: 긴급 냉각 2회")
	# 컨베이어 A: 한 칸 뒤로
	var cv := GMatch.new(["A", "B"], [["conveyor", "gun", "cold", "spike"]])
	cv.players[0]["gold"] = 2000
	cv.apply(0, {"op": "build", "type": "conveyor", "x": 3, "y": 4})
	var cid: int = cv.towers.keys()[0]
	cv.apply(0, {"op": "upgrade", "id": cid})
	cv.apply(0, {"op": "upgrade", "id": cid, "branch": "a"})
	cv.phase = "combat"
	var w := _enemy(1, 2.6)
	cv.enemies = [w]
	cv._move_enemies(0.2)
	ok(float(w["dist"]) < 2.6, "컨베이어 역회전: 뒤로 밀림")
	# 용접 A: 화상 + 감전 (과열), B: 누적
	var wd := GMatch.new(["A", "B"])
	wd.phase = "combat"
	var c := _enemy(1, 5.0)
	c["hp"] = 1000.0
	wd.enemies = [c]
	wd._hurt(c, GData.tower_stats("welder", 3, "a"), 0)
	ok(int(wd.rx_log.get("overheat", 0)) == 1, "플라스마: 화상 + 감전 = 과열")
	# 냉동 미사일 A: 산산조각
	var cy := GMatch.new(["A", "B"])
	cy.phase = "combat"
	var d := _enemy(1, 5.0)
	d["hp"] = 1000.0
	cy.enemies = [d]
	cy._apply_status(d, "cold", 1)
	cy._hurt(d, GData.tower_stats("cryo", 3, "a"), 0)
	ok(int(cy.rx_log.get("shatter", 0)) == 1, "집속탄: 냉기 적에게 산산조각")
	# 탐조등: 표식, 유령 드러냄
	var sl := GMatch.new(["A", "B"], [["searchlight", "gun", "cold", "spike"]])
	sl.apply(0, {"op": "build", "type": "searchlight", "x": 5, "y": 3})
	sl.phase = "combat"
	var e := _enemy(1, 5.0)
	sl.enemies = [e]
	sl._fire(0.05)
	ok((e["st"] as Dictionary).has("mark") and sl._revealed(Vector2(5.5, 4.5)), "탐조등: 표식과 드러내기")
	# 고철 더미: 자성 장판
	var sc := GMatch.new(["A", "B"])
	sc.phase = "combat"
	var f := _enemy(1, 5.0)
	sc.enemies = [f]
	var ss := GData.tower_stats("scrap", 3, "a")
	ss["range"] = 5.0
	sc.towers[99] = {"id": 99, "owner": 0, "type": "scrap", "x": 5, "y": 3, "lv": 3, "branch": "a", "spent": 0, "prio": "first", "cd": 0.0, "uses": 0, "heat": 0.0, "fresh": false}
	sc._fire(0.05)
	var has_mag := false
	for k in sc.puddle_t:
		if str(sc.puddle_t[k][2]) == "mag":
			has_mag = true
	ok(has_mag, "고철 더미: 자성 장판")


func _picks() -> void:
	var m := GMatch.new(["A", "B"], [], 11)
	ok((m.players[0]["hand"] as Array).size() == GData.HAND_SIZE and (m.players[1]["hand"] as Array).size() == GData.HAND_SIZE, "준비 시작 때 각자 카드 6장")
	var both := 0
	for k in m.players[0]["hand"]:
		if (m.players[1]["hand"] as Array).has(k):
			both += 1
	ok(both <= 2, "두 사람 카드 겹침은 최대 2장 (%d)" % both)
	ok(GData.unlocked(1).size() == 10, "초원은 기존 10종")
	var hand: Array = m.players[0]["hand"]
	m.apply(0, {"op": "pick", "v": hand.slice(0, 4)})
	ok(m.apply(0, {"op": "lock", "v": hand[0]}) == "" and str(m.players[0]["lock"]) == hand[0], "고른 카드 하나 잠금")
	ok(m.apply(0, {"op": "lock", "v": "nope"}) != "", "공구함에 없는 카드는 못 잠금")
	var gold: int = m.players[0]["gold"]
	ok(m.apply(0, {"op": "reroll"}) == "" and int(m.players[0]["gold"]) == gold, "다시 뽑기 첫 번은 무료")
	ok(m.apply(0, {"op": "reroll"}) == "" and int(m.players[0]["gold"]) == gold - GData.REROLL_COST, "두 번째부터 30골드")
	m.wave = 1
	m._finish_wave()
	ok(m.wave == 2 and (m.players[0]["kit"] as Array).has(hand[0]) and not (m.players[0]["hand"] as Array).has(hand[0]), "잠근 카드는 다음 웨이브에도 공구함에 (손패에는 없음)")
	var h2: Array = m.players[0]["hand"]
	ok(m.apply(0, {"op": "pick", "v": h2.slice(0, 3)}) == "" and (m.players[0]["kit"] as Array)[0] == hand[0], "잠금이 있으면 3장만 고름")
	var keep: Array = (m.players[1]["kit"] as Array).duplicate()
	m.apply(0, {"op": "ready", "v": true})
	m.apply(1, {"op": "ready", "v": true})
	ok(m.players[1]["kit"] == keep, "안 고르고 준비하면 지난 공구함 그대로")
	var tb := GMatch.new(["A", "B"])
	tb.players[0]["kit"] = ["gun", "cannon", "cold", "oil"]
	tb.players[1]["kit"] = ["flame", "shock", "sniper", "spike"]
	var mat: int = tb.players[0]["mat"]
	tb.apply(0, {"op": "ready", "v": true})
	tb.apply(1, {"op": "ready", "v": true})
	ok(int(tb.players[0]["mat"]) == mat + 1, "팀 공구함 서로 다른 6종 이상이면 자재 +1")
	var bot := GMatch.new(["A", "B"], [], 5)
	GBot.pick_hand(bot, 1)
	ok(bool(bot.players[1]["picked"]) and (bot.players[1]["kit"] as Array).size() == 4, "봇도 손패에서 4장 고름")
	var copy := GMatch.new()
	copy.load_data(JSON.parse_string(JSON.stringify(m.to_data())))
	ok(copy.players[0]["hand"] == m.players[0]["hand"] and copy.players[0]["lock"] == m.players[0]["lock"], "손패·잠금 동기화")


func _reactions() -> void:
	var r := _rx("oil", "burn")
	ok(int(r[0].rx_log.get("ignite", 0)) == 1 and float(r[2]["hp"]) <= 970.0 and not (r[1]["st"] as Dictionary).has("oil"), "인화: 반지름 1칸 폭발 30, 두 상태 사라짐")
	r = _rx("oil", "cold")
	ok(float(r[1]["stun"]) >= 1.5, "굳음: 1.5초 멈춤")
	r = _rx("oil", "shock")
	ok(float(r[1]["hp"]) <= 980.0, "합선: 기름 묻은 적 피해 20")
	r = _rx("cold", "burn")
	ok(float(r[1]["arm_dn"]) == 1.0 and float(r[1]["hp"]) <= 985.0, "열충격: 방어 영구 -1, 피해 15")
	r = _rx("cold", "shock")
	ok(float(r[2]["hp"]) < 1000.0, "초전도: 주변 적에게 번개")
	r = _rx("cold", "mag")
	ok(float(r[1]["brit_t"]) > 0.0 and (r[1]["st"] as Dictionary).has("mag"), "취성: 물리 피해 +50%, 자성은 남음")
	var m: GMatch = r[0]
	var plain := _enemy(3, 6.0)
	m.enemies.append(plain)
	var gun := GData.tower_stats("gun", 1, "")
	var h0 := float(r[1]["hp"])
	m._hurt(r[1], gun, 0)
	m._hurt(plain, gun, 0)
	ok(h0 - float(r[1]["hp"]) > (100.0 - float(plain["hp"])) * 1.4, "취성 적에게 물리 피해 증가")
	r = _rx("mag", "shock")
	ok(int(r[0].rx_log.get("emag", 0)) == 1 and float(r[2]["dist"]) < 6.3, "전자석: 끌어모음")
	r = _rx("mag", "burn")
	ok(float(r[1]["melt_t"]) > 0.0, "가열 장갑: 방어력 0")
	r = _rx("shock", "burn")
	ok((r[2]["st"] as Dictionary).has("burn") and float(r[2]["hp"]) <= 975.0, "과열: 주변 피해 25, 화상 퍼짐")
	# 산산조각
	var sm := GMatch.new(["A", "B"])
	sm.phase = "combat"
	var ice := _enemy(1, 6.0)
	ice["hp"] = 1000.0
	sm.enemies = [ice]
	sm._apply_status(ice, "cold", 1)
	sm._hurt(ice, GData.tower_stats("cannon", 3, "b"), 0)
	ok(is_equal_approx(1000.0 - float(ice["hp"]), 52.0 * 1.5) and int(sm.rx_log.get("shatter", 0)) == 1, "산산조각: 냉기 + 한 방 40 이상 = ×1.5")
	# 미끄럼
	var sl := GMatch.new(["A", "B"])
	sl.apply(0, {"op": "build", "type": "spike", "x": 1, "y": 4})
	sl.phase = "combat"
	var w := _enemy(1, 0.6)
	w["hp"] = 1000.0
	sl.enemies = [w]
	sl._apply_status(w, "oil", 1)
	for _i in 20:
		sl._move_enemies(0.05)
	ok(int(sl.rx_log.get("slip", 0)) == 1 and 1000.0 - float(w["hp"]) >= 40.0, "미끄럼: 기름 + 덫 = 덫 피해 ×2")
	# 증폭
	var am := _rx("mark", "oil")
	am[0]._apply_status(am[1], "burn", 1)
	ok(int(am[0].rx_log.get("amp", 0)) == 1 and float(am[2]["hp"]) <= 1000.0 - 30.0 * 2.0 * 1.25 + 0.01, "증폭: 표식 + 반응 = 피해 ×2")
	ok((am[1]["st"] as Dictionary).has("mark"), "표식은 반응 뒤에도 남음")
	# 다른 사람끼리 +25%
	var same := _rx("oil", "burn", 0, 0)
	var cross := _rx("oil", "burn", 0, 1)
	ok(is_equal_approx(1000.0 - float(cross[2]["hp"]), (1000.0 - float(same[2]["hp"])) * 1.25), "다른 사람 포탑끼리 만든 반응 +25%")
	ok(float(cross[0].joint_dmg) > 0.0 and int(cross[0].players[1]["rx"]) == 1, "함께 만든 피해와 반응 기여 기록")
	# 1초에 한 번
	var once := _rx("oil", "burn")
	once[0]._apply_status(once[1], "oil", 0)
	once[0]._apply_status(once[1], "burn", 0)
	ok(int(once[0].rx_log.get("ignite", 0)) == 1, "같은 적 반응은 1초에 한 번")
	ok(once[0].seen_rx == ["ignite"], "처음 나온 반응은 도감에")
	var copy := GMatch.new()
	copy.load_data(JSON.parse_string(JSON.stringify(once[0].to_data())))
	copy.load_enemies(JSON.parse_string(JSON.stringify(once[0].enemies_data())))
	ok(copy.seen_rx == ["ignite"] and (copy.enemies[0]["st"] as Dictionary).has("oil"), "반응 기록·상태 동기화")


func _sync() -> void:
	var m := GMatch.new(["A", "B"])
	GBot.play_prep(m, 0)
	m.apply(1, {"op": "draft", "e": 0, "path": Board.flat(m.board.candidate(1, 1, "detour", 1))})
	m.apply(1, {"op": "draft", "e": 1, "path": Board.flat(m.board.candidate(1, 1, "detour", -1))})
	var copy := GMatch.new()
	copy.load_data(JSON.parse_string(JSON.stringify(m.to_data())))
	ok(copy.towers.size() == m.towers.size(), "사본 포탑 수")
	ok(copy.board.paths == m.board.paths, "사본 경로")
	ok(copy.players[0]["gold"] == m.players[0]["gold"] and copy.players[0]["gold"] is int, "사본 골드")
	ok(copy.plan.size() == m.plan.size() and copy.drafts.size() == m.drafts.size(), "사본 웨이브 구성과 미리보기")
	ok(copy.players[0]["kit"] == m.players[0]["kit"], "사본 공구함")
	m.apply(1, {"op": "ready"})
	for _i in 100:
		m.step()
	copy.load_enemies(JSON.parse_string(JSON.stringify(m.enemies_data())))
	ok(copy.enemies.size() == m.enemies.size() and copy.enemies.size() > 0, "사본 적 목록")
