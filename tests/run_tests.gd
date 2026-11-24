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
	_themes()
	_rewards()
	_sync()
	print("%d/%d passed" % [total - fails, total])
	quit(1 if fails > 0 else 0)


func _roads() -> void:
	var m := GMatch.new(["A", "B"])
	var before: int = m.board.paths[0].size()
	ok(m.apply(1, {"op": "draft", "e": 0, "i": 1, "kind": "detour", "side": 1}) == "" and int(m.draft["seat"]) == 1, "누구나 미리보기를 올리고 주인이 보임")
	ok(m.team_edits() == 2 and m.board.paths[0].size() == before, "미리보기는 기회와 경로를 바꾸지 않음")
	ok(m.apply(0, {"op": "edit", "e": 0, "i": 1, "kind": "detour", "side": 1}) == "", "다른 사람의 제안을 내 기회로 확정")
	ok(m.board.paths[0].size() == before + 4 and int(m.players[0]["edits"]) == 0 and int(m.players[1]["edits"]) == 1, "우회로 +4칸, 확정한 사람의 기회만 소비")
	ok(m.draft.is_empty(), "확정하면 미리보기 제거")
	ok(m.apply(0, {"op": "edit", "e": 1, "i": 1, "kind": "detour", "side": 1}) != "", "내 기회를 다 쓰면 확정 불가")
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
	ok(int(m.players[0]["edits"]) == GData.EDITS_PER_PLAYER, "보스 전에는 길 개조 기회가 다시 생기지 않음")
	ok(int(m.summary["wave"]) == 1 and int(m.summary["leaks"][0]) + int(m.summary["leaks"][1]) == 12, "웨이브 결과에 입구별 새어 나간 적 수")
	m.apply(0, {"op": "ready"})
	m.apply(1, {"op": "ready"})
	ok(m.phase == "combat" and m.apply(0, {"op": "ability", "x": 3.0, "y": 8.0}) == "", "다음 웨이브에 능력 다시 사용")
	guard = 0
	while m.phase == "combat" and guard < 20000:
		m.step()
		guard += 1
	m.wave = 2
	m.apply(1, {"op": "draft", "e": 0, "i": 1, "kind": "detour", "side": 1})
	m.set_online(1, false)
	ok(m.draft.is_empty(), "끊긴 사람의 미리보기는 정리")
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


func _themes() -> void:
	ok(GData.theme_of(5) == 0 and GData.theme_of(6) == 1 and GData.theme_of(21) == 4 and GData.theme_of(25) == 4, "5웨이브마다 테마 전환")
	var m := GMatch.new(["A", "B"])
	ok(m.apply(0, {"op": "build", "type": "gun", "x": 19, "y": 3}) != "", "랜드마크 구역 건설 불가")
	for e in 2:
		for c in m.board.paths[e]:
			ok(not GData.LANDMARK.has_point(c), "기본 길은 랜드마크와 겹치지 않음")
	var spots := [0, 0]
	for e in 2:
		for i in m.board.paths[e].size():
			for side in [1, -1]:
				if m.board.reroute(e, i, "detour", side, {}).has("path"):
					spots[e] += 1
	ok(spots[0] >= 6 and spots[1] >= 6, "랜드마크가 있어도 우회로 자리가 충분함")
	m.apply(0, {"op": "build", "type": "gun", "x": 19, "y": 10})
	var id: int = m.towers.keys()[0]
	var before: Array = m.board.paths.duplicate(true)
	var base := m.tower_range(m.towers[id])
	m.wave = 11
	ok(is_equal_approx(m.tower_range(m.towers[id]), base * GData.SAND_RANGE), "사막 모래바람은 구역 안 포탑 사거리 감소")
	ok(m.board.paths == before and int(m.towers[id]["owner"]) == 0, "테마가 바뀌어도 길과 포탑 유지")
	m.wave = 6
	m.phase = "combat"
	m.enemies = [_enemy(1, 7.0)]
	m.enemies[0]["dist"] = 8.0
	m._move_enemies(1.0)
	ok(is_equal_approx(float(m.enemies[0]["dist"]), 8.0 + 1.25 * GData.ICE_SPEED), "설원 빙판은 적 가속")
	m.wave = 16
	m.enemies = [_enemy(1, 12.0)]
	m._move_enemies(1.0)
	ok(float(m.enemies[0]["hp"]) < 100.0, "화산 용암은 적에게 지속 피해")
	m.wave = 21
	var ghost := _enemy(3, 2.0)
	m.time = GData.GHOST_CYCLE - 3 * 0.37
	ok(m.is_ghost(ghost), "유령 상태 판정")
	m.enemies = [ghost]
	ok(m._pick(Vector2(2.5, 8.5), 9.0, "first").is_empty(), "유령은 조준 불가")
	m.time = 2.5
	ok(not m.is_ghost(ghost) and not m._pick(Vector2(2.5, 8.5), 9.0, "first").is_empty(), "실체화되면 조준 가능")
	var late: Array = GData.wave_groups(25)
	ok(late.any(func(g): return g[1] == "boss"), "테마 마지막 웨이브에 보스")
	var row: Array = GMatch.new(["A", "B"]).enemies_data()
	ok(row.is_empty(), "빈 적 목록 직렬화")


func _rewards() -> void:
	var m := GMatch.new(["A", "B"])
	m.wave = GData.THEME_LEN
	m.players[0]["edits"] = 0
	m.hp = 80
	m._finish_wave()
	ok(m.phase == "reward" and int(m.players[0]["edits"]) == GData.EDITS_PER_PLAYER, "보스 뒤에는 보상 투표, 길 개조 기회 다시 지급")
	ok(m.apply(0, {"op": "build", "type": "gun", "x": 3, "y": 4}) != "", "보상 투표 중에는 건설 불가")
	m.apply(0, {"op": "vote", "v": "heal"})
	ok(m.phase == "reward", "한 명만 투표하면 그대로")
	m.apply(1, {"op": "vote", "v": "gold"})
	ok(m.phase == "prep" and m.hp == 90 and m.summary["reward"] == "heal", "동점이면 목록 앞쪽(본부 회복)")
	var g := GMatch.new(["A", "B"])
	g.phase = "reward"
	g.apply(0, {"op": "vote", "v": "up"})
	g.apply(1, {"op": "vote", "v": "up"})
	g.apply(0, {"op": "build", "type": "gun", "x": 3, "y": 4})
	var id: int = g.towers.keys()[0]
	var gold: int = g.players[0]["gold"]
	ok(g.apply(0, {"op": "upgrade", "id": id}) == "" and int(g.players[0]["gold"]) == gold and int(g.players[0]["free_up"]) == 0, "무료 강화 1회")
	var mag := GMatch.new(["A", "B"])
	mag.phase = "combat"
	var heavy := {"id": 7, "type": "heavy", "e": 0, "dist": 1.0, "hp": 100.0, "max": 100.0, "slow": 0.0, "slow_t": 0.0}
	mag.enemies = [heavy]
	var gun := GData.tower_stats("gun", 1, "")
	mag._hurt(heavy, gun, 0)
	var plain := 100.0 - float(heavy["hp"])
	heavy["hp"] = 100.0
	mag._hurt(heavy, GData.tower_stats("magnet", 1, ""), 0)
	heavy["hp"] = 100.0
	mag._hurt(heavy, gun, 0)
	ok(100.0 - float(heavy["hp"]) > plain, "자석탑이 방어력을 깎으면 기관포 피해 증가")


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
