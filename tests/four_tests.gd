extends SceneTree
## 3~4인 규칙과 온라인 자리 관리를 별 모양 가짜 연결로 확인한다.


class Hub:
	extends RefCounted
	var boxes := {}

	func box(name_: String) -> Array:
		if not boxes.has(name_):
			boxes[name_] = []
		return boxes[name_]

	func deliver(from: String, to: String, msg: Dictionary) -> void:
		box(to).append({"from": from, "data": JSON.parse_string(JSON.stringify(msg))})


class Link:
	extends RefCounted
	var hub: Hub
	var me := ""
	var peers: Array = []

	func _init(h: Hub, name_: String) -> void:
		hub = h
		me = name_

	func send_to(to: String, msg: Dictionary) -> void:
		hub.deliver(me, to, msg)

	func broadcast(msg: Dictionary, _except := "") -> void:
		for p in peers:
			hub.deliver(me, p, msg)

	func poll() -> Array:
		var out: Array = hub.box(me).duplicate()
		hub.box(me).clear()
		return out


var fails := 0
var total := 0
var hub := Hub.new()
var host_link: Link
var host: GSession
var guests: Array = []


func ok(cond: bool, label: String) -> void:
	total += 1
	if not cond:
		fails += 1
		print("FAIL: ", label)


func pump(n := 6) -> void:
	for _i in n:
		host.tick(0.05)
		for g in guests:
			g.tick(0.05)


func join(peer: String, token: String, tab: String) -> GSession:
	var link := Link.new(hub, peer)
	link.peers = ["host"]
	if not host_link.peers.has(peer):
		host_link.peers.append(peer)
	var g := GSession.new(link, peer, token)
	g.my_tab = tab
	g.open_client()
	guests.append(g)
	hub.deliver("host", peer, {"t": "_open"})
	pump()
	return g


func leave(g: GSession) -> void:
	var peer: String = g.net.me
	guests.erase(g)
	host_link.peers.erase(peer)
	hub.deliver(peer, "host", {"t": "_left"})
	pump()


func _init() -> void:
	_rules()
	_online()
	_balance_shape()
	print("four %d/%d passed" % [total - fails, total])
	quit(1 if fails > 0 else 0)


func _rules() -> void:
	ok(GData.lanes_for(2) == 2 and GData.lanes_for(3) == 3 and GData.lanes_for(4) == 3, "인원별 입구 수")
	for n in [2, 3, 4]:
		var names := []
		for i in n:
			names.append("P%d" % i)
		var m := GMatch.new(names)
		ok(m.board.paths.size() == GData.lanes_for(n) and m.gate_dmg.size() == m.board.paths.size(), "%d인 입구와 기록" % n)
		for e in m.board.paths.size():
			ok(m.board.validate(e, m.board.paths[e], {}) == "", "%d인 %d번 길 유효" % [n, e + 1])
		var copy := GMatch.new()
		copy.load_data(JSON.parse_string(JSON.stringify(m.to_data())))
		ok(copy.board.paths == m.board.paths and copy.gate_dmg.size() == m.gate_dmg.size(), "%d인 상태 동기화" % n)
		var owners := []
		for w in n + 1:
			owners.append(m.road_owner)
			m._finish_wave()
		ok(owners[n] == owners[0] and _unique(owners.slice(0, n)) == n, "%d인 길 담당 순환" % n)
	var four := GMatch.new(["A", "B", "C", "D"])
	var spots := 0
	for i in four.board.paths[2].size():
		for side in [1, -1]:
			if four.board.reroute(2, i, "detour", side, {}).has("path"):
				spots += 1
	ok(spots >= 4, "3번 길에도 우회로 자리가 있음")
	for k in 4:
		ok(four.players[k]["gold"] == GData.START_GOLD, "개인 시작 골드 유지")
	four.apply(0, {"op": "ready"})
	four.apply(1, {"op": "ready"})
	four.apply(2, {"op": "ready"})
	ok(four.phase == "prep", "세 명만 준비하면 시작 안 함")
	four.set_online(3, false)
	ok(four.phase == "combat", "끊긴 네 번째는 준비 판정 제외")
	ok(four._queue.any(func(q): return int(q["e"]) == 2), "3번 입구로도 적이 나옴")


