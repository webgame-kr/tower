class_name GSession
extends RefCounted
## 온라인 한 판. 호스트가 판정하고 손님은 요청과 표시만 한다.
## transport 는 send_to / broadcast / poll 만 있으면 된다 (실제 연결 또는 테스트용 가짜 연결).

const MAX_SEATS := 4
const CHAT_MAX := 200
const CHAT_KEEP := 100
const RESEND := 2.0

var net
var is_host := false
var solo := false
var seat := -1
var my_name := ""
var my_token := ""
var my_tab := ""          # 같은 브라우저의 다른 탭을 다른 사람으로 구분한다
var state := "idle"      # idle | lobby | game | lost
var m: GMatch = null
var seats: Array = []    # {peer, token, name, online}
var chat: Array = []     # {seat, name, text, x?, y?}
var pings: Array = []    # {seat, kind, x, y, t}
var toasts: Array = []
var fx: Array = []
var outbox: Array = []   # 손님이 보내고 아직 승인받지 못한 요청 {id, c, t}
var host_away := false   # 방장이 다른 탭을 보면 브라우저가 게임을 멈춘다

var _host_peer := ""
var _clock := 0.0
var _acc := 0.0
var _send_acc := 0.0
var _sent_version := -1
var _out_fx: Array = []
var _nonce := ""
var _seq := 0
var _done: Dictionary = {}    # token -> {요청 id: 결과}
var _chat_times: Dictionary = {}
var _ping_times: Dictionary = {}
var _bot_wave := 0


func _init(transport = null, name := "플레이어", token := "") -> void:
	net = transport
	my_name = name
	my_token = token if token != "" else str(randi())
	_nonce = "%x" % randi()


func open_host(practice := false) -> void:
	is_host = true
	solo = practice
	seat = 0
	state = "lobby"
	seats = [{"peer": "", "token": my_token, "name": my_name, "online": true, "col": 0, "ready": false}]
	if practice:
		seats.append({"peer": "", "token": "bot", "name": "연습 동료", "online": true, "col": 1, "ready": true})
		seats[0]["ready"] = true
		start_match()


func open_client() -> void:
	is_host = false
	state = "lobby"


func start_match() -> String:
	if not is_host:
		return "방장만 시작할 수 있어요"
	if seats.size() < 2:
		return "친구가 들어와야 시작할 수 있어요"
	for st in seats:
		if not st["ready"]:
			return "모두 준비해야 시작할 수 있어요"
	_begin()
	return ""


func _begin() -> void:
	var names := []
	for s in seats:
		names.append(s["name"])
	m = GMatch.new(names)
	for i in seats.size():
		m.players[i]["online"] = seats[i]["online"]
		m.players[i]["col"] = seats[i]["col"]
	state = "game"
	_bot_wave = 0
	_sent_version = -1
	_system("경기 시작! 먼저 길과 포탑을 함께 정해 보세요.")
	_push_state()


## 내 이름·색·준비를 바꾼다 (로비)
func set_seat(d: Dictionary) -> void:
	if is_host:
		_apply_seat(0, d)
	elif _host_peer != "":
		var msg := d.duplicate()
		msg["t"] = "seat"
		net.send_to(_host_peer, msg)


func _apply_seat(s: int, d: Dictionary) -> void:
	if m != null or s < 0 or s >= seats.size():
		return
	if d.has("name"):
		var n := str(d["name"]).strip_edges().left(10)
		if n != "":
			seats[s]["name"] = n
	if d.has("col"):
		var c := int(d["col"])
		var taken := false
		for i in seats.size():
			if i != s and int(seats[i]["col"]) == c:
				taken = true
		if c >= 0 and c < 4 and not taken:
			seats[s]["col"] = c
	if d.has("ready"):
		seats[s]["ready"] = bool(d["ready"])
	if net and not solo:
		net.broadcast(_lobby_data())


func _free_col() -> int:
	for c in 4:
		var used := false
		for st in seats:
			if int(st["col"]) == c:
				used = true
		if not used:
			return c
	return 0


