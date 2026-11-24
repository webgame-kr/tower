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
	_roads()
	_economy()
	_flow()
	_towers()
	_sync()
	print("%d/%d passed" % [total - fails, total])
	quit(1 if fails > 0 else 0)


func _roads() -> void:
	var m := GMatch.new(["A", "B"])
	var before: int = m.board.paths[0].size()
	ok(m.apply(1, {"op": "edit", "e": 0, "i": 1, "kind": "detour", "side": 1}) != "", "담당자가 아니면 길 확정 불가")
	ok(m.apply(0, {"op": "draft", "e": 0, "i": 1, "kind": "detour", "side": 1}) == "", "미리보기 가능")
	ok(m.edits_left == 2 and m.board.paths[0].size() == before, "미리보기는 기회와 경로를 바꾸지 않음")
	ok(m.apply(0, {"op": "edit", "e": 0, "i": 1, "kind": "detour", "side": 1}) == "", "우회로 확정")
	ok(m.board.paths[0].size() == before + 4 and m.edits_left == 1, "우회로 +4칸, 기회 1 소비")
	ok(m.draft.is_empty(), "확정하면 미리보기 제거")
	ok(m.board.validate(0, m.board.paths[0], {}) == "", "개조 후 경로 유효")
	var blocked := GMatch.new(["A", "B"])
	blocked.apply(0, {"op": "build", "type": "gun", "x": 1, "y": 9})
	ok(blocked.board.reroute(0, 1, "detour", 1, blocked.tower_cells()).has("err"), "포탑과 겹치면 불가")
	ok(blocked.board.reroute(0, 3, "detour", 1, {}).has("err"), "곧지 않은 구간 불가")
	var edge := GMatch.new(["A", "B"])
	ok(edge.board.reroute(0, 1, "detour", -1, {}).has("path"), "위쪽 우회 가능")
	var long_path: Array = []
	for x in GData.MAX_PATH + 1:
		long_path.append(Vector2i(x % GData.W, 0))
	ok(edge.board.validate(0, long_path, {}) != "", "길이 상한 초과 불가")


func _economy() -> void:
	var m := GMatch.new(["A", "B"])
	ok(m.apply(0, {"op": "build", "type": "gun", "x": 3, "y": 8}) != "", "길 위 건설 불가")
	ok(m.apply(0, {"op": "build", "type": "gun", "x": 3, "y": 4}) == "", "건설")
	var gun_cost: int = GData.TOWERS["gun"]["cost"]
	ok(m.players[0]["gold"] == GData.START_GOLD - gun_cost, "골드 차감")
	var failed := m.apply(1, {"op": "build", "type": "gun", "x": 3, "y": 4})
	ok(failed != "" and m.players[1]["gold"] == GData.START_GOLD, "같은 칸 두 번째 요청은 실패하고 골드 유지")
	var id: int = m.towers.keys()[0]
	ok(m.apply(1, {"op": "sell", "id": id}) != "", "남의 포탑 판매 불가")
	ok(m.apply(1, {"op": "move", "id": id, "x": 4, "y": 4}) != "", "남의 포탑 이동 불가")
	ok(m.apply(0, {"op": "move", "id": id, "x": 4, "y": 4}) == "", "내 포탑 이동")
	ok(m.players[0]["gold"] == GData.START_GOLD - gun_cost, "이동은 무료")
	ok(m.apply(0, {"op": "upgrade", "id": id}) == "", "2단계 강화")
	ok(m.apply(0, {"op": "upgrade", "id": id}) != "", "3단계는 방향 필수")
	m.players[0]["gold"] = 500
	ok(m.apply(0, {"op": "upgrade", "id": id, "branch": "b"}) == "", "3단계 방향 선택")
	var spent: int = m.towers[id]["spent"]
	var g: int = m.players[0]["gold"]
	ok(m.apply(0, {"op": "sell", "id": id}) == "", "판매")
	ok(m.players[0]["gold"] == g + int(floor(spent * 0.8)), "80% 환급")
	var r := GMatch.new(["A", "B"])
	r.apply(0, {"op": "ready", "v": true})
	r.apply(0, {"op": "build", "type": "gun", "x": 3, "y": 4})
	ok(r.players[0]["ready"] == false, "건설을 바꾸면 준비 해제")


