class_name GBot
extends RefCounted
## 혼자 연습할 때의 동료이자 밸런스 시뮬레이션용 플레이어.


## 준비 단계에서 할 일을 모두 하고 준비 완료한다.
static func play_prep(m: GMatch, seat: int, use_roads := true) -> void:
	_spend(m, seat)      # 포탑을 먼저 놓고, 그 포탑의 사거리 안으로 길을 꺾는다
	if use_roads and m.road_owner == seat:
		while m.edits_left > 0:
			var e := best_road(m)
			if e.is_empty():
				break
			if m.apply(seat, {"op": "edit", "e": e["e"], "i": e["i"], "kind": e["kind"], "side": e["side"]}) != "":
				break
	m.apply(seat, {"op": "ready", "v": true})


static func _spend(m: GMatch, seat: int) -> void:
	for _guard in 12:
		var gold: int = m.players[seat]["gold"]
		var mine := []
		for id in m.towers:
			if int(m.towers[id]["owner"]) == seat:
				mine.append(m.towers[id])
		var has_cold := mine.any(func(t): return t["type"] == "cold")
		var want := "cold" if mine.size() >= 2 and not has_cold else ("cannon" if mine.size() % 2 == 1 else "gun")
		if mine.size() >= 4:
			var up := _cheapest_upgrade(mine)
			if not up.is_empty() and gold >= int(up["cost"]):
				if m.apply(seat, {"op": "upgrade", "id": up["id"], "branch": "b" if up["type"] != "cold" else "a"}) == "":
					continue
		if gold < int(GData.TOWERS[want]["cost"]):
			return
		var c := best_cell(m, want, seat)
		if c.x < 0 or m.apply(seat, {"op": "build", "type": want, "x": c.x, "y": c.y}) != "":
			return


static func _cheapest_upgrade(mine: Array) -> Dictionary:
	var best := {}
	for t in mine:
		if int(t["lv"]) >= 3:
			continue
		var cost: int = GData.TOWERS[t["type"]]["up"][int(t["lv"]) - 1]
		if best.is_empty() or cost < int(best["cost"]):
			best = {"id": t["id"], "type": t["type"], "cost": cost}
	return best


## 자기 입구 쪽을 맡는다 (좌석 번호 = 입구 번호)
static func best_cell(m: GMatch, type: String, seat: int) -> Vector2i:
	var radius: float = GData.tower_stats(type, 1, "")["range"]
	var cells := m.tower_cells()
	var lane: Array = [m.board.paths[seat % m.board.paths.size()]]
	var best := Vector2i(-1, -1)
	var best_n := 0
	for y in GData.H:
		for x in GData.W:
			var c := Vector2i(x, y)
			if m.board.can_build(c, cells) != "":
				continue
			var n := Board.coverage(c, radius, lane)
			if n > best_n:
				best_n = n
				best = c
	return best


static func best_road(m: GMatch) -> Dictionary:
	var cells := m.tower_cells()
	var best := {}
	var best_n := -1
	for e in m.board.paths.size():
		for i in m.board.paths[e].size():
			for kind in ["detour", "bend"]:
				for side in [1, -1]:
					var r := m.board.reroute(e, i, kind, side, cells)
					if r.has("err"):
						continue
					var trial: Array = m.board.paths.duplicate()
					trial[e] = r["path"]
					var n: int = r["path"].size() * 2
					for id in m.towers:
						var t: Dictionary = m.towers[id]
						var s := GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))
						n += Board.coverage(Vector2i(int(t["x"]), int(t["y"])), float(s["range"]), trial)
					if n > best_n:
						best_n = n
						best = {"e": e, "i": i, "kind": kind, "side": side}
	return best
