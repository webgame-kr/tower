extends SceneTree
## 호스트와 손님을 가짜 연결로 이어 온라인 규칙을 확인한다.


class Wire:
	extends RefCounted
	var me := ""
	var other: Wire
	var inbox: Array = []
	var drop_next := false

	func send_to(_to: String, msg: Dictionary) -> void:
		if drop_next:
			drop_next = false
			return
		other.inbox.append({"from": me, "data": JSON.parse_string(JSON.stringify(msg))})

	func broadcast(msg: Dictionary, _except := "") -> void:
		send_to("", msg)

	func poll() -> Array:
		var out := inbox
		inbox = []
		return out


var fails := 0
var total := 0


func ok(cond: bool, label: String) -> void:
	total += 1
	if not cond:
		fails += 1
		print("FAIL: ", label)


func pump(h: GSession, c: GSession, n := 6) -> void:
	for _i in n:
		h.tick(0.05)
		c.tick(0.05)


func _init() -> void:
	var a := Wire.new()
	var b := Wire.new()
	a.me = "host"
	b.me = "guest"
	a.other = b
	b.other = a
	var h := GSession.new(a, "방장", "t-host")
	var c := GSession.new(b, "친구", "t-guest")
	h.open_host()
	c.open_client()
	b.inbox.append({"from": "host", "data": {"t": "_open"}})
	pump(h, c)
	ok(c.seat == 1 and h.seats.size() == 2, "손님 입장")
	ok(h.start_match() != "", "모두 준비 전에는 시작 불가")
	c.set_seat({"col": 0})
	pump(h, c)
	ok(int(h.seats[1]["col"]) == 1, "이미 쓰인 색은 고를 수 없음")
	c.set_seat({"col": 3, "name": "새이름", "ready": true})
	h.set_seat({"ready": true})
	pump(h, c)
	ok(int(c.seats[1]["col"]) == 3 and c.seats[1]["name"] == "새이름", "로비 색·이름 반영")
	ok(h.start_match() == "", "경기 시작")
	pump(h, c)
	ok(c.state == "game" and c.m != null, "손님에게 경기 전달")

	c.command({"op": "build", "type": "gun", "x": 3, "y": 4})
	pump(h, c)
	ok(h.m.towers.size() == 1 and c.m.towers.size() == 1, "손님 건설이 양쪽에 반영")
	ok(h.m.players[1]["gold"] == GData.START_GOLD - 100 and c.m.players[1]["gold"] == GData.START_GOLD - 100, "골드는 호스트 기준")

	# 승인 응답이 사라져 재전송돼도 두 번 결제되면 안 된다
	a.drop_next = true
	c.command({"op": "build", "type": "gun", "x": 4, "y": 4})
	for _i in 60:
		h.tick(0.05)
		c.tick(0.05)
		a.drop_next = false
	ok(h.m.towers.size() == 2, "재전송해도 포탑 하나만 건설")
	ok(h.m.players[1]["gold"] == GData.START_GOLD - 200, "재전송해도 한 번만 결제")
	ok(c.outbox.is_empty(), "재전송 후 승인 수신")

	c.command({"op": "chat", "text": "<b>안녕</b>"})
	pump(h, c)
	ok(h.chat[-1]["text"] == "<b>안녕</b>" and c.chat[-1]["text"] == "<b>안녕</b>", "채팅은 글자 그대로 전달")
	ok(h.run(1, {"op": "chat", "text": "가".repeat(201)}) != "", "201자 거부")
	var limited := false
	for _i in 8:
		if h.run(1, {"op": "chat", "text": "도배"}) != "":
			limited = true
	ok(limited, "연속 전송 제한")

	c.command({"op": "ping", "kind": "danger", "x": 3.5, "y": 8.5})
	pump(h, c)
	ok(c.pings.size() == 1 and h.pings.size() == 1, "핑 양쪽 표시")
	ok(str(c.chat[-1]["text"]).contains("1번 입구 길"), "핑이 위치와 함께 채팅에 기록")

	# 손님이 끊겼다가 돌아오면 자리와 골드를 되찾는다
	var gold: int = h.m.players[1]["gold"]
	a.inbox.append({"from": "guest", "data": {"t": "_left"}})
	pump(h, c)
	ok(h.m.players[1]["online"] == false, "끊김 표시")
	ok(h.m.towers.size() == 2, "끊겨도 포탑 유지")
	var c2 := GSession.new(b, "친구", "t-guest")
	c2.open_client()
	b.inbox.append({"from": "host", "data": {"t": "_open"}})
	pump(h, c2)
	ok(c2.seat == 1 and c2.m != null and c2.m.players[1]["gold"] == gold, "재접속으로 자리와 골드 복구")
	ok(c2.chat.size() > 0, "재접속으로 채팅 복구")
	ok(h.m.players[1]["online"] == true, "재접속 표시")

	c2.command({"op": "ready", "v": true})
	h.command({"op": "ready", "v": true})
	pump(h, c2, 60)
	ok(h.m.phase == "combat" and c2.m.phase == "combat", "전원 준비로 전투 시작")
	ok(c2.m.enemies.size() > 0, "손님에게 적 표시")

	h.m.phase = "over"
	h.to_lobby()
	pump(h, c2)
	ok(h.m == null and c2.m == null and c2.state == "lobby", "결과 화면에서 로비로 복귀")

	var a2 := Wire.new()
	var b2 := Wire.new()
	a2.me = "host"
	b2.me = "guest"
	a2.other = b2
	b2.other = a2
	var h2 := GSession.new(a2, "방장", "same")
	var c3 := GSession.new(b2, "같은 브라우저", "same")
	h2.open_host()
	c3.open_client()
	b2.inbox.append({"from": "host", "data": {"t": "_open"}})
	pump(h2, c3)
	ok(c3.seat == 1 and h2.seats.size() == 2 and h2.seats[0]["peer"] == "", "같은 브라우저 손님이 방장 자리를 뺏지 않음")

	var solo := GSession.new(null, "나", "me")
	solo.open_host(true)
	for _i in 10:
		solo.tick(0.05)
	ok(solo.m.players[1]["ready"] == true and solo.m.towers.size() > 0, "연습 동료가 준비")
	solo.command({"op": "ready", "v": true})
	ok(solo.m.phase == "combat", "연습 모드 전투 시작")

	print("net %d/%d passed" % [total - fails, total])
	quit(1 if fails > 0 else 0)