## 결과 화면에서 모두 로비로 돌아간다
func to_lobby() -> void:
	if not is_host:
		return
	m = null
	state = "lobby"
	for st in seats:
		st["ready"] = false
	if net and not solo:
		net.broadcast({"t": "tolobby"})
		net.broadcast(_lobby_data())


func tick(delta: float) -> void:
	_clock += delta
	if net:
		for item in net.poll():
			if is_host:
				_host_msg(str(item["from"]), item["data"])
			else:
				_client_msg(str(item["from"]), item["data"])
	if is_host:
		_host_tick(delta)
	else:
		for o in outbox:
			if _clock - float(o["t"]) >= RESEND and _host_peer != "":
				o["t"] = _clock
				net.send_to(_host_peer, {"t": "cmd", "id": o["id"], "c": o["c"]})
	for i in range(pings.size() - 1, -1, -1):
		if _clock - float(pings[i]["t"]) > 6.0:
			pings.remove_at(i)


func _host_tick(delta: float) -> void:
	if m == null:
		return
	if solo and m.phase == "prep":
		if _bot_wave != m.wave:
			_bot_wave = m.wave
			GBot.play_prep(m, 1)
		elif not m.players[1]["ready"]:
			m.apply(1, {"op": "ready", "v": true})
	_acc = minf(_acc + delta, GData.TICK * 8)
	while _acc >= GData.TICK:
		_acc -= GData.TICK
		m.step()
	for f in m.fx:
		fx.append(f)
		_out_fx.append(f)
	m.fx = []
	_send_acc += delta
	if m.version != _sent_version:
		_push_state()
	if _send_acc >= (0.25 if _any_relay() else 0.125):
		_send_acc = 0.0
		if net and not solo and (m.phase == "combat" or not _out_fx.is_empty()):
			net.broadcast({"t": "en", "r": m.enemies_data(), "f": _trim_fx()})
		_out_fx = []


func _any_relay() -> bool:
	if not net or not net.has_method("how"):
		return false
	for s in seats:
		if s["peer"] != "" and net.how(s["peer"]) == "relay":
			return true
	return false


## 연출은 빠져도 되므로 메시지가 커지지 않게 자른다
func _trim_fx() -> Array:
	var keep := []
	var shots := 0
	for f in _out_fx:
		if f["k"] == "shot":
			shots += 1
			if shots > 14:
				continue
		keep.append(f)
	return keep


func _push_state() -> void:
	if m == null:
		return
	_sent_version = m.version
	if net and not solo:
		net.broadcast({"t": "st", "d": m.to_data()})


func _lobby_data() -> Dictionary:
	var names := []
	for s in seats:
		names.append({"name": s["name"], "online": s["online"], "col": s["col"], "ready": s["ready"]})
	return {"t": "lobby", "seats": names}


func _host_msg(from: String, d: Dictionary) -> void:
	match str(d.get("t", "")):
		"hello":
			_hello(from, d)
		"seat":
			_apply_seat(_seat_of(from), d)
		"cmd":
			var s := _seat_of(from)
			if s < 0:
				return
			var id := str(d.get("id", ""))
			var token: String = seats[s]["token"]
			if not _done.has(token):
				_done[token] = {}
			var err: String
			if _done[token].has(id):      # 재전송: 다시 실행하지 않고 같은 결과만 돌려준다
				err = _done[token][id]
			else:
				var c = d.get("c", {})
				err = run(s, c if c is Dictionary else {})
				_done[token][id] = err
				if _done[token].size() > 256:
					_done[token].erase(_done[token].keys()[0])
			net.send_to(from, {"t": "ack", "id": id, "err": err})
		"_left":
			var s := _seat_of(from)
			if s >= 0:
				seats[s]["online"] = false
				seats[s]["peer"] = ""
				if m:
					m.set_online(s, false)
					_system("%s 님의 연결이 끊겼어요. 포탑은 계속 싸웁니다." % seats[s]["name"])
				else:
					seats.remove_at(s)
					for i in range(1, seats.size()):   # 자리가 당겨지면 각자 새 번호를 받는다
						net.send_to(seats[i]["peer"], {"t": "seatno", "seat": i})
				net.broadcast(_lobby_data())