func _unique(a: Array) -> int:
	var seen := {}
	for v in a:
		seen[v] = true
	return seen.size()


func _online() -> void:
	host_link = Link.new(hub, "host")
	host = GSession.new(host_link, "방장", "t0")
	host.open_host()
	var a := join("a", "ta", "1")
	var b := join("b", "same-browser", "1")
	var c := join("c", "same-browser", "2")
	ok(a.seat == 1 and b.seat == 2 and c.seat == 3 and host.seats.size() == 4, "네 명 입장, 같은 브라우저의 다른 탭은 다른 자리")
	var fifth := join("e", "te", "1")
	ok(fifth.state == "lost", "다섯 번째는 입장 불가")
	guests.erase(fifth)
	host_link.peers.erase("e")
	var cols := {}
	for st in host.seats:
		cols[int(st["col"])] = true
	ok(cols.size() == 4, "네 명의 색이 모두 다름")
	leave(a)
	ok(host.seats.size() == 3 and b.seat == 1 and c.seat == 2, "로비에서 나가면 뒤 자리 번호가 당겨짐")
	b.command({"op": "chat", "text": "자리 확인"})
	pump()
	ok(int(host.chat[-1]["seat"]) == 1 and host.chat[-1]["name"] == "b", "당겨진 번호로 요청 처리")
	var d := join("d", "td", "1")
	ok(d.seat == 3 and host.seats.size() == 4, "빈자리에 다시 입장")
	ok(host.start_match() != "", "전원 준비 전 시작 불가")
	host.set_seat({"ready": true})
	for g in guests:
		g.set_seat({"ready": true})
	pump()
	ok(host.start_match() == "", "4인 시작")
	pump()
	for g in guests:
		ok(g.state == "game" and g.m.board.paths.size() == 3 and g.m.players.size() == 4, "손님에게 4인 경기 전달")
	var spots := [Vector2i(1, 6), Vector2i(23, 6), Vector2i(15, 15)]
	for i in guests.size():
		guests[i].command({"op": "build", "type": "gun", "x": spots[i].x, "y": spots[i].y})
	pump()
	ok(host.m.towers.size() == 3, "세 손님의 건설 반영")
	var owners := {}
	for id in host.m.towers:
		owners[int(host.m.towers[id]["owner"])] = true
	ok(owners.has(1) and owners.has(2) and owners.has(3), "포탑 소유자가 각자")
	ok(guests[0].m.players[3]["gold"] == GData.START_GOLD - 100, "다른 손님의 골드도 동기화")
	var token_gold: int = host.m.players[2]["gold"]
	leave(c)
	ok(host.m.players[2]["online"] == false and host.seats.size() == 4, "경기 중 끊겨도 자리 유지")
	var back := join("c2", "same-browser", "2")
	ok(back.seat == 2 and back.m != null and back.m.players[2]["gold"] == token_gold, "경기 중 재접속으로 자기 자리 복구")
	ok(host.m.players[2]["online"] == true and host.m.players[1]["online"] == true, "다른 자리는 그대로")
	for g in guests:
		g.command({"op": "ready", "v": true})
	host.command({"op": "ready", "v": true})
	pump(30)
	ok(host.m.phase == "combat" and guests[0].m.enemies.size() > 0, "4인 전투 시작과 적 동기화")


func _balance_shape() -> void:
	var two: Array = GData.wave_groups(3, 2)
	var four: Array = GData.wave_groups(3, 4)
	ok(_count(four) > _count(two), "인원이 늘면 적 물량 증가")
	ok(GData.wave_hp(8, 4) > GData.wave_hp(8, 2), "인원이 늘면 적 체력 증가")
	ok(GData.wave_groups(3) == two, "2인 웨이브는 그대로")
	var boss := GData.wave_groups(5, 4).filter(func(g): return g[1] == "boss")
	ok(boss.size() == 1 and int(boss[0][2]) == 1, "보스는 한 마리 유지")


func _count(groups: Array) -> int:
	var n := 0
	for g in groups:
		n += int(g[2])
	return n