func _flow() -> void:
	var m := GMatch.new(["A", "B"])
	m.apply(0, {"op": "ready"})
	ok(m.phase == "prep", "한 명만 준비하면 시작 안 함")
	m.apply(1, {"op": "ready"})
	ok(m.phase == "combat", "전원 준비 시 전투")
	ok(m.apply(0, {"op": "build", "type": "gun", "x": 3, "y": 4}) != "", "전투 중 건설 불가")
	ok(m.apply(0, {"op": "ability", "x": 3.0, "y": 8.0}) == "", "긴급 냉각 사용")
	ok(m.apply(0, {"op": "ability", "x": 3.0, "y": 8.0}) != "", "웨이브당 1회")
	var en := {"id": 999, "type": "grunt", "e": 0, "dist": 1.0, "hp": 30.0, "max": 30.0, "slow": 0.0, "slow_t": 0.0}
	for _i in 4:
		m._chill(en, 0.55, 1.0, 0)
	m._chill(en, 0.9, 1.0, 0)
	ok(float(en["slow"]) <= GData.SLOW_CAP, "감속 상한")
	var guard := 0
	while m.phase == "combat" and guard < 20000:
		m.step()
		guard += 1
	ok(m.phase == "prep" and m.wave == 2, "웨이브 종료 후 다음 준비")
	ok(m.hp == GData.CASTLE_HP - 12, "포탑 없으면 12마리 도착 피해")
	ok(m.road_owner == 1, "길 담당자 순환")
	m.apply(0, {"op": "ready"})
	m.apply(1, {"op": "ready"})
	ok(m.phase == "combat" and m.apply(0, {"op": "ability", "x": 3.0, "y": 8.0}) == "", "다음 웨이브에 능력 다시 사용")
	guard = 0
	while m.phase == "combat" and guard < 20000:
		m.step()
		guard += 1
	m.wave = 2
	m.set_online(1, false)
	ok(m.road_owner == 0, "끊긴 담당자는 다음 사람에게 인계")
	m.apply(0, {"op": "ready"})
	ok(m.phase == "combat", "끊긴 사람은 준비 판정 제외")
	m.hp = 1
	guard = 0
	while m.phase == "combat" and guard < 20000:
		m.step()
		guard += 1
	ok(m.phase == "over" and not m.cleared and m.failed_wave == 2, "성 붕괴로 패배")


func _towers() -> void:
	var cold := GMatch.new(["A", "B"])
	cold.apply(0, {"op": "build", "type": "cold", "x": 2, "y": 9})
	cold.enemies = [_enemy(1, 1.0), _enemy(2, 2.0), _enemy(3, 3.0)]
	cold.phase = "combat"
	cold._fire(0.05)
	ok(cold.enemies.all(func(e): return float(e["slow"]) == 0.3), "냉각탑은 범위 안 전부 30% 감속")
	var line := GMatch.new(["A", "B"])
	line.players[0]["gold"] = 1000
	line.apply(0, {"op": "build", "type": "gun", "x": 0, "y": 9})
	var id: int = line.towers.keys()[0]
	line.apply(0, {"op": "upgrade", "id": id})
	line.apply(0, {"op": "upgrade", "id": id, "branch": "b"})
	line.board.paths[0] = [Vector2i(0, 8), Vector2i(1, 8), Vector2i(2, 8), Vector2i(3, 8)]
	line.towers[id]["y"] = 8
	line.towers[id]["x"] = 0
	line.enemies = [_enemy(1, 1.0), _enemy(2, 2.0), _enemy(3, 3.0)]
	line.phase = "combat"
	line._fire(0.05)
	ok(line.enemies.all(func(e): return float(e["hp"]) < 100.0), "관통 장포신은 일직선의 적을 모두 맞힘")
	var one := GMatch.new(["A", "B"])
	one.apply(0, {"op": "ability", "x": 1.0, "y": 1.0})
	ok(GData.ABILITY_RADIUS == 1.5 and GData.ABILITY_SLOW == 0.4, "긴급 냉각 시안 수치")


func _enemy(id: int, dist: float) -> Dictionary:
	return {"id": id, "type": "grunt", "e": 0, "dist": dist, "hp": 100.0, "max": 100.0, "slow": 0.0, "slow_t": 0.0}


func _sync() -> void:
	var m := GMatch.new(["A", "B"])
	GBot.play_prep(m, 0)
	var copy := GMatch.new()
	copy.load_data(JSON.parse_string(JSON.stringify(m.to_data())))
	ok(copy.towers.size() == m.towers.size(), "사본 포탑 수")
	ok(copy.board.paths == m.board.paths, "사본 경로")
	ok(copy.players[0]["gold"] == m.players[0]["gold"] and copy.players[0]["gold"] is int, "사본 골드")
	m.apply(1, {"op": "ready"})
	for _i in 100:
		m.step()
	copy.load_enemies(JSON.parse_string(JSON.stringify(m.enemies_data())))
	ok(copy.enemies.size() == m.enemies.size() and copy.enemies.size() > 0, "사본 적 목록")