func _hello(from: String, d: Dictionary) -> void:
	var token := str(d.get("token", ""))
	var name := str(d.get("name", "친구")).strip_edges().left(10)
	if name == "":
		name = "친구"
	var tab := str(d.get("tab", ""))
	var at := -1
	for i in range(1, seats.size()):   # 방장 자리(0)는 같은 브라우저의 다른 탭이라도 가져갈 수 없다
		if seats[i]["token"] != token:
			continue
		if str(seats[i].get("tab", "")) == tab:      # 새로고침·재접속
			at = i
			break
		if not seats[i]["online"] and at < 0:        # 탭을 닫았다가 다시 열었을 때
			at = i
	if at < 0:
		if m != null or seats.size() >= MAX_SEATS:
			net.send_to(from, {"t": "full", "why": "이미 시작했거나 자리가 없어요"})
			return
		seats.append({"peer": from, "token": token, "tab": tab, "name": name, "online": true, "col": _free_col(), "ready": false})
		at = seats.size() - 1
	else:
		seats[at]["tab"] = tab
		seats[at]["peer"] = from
		seats[at]["online"] = true
		if m:
			m.set_online(at, true)
			_system("%s 님이 돌아왔어요." % seats[at]["name"])
	net.send_to(from, {"t": "welcome", "seat": at, "chat": chat})
	net.broadcast(_lobby_data())
	if m:
		net.send_to(from, {"t": "st", "d": m.to_data()})
		net.send_to(from, {"t": "en", "r": m.enemies_data(), "f": []})


func _seat_of(peer: String) -> int:
	for i in seats.size():
		if seats[i]["peer"] == peer:
			return i
	return -1


## 호스트에서 요청 하나를 판정한다
func run(s: int, c: Dictionary) -> String:
	var op := str(c.get("op", ""))
	if op == "chat":
		return _chat(s, str(c.get("text", "")))
	if op == "ping":
		return _ping(s, c)
	if m == null:
		return "아직 경기가 시작되지 않았어요"
	return m.apply(s, c)


func _chat(s: int, raw: String) -> String:
	var text := raw.strip_edges()
	if text == "":
		return "빈 메시지예요"
	if text.length() > CHAT_MAX:
		return "메시지는 %d자까지예요" % CHAT_MAX
	var times: Array = _chat_times.get(s, [])
	times = times.filter(func(t): return _clock - float(t) < 4.0)
	if times.size() >= 4:
		return "너무 빨라요. %d초 뒤에 보내 주세요" % ceili(4.0 - (_clock - float(times[0])))
	times.append(_clock)
	_chat_times[s] = times
	_add_chat({"seat": s, "col": seats[s]["col"], "name": seats[s]["name"], "text": text})
	return ""


func _ping(s: int, c: Dictionary) -> String:
	var kind := str(c.get("kind", ""))
	if not GData.PING_KINDS.has(kind):
		return "없는 핑이에요"
	var x := float(c.get("x", -1))
	var y := float(c.get("y", -1))
	if x < 0 or y < 0 or x > GData.W or y > GData.H:
		return "맵 안을 골라 주세요"
	if _clock - float(_ping_times.get(s, -9.0)) < 1.0:
		return "핑은 1초에 한 번만 쓸 수 있어요"
	_ping_times[s] = _clock
	var row := {"seat": s, "kind": kind, "x": x, "y": y}
	_add_ping(row)
	if net and not solo:
		net.broadcast({"t": "ping", "p": row})
	_add_chat({"seat": s, "col": seats[s]["col"], "name": seats[s]["name"], "text": GData.PING_KINDS[kind], "x": x, "y": y})
	return ""


func _add_ping(row: Dictionary) -> void:
	var p := row.duplicate()
	p["t"] = _clock
	pings.append(p)


func _add_chat(row: Dictionary) -> void:
	chat.append(row)
	if chat.size() > CHAT_KEEP:
		chat.pop_front()
	if is_host and net and not solo:
		net.broadcast({"t": "chat", "m": row})


func _system(text: String) -> void:
	_add_chat({"seat": -1, "name": "알림", "text": text})


func place_name(x: float, y: float) -> String:
	var at := Vector2(x, y)
	if m:
		var best := 4.0
		var label := ""
		var points := [[GData.CASTLE.get_center(), "본부 옆"]]
		var theme: Dictionary = GData.THEMES[GData.theme_of(m.wave)]
		points.append([Vector2(GData.LANDMARK.position) + Vector2(GData.LANDMARK.size) * 0.5, "%s 옆" % theme["landmark"]])
		for e in m.board.paths.size():
			var p: Array = m.board.paths[e]
			points.append([Vector2(p[0]) + Vector2(0.5, 0.5), "%d번 입구 옆" % (e + 1)])
			var bend := 0
			for i in range(1, p.size() - 1):
				if p[i] - p[i - 1] != p[i + 1] - p[i]:
					points.append([Vector2(p[i]) + Vector2(0.5, 0.5), "%d번 길 굽이 %s" % [e + 1, "가나다라마바사아자차"[bend % 10]]])
					bend += 1
		for pt in points:
			var d := at.distance_to(Vector2(pt[0]))
			if d <= best:
				best = d
				label = pt[1]
		if label != "":
			return label
	var col := clampi(int(x / (GData.W / 4.0)), 0, 3)
	var row := clampi(int(y / (GData.H / 3.0)), 0, 2)
	return "%s%d 구역" % ["가나다라"[col], row + 1]


## 내 조작. 호스트는 바로 판정하고 손님은 요청을 보낸다.
func command(c: Dictionary) -> void:
	if is_host:
		var err := run(seat, c)
		if err != "":
			toasts.append(err)
		return
	_seq += 1
	var id := "%s-%d" % [_nonce, _seq]
	outbox.append({"id": id, "c": c, "t": _clock})
	if _host_peer != "":
		net.send_to(_host_peer, {"t": "cmd", "id": id, "c": c})


func rematch() -> void:
	if is_host:
		_begin()


func _client_msg(from: String, d: Dictionary) -> void:
	match str(d.get("t", "")):
		"_open":
			_host_peer = from
			net.send_to(from, {"t": "hello", "name": my_name, "token": my_token, "tab": my_tab})
		"_left":
			if from == _host_peer:
				state = "lost"
				_host_peer = ""
		"seatno":
			seat = int(d["seat"])
		"tolobby":
			m = null
			state = "lobby"
		"_away":
			host_away = bool(d.get("on", false))
		"full":
			state = "lost"
			toasts.append(str(d.get("why", "들어갈 수 없어요")))
		"welcome":
			seat = int(d["seat"])
			chat = d.get("chat", [])
			for row in chat:
				row["seat"] = int(row["seat"])
		"lobby":
			seats = []
			for s in d["seats"]:
				seats.append({"peer": "", "token": "", "name": str(s["name"]), "online": bool(s["online"]), "col": int(s["col"]), "ready": bool(s["ready"])})
		"st":
			if m == null:
				m = GMatch.new()
			m.load_data(d["d"])
			state = "game"
		"en":
			if m:
				m.load_enemies(d["r"])
				fx.append_array(d["f"])
		"ack":
			var id := str(d.get("id", ""))
			for i in outbox.size():
				if outbox[i]["id"] == id:
					outbox.remove_at(i)
					break
			if str(d.get("err", "")) != "":
				toasts.append(str(d["err"]))
		"chat":
			var row: Dictionary = d["m"]
			row["seat"] = int(row["seat"])
			chat.append(row)
			if chat.size() > CHAT_KEEP:
				chat.pop_front()
		"ping":
			var row: Dictionary = d["p"]
			row["seat"] = int(row["seat"])
			_add_ping(row)
