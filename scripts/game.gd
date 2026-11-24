extends Control
## 화면과 입력. UI 시안(UI DNA)의 1280×720 좌표를 그대로 쓰고, 지도는 화면 전체에 깐다.
## 규칙은 GMatch, 온라인은 GSession 이 맡는다.

const NetScript := preload("res://scripts/net.gd")
const NOTO := preload("res://fonts/NotoSansKR-Hangul.ttf")   # (예전 글꼴, 지금은 쓰지 않음)
const MONO := preload("res://fonts/DMMono-Medium.ttf")
const GAL7 := preload("res://fonts/Galmuri7.ttf")      # 도트 글꼴 (OFL): 원본 크기 x2 로만 쓴다
const GAL9 := preload("res://fonts/Galmuri9.ttf")
const GAL11 := preload("res://fonts/Galmuri11.ttf")
const GAL11B := preload("res://fonts/Galmuri11-Bold.ttf")
const GAL14 := preload("res://fonts/Galmuri14.ttf")
const GALM11 := preload("res://fonts/GalmuriMono11.ttf")
## 글자 스타일 5개 (원본 x2): 이 밖의 크기는 쓰지 않는다
enum T { KEY, LABEL, BODY, STRONG, BIG }
const TS := {
	T.KEY: [GAL7, 16, 20],      # 글꼴, 크기, 줄 높이 — 숫자·영문 키만 (한글 금지)
	T.LABEL: [GAL9, 20, 24],    # 패널 제목, 라벨, 보조 설명
	T.BODY: [GAL11, 24, 28],    # 채팅, 버튼 글자, 일반 문장
	T.STRONG: [GAL11B, 24, 28], # 이름, 값, 강조
	T.BIG: [GAL14, 30, 36],     # 본부 HP, 웨이브 번호, 골드, 큰 버튼, 화면 제목
}
const TEX_UI := preload("res://art/ui.png")
const TEX_TOWERS := preload("res://art/towers.png")
const TEX_ENEMIES := preload("res://art/enemies.png")
const TEX_ICONS := preload("res://art/icons.png")

const STAGE := Vector2(1280, 720)
const FRAME := Rect2(0, 0, 1280, 720)     # 지형이 깔리는 화면 전체
var MAP := Vector2(262, 110)              # 플레이 칸의 시작점 (맵 배치에 따라 GData 가 정한다)
var CELL := 36.0
const MINI_VIEW := Rect2(190, 60, 900, 600)   # 작은 지도에 보여 줄 범위
const TRANSITION := 2.5

## UI DNA 색 토큰 (생성기 출력값)
const BG := Color("282b30")
const PANEL := Color("454a4f")
const PANEL_HI := Color("50555a")
const PANEL_LO := Color("3d4247")
const WELL := Color("1c1e22")
const LINE := Color("405068")
const INK := Color("eff5ff")
const SUB := Color("9aaabe")
const AMBER := Color("f4bb60")
const AMBER_HI := Color("f6c679")
const AMBER_INK := Color("2a2214")
const DANGER := Color("f47679")
const WARN := Color("e5be68")
const LAMP := Color("FF4A3A")
const ICE := Color("9FD8E6")
const FIRE := Color("F07A2A")
const GRASS := Color("6E8550")
const GRASS2 := Color("67804A")
const TUFT := Color("58703F")
const ROAD := Color("A08A6A")
const ROAD_EDGE := Color("4E4232")
const OK_GREEN := Color("64d4a3")
const CFG_DEFAULT := {"font": 100, "fx_low": false, "thick": false, "shake": 30, "pattern": true, "dmg": true}

const OWNER := [Color("E0533D"), Color("3D6FD1"), Color("E9B935"), Color("38A672")]
const OWNER_TEXT := [Color("FF8A78"), Color("7FA6F0"), Color("E9B935"), Color("5FCB97")]
const MARK := ["●", "▲", "■", "◆"]
const TOWER_ROW := {"gun": 0, "cannon": 1, "cold": 2, "magnet": 3, "oil": 4, "flame": 5, "shock": 6, "sniper": 7, "signal": 8, "spike": 9}
const TW := Vector2(34, 50)                # 포탑 그림 한 칸 (픽셀): 아래 19줄이 그 칸
const EW := Vector2(44, 40)                # 적 그림 한 칸 (픽셀), 발은 (22, 38)
const TILE := 19.0                         # 픽셀 아트 타일 (화면 칸 = 19 x 배율)
const PRIO := {"first": "앞선", "strong": "강한", "near": "가까운"}
const PING_ORDER := ["look", "danger", "build", "road", "mine"]
const PING_COL := [Color("3F9BD6"), Color("D2452F"), Color("E9B935"), Color("C9A15F"), Color("38A672")]

var net: Node
var s: GSession
## 시안의 글꼴 쌓기: 본문은 Noto Sans KR, 라벨·숫자는 'DM Mono', 'Noto Sans KR'
var REG: Font
var BOLD: Font
var web := false
var room := ""

var _off := Vector2.ZERO
var mode := ""            # build:gun | road:detour | move:id | ability | ping:look
var selected := -1
var hover := Vector2(-1, -1)
var hover_edit := {}
var chat_open := true
var _screen := "menu"
var _fxs: Array = []
var _disp := {}
var _shake := 0.0
var _flash := Vector2(-1, -1)
var _flash_t := 0.0
var _toast := ""
var _toast_t := 0.0
var _chat_key := ""
var _name_sent := ""
var _name_t := 0.0
var _tick := 0.0
var _menu_open := false
var _theme := 0           # 지금 그리는 테마
var _theme_goal := 0
var _trans_t := 0.0
var _notice_t := 0.0
var _theme_tex := {}
var fx_low := false
var cfg := CFG_DEFAULT.duplicate()
var _cfg_draft := {}
var _paused := false
var _panel := ""           # "" | settings | help | mute
var _tab := 3
var _muted := {}
var _chat_typing := false
var _type_t := 0.0
var _code_open := false
var _menu_focus := 0
var _record := {}
var _record_done := false
var _flip := 0
var _trail := {}
var _face := {}
var _wheel := {}              # 핑 휠: {at(격자), from(화면)}
var _kit_sent := false
const QUICK := ["여기 막아 줘", "골드 좀 나눠 줘", "길 늘려 줘", "준비 됐어"]               # 적이 바라보는 쪽 (좌우 반전)             # 길 그리기 중: {e, i, cells[], j}
var _kit_open := false
var _kit_pick: Array = []     # 카드 띠에서 고른 것
var _pick_wave := 0           # 카드 띠를 자동으로 연 웨이브
var pick_btns: Array = []
var lock_btns: Array = []
var pick_go: Button
var pick_reroll: Button
var _summary_wave := 0
var _summary_t := 0.0
var _tut := -1               # 첫 판 안내 단계 (-1 = 끝)
var reward_btns := {}
var tut_skip: Button

var stage: Control
var menu: Control
var lobby: Control
var hud: Control
var result: Control
var chat_box: RichTextLabel
var chat_block: Control
var chat_toggle: Button

var host_btn: Button
var join_btn: Button
var solo_btn: Button
var start_btn: Button
var ready_lobby: Button
var col_btns: Array = []
var build_btns := {}
var road_btns := {}
var slot_btns: Array = []
var kit_btns := {}
var lobby_kit := {}
var diff_btns := {}
var fix_btn
var confirm_btn: Button
var accept_btn: Button
var title_btn: Button
var code_cancel: Button
var _code_len := 0
const FONT_STEPS := [90, 100, 120, 150]
var reject_btn: Button
var quick_btn: Button
var _quick_open := false
var _newrx := ""               # 처음 나온 반응 알림
var _newrx_t := 0.0
# ── 카메라 (각자의 것, 네트워크로 보내지 않음) ──
var _zoom := 2                 # 1 = 원본 x1 (맵 전체), 2 = x2 (기본)
var _cam := Vector2(10, 6)     # 화면 가운데에 오는 칸 좌표
var _overview_t := 0.0         # 준비 시작 때 x1 로 잠깐 보여 주기
var _last_phase := ""
var _pan := {}                 # 끌어서 이동 {from, cam, button, moved}
const VIEW_C := Vector2(620, 364)      # 지도 화면의 가운데 (왼쪽·오른쪽 열 사이)
const CAM_SPEED := 12.0
var _branch_pick := false      # MK-3 갈래 카드를 펼쳤는지
var _drag := {}                # 포탑 끌어 옮기기 {id, from}
var _chat_seen := 0            # 접힌 채팅: 마지막으로 본 메시지 수
var _chat_flash := 0.0         # 접힌 채팅 한 줄이 남은 시간
var _dismissed := {}      # 거절한 동료 길 제안 (자리 -> 길)
var _dither: ImageTexture
var cancel_btn: Button
var ability_btn: Button
var ping_btns: Array = []
var ready_btn: Button
var prio_btns := {}
var up_btn: Button
var a_btn: Button
var b_btn: Button
var move_btn: Button
var sell_btn: Button
var menu_btn: Button
var quit_btn: Button
var fx_btn: Button
var retry_btn: Button
var back_btn: Button
var pause: Control
var pause_block: Control
var pause_btns := {}
var set_tabs: Array = []
var font_btns: Array = []
var toggle_btns := {}
var shake_btn: Button
var mute_btns: Array = []
var cfg_btns := {}
var menu_items: Array = []
var code_go: Button
var speed_btns: Array = []
var call_btn: Button
var _none := StyleBoxEmpty.new()
var _ui_rects = {}
const OUTLINE := Color("0E0D0C")       # 외곽선은 이 색 하나


func _init() -> void:
	REG = GAL11
	BOLD = GAL11B


## 예전 크기(px) → 도트 글꼴과 화면 크기. 원본의 정확히 2배만 쓴다.
func _style_font(st: int) -> Array:
	var row: Array = TS[st]
	if st != T.KEY and int(cfg.get("font", 100)) > 100 and st < T.BIG:      # 글자 크게: 한 단계 위
		return TS[st + 1 if st != T.BODY else T.BIG]
	return row


func _sz(text: String, st: int) -> Vector2:
	var f: Array = _style_font(st)
	return Vector2((f[0] as Font).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(f[1])).x, float(f[2]))


func _noto(weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = NOTO
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


func _ready() -> void:
	net = NetScript.new()
	add_child(net)
	web = OS.has_feature("web") and net.available
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST      # 모든 것이 원본 640x360 의 정수 2배
	_ui_rects = JSON.parse_string(FileAccess.get_file_as_string("res://art/ui.json"))
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = STAGE
	add_child(stage)
	menu = _layer()
	lobby = _layer()
	hud = _layer()
	result = _layer()
	_build_chat()
	_build_menu()
	_build_lobby()
	_build_hud()
	_build_result()
	pause = _layer()
	_build_pause()
	_load_cfg()
	if web:
		room = net.room_param()
	get_viewport().size_changed.connect(_place)
	_show("menu")
	_place.call_deferred()


func _load_cfg() -> void:
	if not web:
		return
	var ui = JavaScriptBridge.get_interface("GilUI")
	var raw := str(ui.load_key("cfg"))
	var saved = JSON.parse_string(raw) if raw.begins_with("{") else null
	if saved is Dictionary:
		for k in CFG_DEFAULT:
			if saved.has(k):
				cfg[k] = saved[k]
	var raw_rec := str(ui.load_key("record"))
	var rec = JSON.parse_string(raw_rec) if raw_rec.begins_with("{") else null
	if rec is Dictionary:
		_record = rec
	fx_low = bool(cfg["fx_low"])


func _save_cfg() -> void:
	fx_low = bool(cfg["fx_low"])
	_chat_key = ""
	chat_box.add_theme_font_override("normal_font", GAL11 if float(cfg["font"]) <= 100.0 else GAL14)
	chat_box.add_theme_font_size_override("normal_font_size", 24 if float(cfg["font"]) <= 100.0 else 30)
	if web:
		JavaScriptBridge.get_interface("GilUI").save_key("cfg", JSON.stringify(cfg))


func _layer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = STAGE
	stage.add_child(c)
	return c


# ── 버튼 ──

func _box(fill: Color, edge: Color, radius := 3, width := 1) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = edge
	b.set_border_width_all(width)
	b.set_corner_radius_all(0)
	b.corner_radius_top_left = radius + 2
	b.corner_radius_bottom_right = radius + 2
	b.corner_detail = 1
	b.set_content_margin_all(3)
	return b


func _btn(parent: Control, r: Rect2, text: String, cb: Callable, kind := "sec", st := T.BODY) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.position = r.position
	b.size = r.size
	b.clip_text = false
	var f: Array = _style_font(st)
	b.add_theme_font_override("font", f[0])
	b.add_theme_font_size_override("font_size", f[1])
	b.pressed.connect(cb)
	_style(b, kind)
	parent.add_child(b)
	return b


func _style(b: Button, kind: String) -> void:
	if b.get_meta("kind", "") == kind:
		return
	b.set_meta("kind", kind)
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(k, _none)
	var ink := AMBER_INK if kind == "pri" else (Color("FFE9E2") if kind == "danger" else INK)
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink)
	b.add_theme_color_override("font_pressed_color", ink)
	b.add_theme_color_override("font_hover_pressed_color", ink)
	b.add_theme_color_override("font_focus_color", ink)
	b.add_theme_color_override("font_disabled_color", Color(SUB, 0.55))


func _cut(r: Rect2, c: float) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(c, 0), Vector2(r.end.x, r.position.y), r.end - Vector2(0, c), r.end - Vector2(c, 0),
		Vector2(r.position.x, r.end.y), r.position + Vector2(0, c)])


## 금속 판: 위 하이라이트, 아래 음영, 7px 절단 모서리
## 금속 판 → 도트 9조각 (빛은 왼쪽 위, 외곽선 #0E0D0C)
func _metal(r: Rect2, top: Color, bottom: Color, edge := LINE, c := 7.0) -> void:
	var name := "panel_steel"
	if top.r > 0.8 and top.g > 0.6:
		name = "panel_amber"
	elif top.get_luminance() < 0.2:
		name = "panel_dark"
	_nine(r, name)
	if edge == AMBER or edge == DANGER or edge == OK_GREEN:
		_prect(r.grow(-2), edge, false, 2.0)


func _nine(r: Rect2, name: String, tint := Color.WHITE) -> void:
	var info = _ui_rects.get(name)
	if info == null:
		_prect(r, PANEL)
		return
	var src := Rect2(info["rect"][0], info["rect"][1], info["rect"][2], info["rect"][3])
	var m := float(info["margin"])
	r = Rect2(_ev(r.position), _ev(r.size))
	if m <= 0.0:
		draw_texture_rect_region(TEX_UI, r, src, tint)
		return
	m = minf(m, minf(r.size.x, r.size.y) * 0.5)
	var xs := [r.position.x, r.position.x + m, r.end.x - m, r.end.x]
	var ys := [r.position.y, r.position.y + m, r.end.y - m, r.end.y]
	var us := [src.position.x, src.position.x + m, src.end.x - m, src.end.x]
	var vs := [src.position.y, src.position.y + m, src.end.y - m, src.end.y]
	for j in 3:
		for i in 3:
			var d := Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j])
			if d.size.x <= 0 or d.size.y <= 0:
				continue
			draw_texture_rect_region(TEX_UI, d, Rect2(us[i], vs[j], us[i + 1] - us[i], vs[j + 1] - vs[j]), tint)


func _plate(b: Button) -> void:
	var kind: String = b.get_meta("kind", "sec")
	if kind == "clear" or not b.is_visible_in_tree():
		return
	var r := Rect2(b.position, b.size)
	var parent := b.get_parent()
	while parent != stage and parent != null:
		r.position += parent.position
		parent = parent.get_parent()
	var mode_ := b.get_draw_mode()
	var down := mode_ == BaseButton.DRAW_PRESSED or mode_ == BaseButton.DRAW_HOVER_PRESSED
	var hot := mode_ == BaseButton.DRAW_HOVER or mode_ == BaseButton.DRAW_HOVER_PRESSED
	if b.disabled:
		_nine(r, "btn_disabled")
		return
	if kind == "danger":
		_prect(r, OUTLINE)
		_prect(r.grow(-2), Color("A8382A") if down else Color("C0412F"))
		_prect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 2)), Color("E0654F"))
		_prect(Rect2(r.position + Vector2(2, r.size.y - 6), Vector2(r.size.x - 4, 4)), Color("7A2418"))
		return
	if kind == "pri":
		_nine(r, "btn_amber_pressed" if down else "btn_amber")
	elif b.toggle_mode and b.button_pressed:
		_nine(r, "btn_hover")
	else:
		_nine(r, "btn_pressed" if down else ("btn_hover" if hot else "btn_normal"))


func _draw_plates(parent: Control) -> void:
	if not parent.is_visible_in_tree():
		return
	for b in parent.get_children():
		if b is Button:
			_plate(b)


# ── 화면 구성 ──

func _build_chat() -> void:
	chat_block = Control.new()
	chat_block.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(chat_block)
	chat_box = RichTextLabel.new()
	chat_box.bbcode_enabled = false      # 사용자 입력이 서식으로 해석되지 않게
	chat_box.scroll_following = true
	chat_box.add_theme_font_override("normal_font", GAL11)
	chat_box.add_theme_font_size_override("normal_font_size", 24)
	chat_box.add_theme_color_override("default_color", INK)
	chat_box.add_theme_constant_override("line_separation", 3)
	chat_box.meta_clicked.connect(_on_chat_link)
	stage.add_child(chat_box)
	chat_toggle = _btn(stage, Rect2(256, 456, 52, 18), "", _on_chat_toggle, "clear", T.LABEL)
	chat_toggle.add_theme_color_override("font_color", SUB)


func _build_menu() -> void:
	var rows := [["방 만들기", _on_host, "sec"], ["코드로 참가", _on_code, "sec"], ["혼자 연습 · 봇 동료", _on_solo, "sec"],
		["이어서 하기 · 지원 예정", _noop, "sec"], ["설정", _open_settings, "sec"]]
	for i in rows.size():
		var b := _btn(menu, Rect2(34, 266 + i * 56, 308, 44), str(rows[i][0]), rows[i][1], str(rows[i][2]), T.BODY)
		menu_items.append(b)
	menu_items[3].disabled = true
	host_btn = menu_items[0]
	solo_btn = menu_items[2]
	join_btn = _btn(menu, Rect2(34, 266, 308, 44), "초대받은 방 입장", _on_join, "pri", T.BODY)
	code_go = _btn(menu, Rect2(612, 432, 266, 44), "참가    ", _on_code_go, "pri", T.BODY)
	code_cancel = _btn(menu, Rect2(400, 432, 198, 44), "취소", _on_code, "sec", T.BODY)


func _build_lobby() -> void:
	_btn(lobby, Rect2(16, 110, 140, 38), "코드 복사", _on_copy_code, "sec", T.LABEL)
	_btn(lobby, Rect2(162, 110, 136, 38), "초대 링크", _on_copy_link, "sec", T.LABEL)
	for c in 4:
		col_btns.append(_btn(lobby, Rect2(), "", _on_color.bind(c), "clear"))
	ready_lobby = _btn(lobby, Rect2(), "준비 완료", _on_lobby_ready, "pri", T.LABEL)
	for k in GData.TOWER_ORDER:
		lobby_kit[k] = _btn(lobby, Rect2(), "", _on_lobby_kit.bind(k), "clear")
		lobby_kit[k].tooltip_text = "%s · %s" % [GData.TOWERS[k]["name"], GData.TOWERS[k]["role"]]
	for k in GData.DIFFICULTY:
		diff_btns[k] = _btn(lobby, Rect2(), str(GData.DIFFICULTY[k][2]), _on_diff.bind(k), "sec", T.BODY)
		diff_btns[k].toggle_mode = true
	_btn(lobby, Rect2(638, 600, 176, 56), "나가기     ", _on_leave, "sec", T.BODY)
	start_btn = _btn(lobby, Rect2(828, 560, 442, 96), "", _on_start, "pri", T.BODY)


func _build_hud() -> void:
	menu_btn = _btn(hud, Rect2(1220, 14, 44, 44), "II", _toggle_pause, "sec", T.BODY)
	quit_btn = _btn(hud, Rect2(-100, -100, 1, 1), "", _noop, "clear")
	fx_btn = _btn(hud, Rect2(-100, -100, 1, 1), "", _noop, "clear")
	quit_btn.visible = false
	fx_btn.visible = false
	for i in GData.KIT_SIZE:
		var b := _btn(hud, Rect2(347 + i * 75, 634, 70, 72), "", _on_slot.bind(i), "clear")
		b.tooltip_text = "단축키 %d" % (i + 1)
		slot_btns.append(b)
	var kb := _btn(hud, Rect2(724, 634, 70, 72), "", _toggle_kit, "clear")
	kb.tooltip_text = "포탑 카드 고르기 (K) · 준비 중"
	build_btns["kit"] = kb
	for i in GData.HAND_SIZE + 1:
		pick_btns.append(_btn(hud, Rect2(), "", _on_kit_pick.bind(i), "clear"))
	pick_go = _btn(hud, Rect2(), "", _on_pick_go, "pri", T.BODY)
	pick_reroll = _btn(hud, Rect2(), "", _on_reroll, "sec", T.LABEL)
	for i in GData.KIT_SIZE:
		var lb := _btn(hud, Rect2(), "", _on_lock.bind(i), "clear")
		lb.tooltip_text = "잠금: 다음 웨이브에도 이 카드를 남겨요"
		lock_btns.append(lb)
	for k in GData.REWARDS:
		reward_btns[k] = _btn(hud, Rect2(), "", _on_vote.bind(k), "clear", T.BODY)
		reward_btns[k].toggle_mode = true
	tut_skip = _btn(hud, Rect2(), "", _skip_tutorial, "clear", T.LABEL)
	road_btns["draw"] = _btn(hud, Rect2(28, 162, 116, 46), "", _set_mode.bind("road:draw"), "sec", T.LABEL)
	road_btns["undo"] = _btn(hud, Rect2(148, 162, 56, 46), "", _on_undo, "sec", T.LABEL)
	road_btns["undo"].tooltip_text = "Ctrl+Z · 같은 준비 단계 안에서 자재를 돌려받아요"
	confirm_btn = _btn(hud, Rect2(28, 212, 116, 34), "", _on_confirm, "pri", T.LABEL)
	cancel_btn = _btn(hud, Rect2(148, 212, 56, 34), "", _on_cancel_draft, "sec", T.LABEL)
	ability_btn = _btn(hud, Rect2(186, 624, 132, 74), "", _set_mode.bind("ability"), "clear")
	accept_btn = _btn(hud, Rect2(), "", _on_accept, "pri", T.LABEL)
	reject_btn = _btn(hud, Rect2(), "", _on_reject, "sec", T.LABEL)
	quick_btn = _btn(hud, Rect2(), "", _on_quick, "clear")
	quick_btn.tooltip_text = "빠른 요청 (T) · 숫자키"
	for i in 5:
		var b := _btn(hud, Rect2(822 + i * 38, 655, 32, 32), "", _on_ping_kind.bind(PING_ORDER[i]), "clear")
		b.tooltip_text = GData.PING_KINDS[PING_ORDER[i]]
		ping_btns.append(b)
	ready_btn = _btn(hud, Rect2(1065, 628, 150, 48), "", _on_ready, "pri", T.BODY)
	speed_btns.append(_btn(hud, Rect2(1065, 650, 72, 40), "", _on_speed.bind(false), "clear", T.BODY))
	speed_btns.append(_btn(hud, Rect2(1141, 650, 74, 40), "", _on_speed.bind(true), "clear", T.BODY))
	for b in speed_btns:
		b.toggle_mode = true
	call_btn = _btn(hud, Rect2(1046, 560, 180, 44), "", _on_call, "pri", T.LABEL)
	call_btn.toggle_mode = true
	call_btn.tooltip_text = "적이 다 나왔을 때 다음 웨이브를 바로 불러요. 남은 적이 많을수록 보너스 골드가 커요 (전원 동의 · N)"
	var keys_order := ["first", "strong", "near"]
	for i in 3:
		prio_btns[keys_order[i]] = _btn(hud, Rect2(), "", _on_prio.bind(keys_order[i]), "sec", T.LABEL)
		prio_btns[keys_order[i]].toggle_mode = true
	up_btn = _btn(hud, Rect2(), "", _on_up_press, "pri", T.LABEL)
	a_btn = _btn(hud, Rect2(), "", _on_upgrade.bind("a"), "clear", T.LABEL)
	b_btn = _btn(hud, Rect2(), "", _on_upgrade.bind("b"), "clear", T.LABEL)
	move_btn = _btn(hud, Rect2(), "이동", _on_move, "sec", T.LABEL)
	fix_btn = _btn(hud, Rect2(), "수리 · 자재 1", _on_fix, "sec", T.LABEL)
	sell_btn = _btn(hud, Rect2(), "", _on_sell, "sec", T.LABEL)


## 일시정지 메뉴와 설정 창 (타이틀에서도 설정 창을 쓴다)
func _build_pause() -> void:
	pause_block = Control.new()
	pause_block.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_block.position = Vector2(-3000, -3000)
	pause_block.size = Vector2(8000, 8000)
	pause.add_child(pause_block)
	pause_btns["back"] = _btn(pause, Rect2(462, 246, 356, 46), "게임으로 돌아가기    ", _toggle_pause, "pri", T.BODY)
	pause_btns["settings"] = _btn(pause, Rect2(462, 306, 356, 46), "설정", _open_settings, "sec", T.BODY)
	pause_btns["help"] = _btn(pause, Rect2(462, 366, 356, 46), "조작 안내", _open_panel.bind("help"), "sec", T.BODY)
	pause_btns["mute"] = _btn(pause, Rect2(462, 426, 174, 46), "음소거", _open_panel.bind("mute"), "sec", T.BODY)
	pause_btns["codex"] = _btn(pause, Rect2(644, 426, 174, 46), "반응 도감", _open_panel.bind("codex"), "sec", T.BODY)
	pause_btns["leave"] = _btn(pause, Rect2(462, 506, 356, 44), "방 나가기", _on_leave, "danger", T.BODY)
	pause_btns["close"] = _btn(pause, Rect2(804, 150, 28, 28), "", _toggle_pause, "sec", T.LABEL)
	var tabs := ["그래픽", "조작", "오디오", "접근성"]
	var x := 320.0
	for i in tabs.size():
		var w := 94.0 if i != 1 else 70.0
		var b := _btn(pause, Rect2(x, 136, w, 34), tabs[i], _on_tab.bind(i), "sec", T.BODY)
		b.toggle_mode = true
		set_tabs.append(b)
		x += w + 4
	for i in 4:
		var b := _btn(pause, Rect2(668 + i * 72, 249, 66, 30), "%d" % FONT_STEPS[i], _on_font.bind(FONT_STEPS[i]), "sec", T.LABEL)
		b.toggle_mode = true
		font_btns.append(b)
	for k in ["fx_low", "dmg", "thick", "pattern"]:
		toggle_btns[k] = _btn(pause, Rect2(), "", _on_toggle.bind(k), "clear")
	shake_btn = _btn(pause, Rect2(680, 0, 220, 26), "", _noop, "clear")
	for i in GSession.MAX_SEATS:
		mute_btns.append(_btn(pause, Rect2(838, 200 + i * 60, 120, 34), "음소거", _on_mute.bind(i), "sec", T.LABEL))
	cfg_btns["close"] = _btn(pause, Rect2(940, 90, 28, 28), "", _close_panel, "sec", T.LABEL)
	cfg_btns["default"] = _btn(pause, Rect2(320, 592, 140, 34), "기본값", _on_cfg_default, "sec", T.LABEL)
	cfg_btns["cancel"] = _btn(pause, Rect2(678, 592, 130, 34), "취소", _close_panel, "sec", T.LABEL)
	cfg_btns["apply"] = _btn(pause, Rect2(818, 592, 140, 34), "적용    ", _on_cfg_apply, "pri", T.LABEL)


func _build_result() -> void:
	retry_btn = _btn(result, Rect2(898, 626, 356, 76), "", _on_retry, "pri", T.BODY)
	back_btn = _btn(result, Rect2(286, 634, 236, 56), "대기실로", _on_back, "sec", T.BODY)
	title_btn = _btn(result, Rect2(34, 634, 236, 56), "타이틀로     ", _on_leave, "sec", T.BODY)


func _noop() -> void:
	pass


func _show(which: String) -> void:
	_screen = which
	menu.visible = which == "menu"
	lobby.visible = which == "lobby"
	hud.visible = which == "game" and not _paused
	result.visible = which == "result"
	_menu_open = false
	_chat_key = ""
	_code_open = false
	if which != "game":
		_paused = false
	if which != "menu" and _panel != "" and not _paused:
		_panel = ""
	if web:
		var ui = JavaScriptBridge.get_interface("GilUI")
		if which == "lobby":
			ui.show("name", "내 이름 (10자)", 10, 0, 0, 10, 1, true)
			ui.put("name", str(ui.saved()))
		else:
			ui.hide("name")
		ui.hide("code")
		if which == "menu" or which == "game":
			ui.hide("chat")
		else:
			ui.show("chat", "Enter 를 눌러 채팅", GSession.CHAT_MAX, 0, 0, 10, 1, false)
	_evict()
	_place()


## 지금 쓰는 테마와 다음 테마 그림만 메모리에 둔다
func _evict() -> void:
	var keep := {}
	if _screen == "menu" or _screen == "lobby":
		keep[3] = true
		keep[0] = true
	elif s != null and s.m != null:
		var t := GData.theme_of(s.m.wave)
		keep[t] = true
		keep[mini(t + 1, GData.THEMES.size() - 1)] = true
		keep[_theme] = true
	for key in _theme_tex.keys():
		if not keep.has(int(str(key).left(1))):
			_theme_tex.erase(key)


func _place() -> void:
	var v := get_viewport_rect().size
	_off = (((v - STAGE) * 0.25).max(Vector2.ZERO).floor()) * 2.0      # 짝수 px 로
	stage.position = _off
	_place_chat()
	_place_pause()
	if not web:
		return
	var ui = JavaScriptBridge.get_interface("GilUI")
	var canvas = JavaScriptBridge.get_interface("document").querySelector("canvas")
	if canvas == null:
		return
	var scale: float = float(canvas.getBoundingClientRect().width) / maxf(v.x, 1.0)
	if _screen == "lobby":
		var at := _crew_rect(maxi(s.seat, 0) if s != null else 0).position + Vector2(8, 14)
		ui.show("name", "내 이름 (10자)", 10, _off.x + at.x, _off.y + at.y, 146, scale, true)
	if _screen == "menu" and _code_open:
		ui.show("code", "XXXX-XXXX-XXXX", 14, _off.x + 400, _off.y + 286, 478, scale, false)
	else:
		ui.hide("code")
	if _screen == "game" and _chat_typing and not _paused:
		ui.show("chat", "메시지 입력 · Enter 전송 · Esc 닫기", GSession.CHAT_MAX, _off.x + 16, _off.y + 560, 300, scale, false)
	elif _screen == "game":
		ui.hide("chat")
	elif _screen == "lobby":
		ui.show("chat", "Enter로 채팅", GSession.CHAT_MAX, _off.x + 1018, _off.y + 474, 244, scale, false)
	elif _screen == "result":
		ui.show("chat", "Enter로 채팅", GSession.CHAT_MAX, _off.x + 696, _off.y + 542, 538, scale, false)


func _place_chat() -> void:
	var show_chat := _screen != "menu" and not (_screen == "game" and _paused)
	chat_box.visible = show_chat
	chat_toggle.visible = _screen == "game" and not _paused
	chat_block.visible = show_chat
	match _screen:
		"game":
			var L := _ly()
			var cr: Rect2 = L["chat"]
			var expanded := chat_open or _chat_typing
			chat_box.visible = show_chat and expanded
			chat_block.position = cr.position
			chat_block.size = cr.size
			chat_box.position = cr.position + Vector2(8, 36)
			chat_box.size = cr.size - Vector2(16, 42)
			chat_box.mouse_filter = Control.MOUSE_FILTER_STOP
			chat_toggle.position = cr.position if not expanded else cr.position + Vector2(0, 0)
			chat_toggle.size = cr.size if not expanded else Vector2(cr.size.x, 36)
		"lobby":
			chat_block.position = Vector2(1010, 74)
			chat_block.size = Vector2(260, 446)
			chat_box.position = Vector2(1020, 110)
			chat_box.size = Vector2(240, 356)
			chat_box.mouse_filter = Control.MOUSE_FILTER_STOP
		"result":
			chat_block.position = Vector2(684, 470)
			chat_block.size = Vector2(562, 120)
			chat_box.position = Vector2(696, 506)
			chat_box.size = Vector2(538, 34)
			chat_box.mouse_filter = Control.MOUSE_FILTER_STOP


func _place_pause() -> void:
	var on := _paused or _panel != ""
	pause.visible = on
	pause_block.visible = on
	for k in pause_btns:
		pause_btns[k].visible = _paused and _panel == ""
	pause_btns["leave"].text = "방 나가기" if not (s != null and s.solo) else "연습 그만하기"
	pause_btns["close"].visible = _paused and _panel == ""
	var settings := _panel == "settings"
	for i in set_tabs.size():
		set_tabs[i].visible = settings
		set_tabs[i].set_pressed_no_signal(i == _tab)
	for k in cfg_btns:
		cfg_btns[k].visible = _panel != "" and (settings or k == "close")
	var rows := _settings_rows() if settings else []
	var want := {}
	for b in font_btns:
		want[b] = false
	for k in toggle_btns:
		want[toggle_btns[k]] = false
	want[shake_btn] = false
	for i in rows.size():
		var y := 218.0 + i * 64.0      # 줄 가운데
		var row: Array = rows[i]
		if row[0] == "font":
			for j in font_btns.size():
				want[font_btns[j]] = true
				font_btns[j].position = Vector2(668 + j * 72, y - 15)
				font_btns[j].set_pressed_no_signal(int(_cfg_draft.get("font", 100)) == FONT_STEPS[j])
		elif row[0] == "toggle":
			var b: Button = toggle_btns[row[1]]
			want[b] = true
			b.position = Vector2(902, y - 12)
			b.size = Vector2(44, 24)
		elif row[0] == "slider":
			want[shake_btn] = true
			shake_btn.position = Vector2(680, y - 13)
	for b in want:
		_vis(b, want[b])
	for i in mute_btns.size():
		var b: Button = mute_btns[i]
		b.visible = _panel == "mute" and s != null and i < _player_count() and i != s.seat
		if b.visible:
			b.text = "해제" if _muted.has(i) else "음소거"


# ── 메뉴·로비 동작 ──

func _player_name() -> String:
	if web:
		var ui = JavaScriptBridge.get_interface("GilUI")
		var n := str(ui.saved()).strip_edges().left(10)
		return n if n != "" else "플레이어"
	return "플레이어"


func _on_host() -> void:
	s = GSession.new(net, _player_name(), net.token())
	s.my_tab = net.tab_id()
	_name_sent = s.my_name
	net.host()
	s.open_host()
	_show("lobby")


func _on_join() -> void:
	s = GSession.new(net, _player_name(), net.token())
	s.my_tab = net.tab_id()
	_name_sent = s.my_name
	s.open_client()
	net.join(room)
	_show("lobby")


func _on_solo() -> void:
	s = GSession.new(null, _player_name(), "me")
	s.open_host(true)
	_enter_game()


func _on_copy_code() -> void:
	net.copy(_room_code())
	_say("방 코드를 복사했어요")


func _on_copy_link() -> void:
	net.copy(net.invite_url(net.code()))
	_say("초대 링크를 복사했어요")


func _room_code() -> String:
	var c: String = net.code().to_upper()
	if c.length() == 12:
		return "%s-%s-%s" % [c.left(4), c.substr(4, 4), c.substr(8)]
	return c


func _on_color(c: int) -> void:
	s.set_seat({"col": c})


func _on_lobby_kit(k: String) -> void:
	if s == null or s.seat < 0 or s.seat >= s.seats.size():
		return
	var kit: Array = (s.seats[s.seat].get("kit", GData.DEFAULT_KIT) as Array).duplicate()
	if kit.has(k):
		if kit.size() <= 1:
			return
		kit.erase(k)
	elif kit.size() < GData.KIT_SIZE:
		kit.append(k)
	else:
		_say("공구함이 가득 찼어요 · 먼저 하나를 빼 주세요")
		return
	var ordered := []
	for t in GData.TOWER_ORDER:
		if kit.has(t):
			ordered.append(t)
	s.seats[s.seat]["kit"] = ordered
	if ordered.size() == GData.KIT_SIZE:
		s.set_seat({"kit": ordered})
		if web:
			JavaScriptBridge.get_interface("GilUI").save_key("kit", ",".join(ordered))


func _on_diff(k: String) -> void:
	if s and s.is_host:
		s.set_difficulty(k)


func _on_lobby_ready() -> void:
	if s.seat >= 0 and s.seat < s.seats.size():
		s.set_seat({"ready": not bool(s.seats[s.seat]["ready"])})


func _on_start() -> void:
	var err := s.start_match()
	if err != "":
		_say(err)
	else:
		_enter_game()


func _on_leave() -> void:
	net.close()
	s = null
	mode = ""
	selected = -1
	_show("menu")


func _on_menu() -> void:
	_toggle_pause()


func _toggle_pause() -> void:
	if _screen != "game":
		return
	_paused = not _paused
	_panel = ""
	mode = ""
	_chat_typing = false
	hud.visible = not _paused
	_place()


func _open_settings() -> void:
	_cfg_draft = cfg.duplicate()
	_open_panel("settings")


func _open_panel(which: String) -> void:
	_panel = which
	_place()


func _close_panel() -> void:
	_panel = ""
	_place()


func _on_tab(i: int) -> void:
	_tab = i
	_place()


func _on_font(v: int) -> void:
	_cfg_draft["font"] = v
	_place()


func _on_toggle(k: String) -> void:
	_cfg_draft[k] = not bool(_cfg_draft.get(k, false))


func _on_cfg_default() -> void:
	_cfg_draft = CFG_DEFAULT.duplicate()
	_place()


func _on_cfg_apply() -> void:
	cfg = _cfg_draft.duplicate()
	_save_cfg()
	_close_panel()


func _on_mute(i: int) -> void:
	if _muted.has(i):
		_muted.erase(i)
	else:
		_muted[i] = true
	_chat_key = ""
	_place()


func _player_count() -> int:
	if s == null:
		return 0
	return s.m.players.size() if s.m != null else s.seats.size()


func _settings_rows() -> Array:
	match _tab:
		0:
			return [["toggle", "fx_low", "효과 줄이기", "눈·불씨·안개 수 제한"], ["toggle", "dmg", "데미지 숫자 표시", ""], ["slider", "shake", "화면 흔들림", ""]]
		3:
			return [["font", "font", "글자 크기", ""], ["toggle", "fx_low", "효과 줄이기", "눈·불씨·안개 수 제한"], ["toggle", "thick", "위험 구역 테두리 굵게", ""],
				["slider", "shake", "화면 흔들림", ""], ["toggle", "pattern", "색 대신 무늬로 팀 구분", "●▲■◆"], ["toggle", "dmg", "데미지 숫자 표시", ""]]
	return []


func _on_call() -> void:
	if s and s.m and s.m.can_call():
		var me: Dictionary = s.m.players[s.seat]
		s.command({"op": "call", "v": not bool(me.get("call", false))})
	if call_btn:
		call_btn.set_pressed_no_signal(false)


func _on_speed(fast: bool) -> void:
	if s and s.m:
		s.command({"op": "speed", "v": fast})


func _open_chat() -> void:
	if not web or _screen != "game":
		return
	_chat_typing = true
	_type_t = 0.0
	_place()
	JavaScriptBridge.get_interface("GilUI").focus("chat")


func _on_code() -> void:
	_code_open = not _code_open
	_place()
	if _code_open and web:
		JavaScriptBridge.get_interface("GilUI").focus("code")


func _on_code_go() -> void:
	if not web:
		return
	var ui = JavaScriptBridge.get_interface("GilUI")
	var code := str(ui.value("code")).strip_edges().to_lower().replace("-", "").replace(" ", "")
	if code.length() != 12:
		_say("방 코드 12자리를 넣어 주세요")
		return
	room = code
	_code_open = false
	_on_join()


func _on_retry() -> void:
	if s.state == "lost":
		net.join(net.code())
		s.state = "lobby"
		_show("lobby")
	elif s.is_host:
		s.rematch()
		_enter_game()


func _on_back() -> void:
	if s.state == "lost" or s.solo:
		_on_leave()
	elif s.is_host:
		s.to_lobby()
		_show("lobby")
	else:
		_on_leave()


func _enter_game() -> void:
	mode = ""
	selected = -1
	_fxs = []
	_disp = {}
	chat_open = false
	_paused = false
	_panel = ""
	_record_done = false
	_flip = 0
	_trail = {}
	_kit_open = false
	_summary_wave = 0
	_tut = 0
	if web and str(JavaScriptBridge.get_interface("GilUI").load_key("tutorial")) == "done":
		_tut = -1
	_pick_wave = 0
	_theme = GData.theme_of(s.m.wave) if s and s.m else 0
	_theme_goal = _theme
	_trans_t = 0.0
	_notice_t = 3.5 if _theme > 0 else 0.0
	_zoom = 2
	_cam = Vector2(GData.CASTLE.get_center()) - Vector2(4, 0)
	_clamp_cam()
	_overview_t = 1.2
	_last_phase = ""
	_show("game")


# ── 매 프레임 ──

func _process(delta: float) -> void:
	if _screen == "game" and s != null and s.m != null and not _paused:
		_update_camera(delta)
	_apply_camera()
	_tick += delta
	_toast_t -= delta
	_shake = maxf(_shake - delta * 3.0, 0.0)
	_flash_t -= delta
	if s != null:
		s.tick(delta)
		while not s.toasts.is_empty():
			_say(str(s.toasts.pop_front()))
		_route()
		if _screen != "menu":
			_take_chat()
		if _screen == "lobby":
			_update_lobby(delta)
		elif _screen == "game" and s.m:
			_update_theme(delta)
			_predict(delta)
			_take_fx()
			_update_hover()
			_update_hud()
			_update_chat_input(delta)
		elif _screen == "result":
			_update_result()
	if _screen == "menu":
		_update_title()
	if _panel == "settings" and shake_btn.visible and shake_btn.is_pressed():
		var x := get_local_mouse_position().x - _off.x
		_cfg_draft["shake"] = clampi(roundi((x - 849.0) / 160.0 * 100.0), 0, 100)
	for i in range(_fxs.size() - 1, -1, -1):
		_fxs[i]["t"] -= delta
		if _fxs[i]["t"] <= 0.0:
			_fxs.remove_at(i)
	queue_redraw()


func _update_title() -> void:
	join_btn.visible = room != ""
	host_btn.visible = room == ""
	code_go.visible = _code_open
	code_cancel.visible = _code_open
	for i in menu_items.size():
		_style(menu_items[i], "pri" if i == maxi(_menu_focus, 0) and not menu_items[i].disabled else "sec")
	if web and _code_open:
		_code_len = str(JavaScriptBridge.get_interface("GilUI").value("code")).strip_edges().replace("-", "").replace(" ", "").length()
	if not web:
		host_btn.disabled = true
		menu_items[1].disabled = true
	if web and _code_open:
		var sent = JSON.parse_string(str(JavaScriptBridge.get_interface("GilUI").take("code")))
		if sent is Array and not sent.is_empty():
			_on_code_go()


## 채팅 입력창은 Enter 로 열고, 전송 뒤 비우거나 Esc 로 닫으면 숨긴다
func _update_chat_input(delta: float) -> void:
	if not _chat_typing:
		return
	_type_t += delta
	if _type_t > 0.25 and web and not bool(JavaScriptBridge.get_interface("GilUI").typing()):
		_chat_typing = false
		_place()


func _route() -> void:
	var want := _screen
	if s.state == "lost":
		want = "result"
	elif s.state == "lobby":
		want = "lobby"
	elif s.state == "game" and s.m:
		want = "result" if s.m.phase == "over" else "game"
	if want != _screen:
		if want == "game":
			_enter_game()
		else:
			_show(want)


## 테마가 바뀌면 판정은 그대로 두고 그림만 전환 연출과 함께 교체한다
func _update_theme(delta: float) -> void:
	var m := s.m
	_notice_t -= delta
	var goal := GData.theme_of(m.wave)
	if goal != _theme_goal and m.phase != "over":
		_theme_goal = goal
		_trans_t = TRANSITION
		mode = ""
		_tex(goal, "base")
		_tex(goal, "over")
	if _trans_t > 0.0:
		var before := _trans_t
		_trans_t -= delta
		if before > TRANSITION - 1.4 and _trans_t <= TRANSITION - 1.4:
			_theme = _theme_goal
		if _trans_t <= 0.0:
			_theme = _theme_goal
			_notice_t = 4.0
	elif m.wave % GData.THEME_LEN == 0 and goal + 1 < GData.THEMES.size():   # 다음 테마를 예고 시점부터 준비
		_tex(goal + 1, "base")
		_tex(goal + 1, "over")


func _tex(theme: int, part: String) -> Texture2D:
	var key := "%d|%s|%s" % [theme, GData.LAYOUT, part]
	if not _theme_tex.has(key):
		_theme_tex[key] = load("res://art/map/%s_%s_%s.png" % [GData.LAYOUT, GData.THEMES[theme]["id"], part])
	return _theme_tex[key]


func _say(text: String) -> void:
	_toast = text
	_toast_t = 2.6


func _update_lobby(delta: float) -> void:
	var mine := s.seat
	var crew := _crew_rect(maxi(mine, 0)).position
	for c in 4:
		var b: Button = col_btns[c]
		b.position = crew + Vector2(10 + c * 28, 70)
		b.size = Vector2(24, 24)
		b.visible = mine >= 0
		var taken := false
		for i in s.seats.size():
			if i != mine and int(s.seats[i]["col"]) == c:
				taken = true
		b.disabled = taken
	ready_lobby.visible = mine >= 0 and mine < s.seats.size()
	ready_lobby.position = crew + Vector2(8, 194)
	ready_lobby.size = Vector2(146, 34)
	if ready_lobby.visible:
		var r: bool = s.seats[mine]["ready"]
		ready_lobby.text = "준비 취소" if r else "준비 완료"
		_style(ready_lobby, "sec" if r else "pri")
	var ready_n := 0
	for st in s.seats:
		if st["ready"]:
			ready_n += 1
	var my_kit: Array = s.seats[mine].get("kit", GData.DEFAULT_KIT) if mine >= 0 and mine < s.seats.size() else []
	for i in GData.TOWER_ORDER.size():
		var k: String = GData.TOWER_ORDER[i]
		lobby_kit[k].position = Vector2(330 + i * 66, 360)
		lobby_kit[k].size = Vector2(62, 120)
		lobby_kit[k].visible = false
	var di := 0
	for k in GData.DIFFICULTY:
		diff_btns[k].position = Vector2(16 + di * 96, 434)
		diff_btns[k].size = Vector2(90, 36)
		diff_btns[k].disabled = not s.is_host
		diff_btns[k].set_pressed_no_signal(s.difficulty == k)
		di += 1
	start_btn.visible = true
	start_btn.disabled = not s.is_host or s.seats.size() < 2 or ready_n < s.seats.size()
	start_btn.text = ""
	_place()
	if web and not _kit_sent and mine >= 0 and mine < s.seats.size():
		_kit_sent = true
		var saved := str(JavaScriptBridge.get_interface("GilUI").load_key("kit"))
		var kit := Array(saved.split(",")) if saved != "" else []
		if GMatch.kit_ok(kit):
			s.seats[mine]["kit"] = kit
			s.set_seat({"kit": kit})
	_name_t -= delta
	if web and _name_t <= 0.0 and mine >= 0:
		_name_t = 0.4
		var n := str(JavaScriptBridge.get_interface("GilUI").value("name")).strip_edges().left(10)
		if n != "" and n != _name_sent:
			_name_sent = n
			JavaScriptBridge.get_interface("GilUI").save(n)
			s.set_seat({"name": n})


func _take_chat() -> void:
	if web:
		var ui = JavaScriptBridge.get_interface("GilUI")
		var sent = JSON.parse_string(str(ui.take("chat")))
		if sent is Array:
			for text in sent:
				s.command({"op": "chat", "text": str(text)})
	var pending := 0
	for o in s.outbox:
		if o["c"].get("op", "") == "chat":
			pending += 1
	var key := "%d:%d:%d:%s:%s" % [_theme + _muted.size() * 100 + int(cfg["font"]) * 1000, s.chat.size(), pending, str(chat_open), str(s.chat[-1].get("text", "")).md5_text() if s.chat.size() > 0 else ""]
	if key == _chat_key:
		return
	_chat_key = key
	chat_box.clear()
	var rows: Array = s.chat
	if _screen == "game" and not chat_open:
		rows = rows.slice(maxi(rows.size() - 3, 0))
	for row in rows:
		var who := int(row["seat"])
		if _muted.has(who):
			continue
		if who >= 0:
			var col := int(row.get("col", _col_of_seat(who))) % 4
			chat_box.push_color(OWNER_TEXT[col])
			chat_box.add_text("%s %s  " % [MARK[col], row["name"]])
			chat_box.pop()
		else:
			chat_box.push_color(SUB)
			chat_box.add_text("— ")
			chat_box.pop()
		if row.has("x"):
			chat_box.push_meta("%f,%f" % [float(row["x"]), float(row["y"])])
			chat_box.push_color(AMBER)
			chat_box.add_text("[%s] %s" % [s.place_name(float(row["x"]), float(row["y"])), row["text"]])
			chat_box.pop()
			chat_box.pop()
		else:
			if who < 0:
				chat_box.push_color(SUB)
			chat_box.add_text(str(row["text"]))
			if who < 0:
				chat_box.pop()
		chat_box.newline()
	if pending > 0:
		chat_box.push_color(Color(SUB, 0.7))
		chat_box.add_text("전송 중… (%d)" % pending)
		chat_box.pop()


func _col_of_seat(seat: int) -> int:
	if s.m and seat >= 0 and seat < s.m.players.size():
		return int(s.m.players[seat].get("col", seat)) % 4
	if seat >= 0 and seat < s.seats.size():
		return int(s.seats[seat].get("col", seat)) % 4
	return maxi(seat, 0) % 4


func _on_chat_link(meta) -> void:
	var p := str(meta).split(",")
	if p.size() == 2:
		_flash = Vector2(float(p[0]), float(p[1]))
		_flash_t = 2.5


func _on_chat_toggle() -> void:
	chat_open = not chat_open
	_chat_key = ""
	_place()


func _predict(delta: float) -> void:
	var alive := {}
	for en in s.m.enemies:
		var id := int(en["id"])
		alive[id] = true
		if not s.is_host:
			if float(en.get("stun", 0.0)) <= 0.0:
				en["dist"] = float(en["dist"]) + float(GData.ENEMIES[en["type"]]["speed"]) * GData.SPEED_MUL * (1.0 - s.m.move_slow(en)) * delta
		var cur: float = _disp.get(id, float(en["dist"]))
		_disp[id] = lerpf(cur, float(en["dist"]), 1.0 - exp(-14.0 * delta))
	for id in _disp.keys():
		if not alive.has(id):
			_disp.erase(id)


func _take_fx() -> void:
	for f in s.fx:
		match str(f["k"]):
			"shot":
				_fxs.append({"k": "shot", "ty": f["ty"], "a": Vector2(f["x"], f["y"]), "b": Vector2(f["tx"], f["ty2"]), "r": float(f["r"]), "t": 0.22, "life": 0.22})
			"ability":
				_fxs.append({"k": "ability", "a": Vector2(f["x"], f["y"]), "o": int(f["o"]), "t": 0.9, "life": 0.9})
			"hit":
				_shake = 1.0
				_fxs.append({"k": "hit", "n": int(f["n"]), "t": 1.0, "life": 1.0})
				_fxs.append({"k": "gate", "e": int(f.get("e", 0)), "n": int(f["n"]), "t": 1.4, "life": 1.4})
			"early":
				_say("다음 웨이브를 일찍 불렀어요 · 전원 보너스 +%dG" % int(f["n"]))
			"rx":
				_fxs.append({"k": "rx", "a": Vector2(f["x"], f["y"]), "n": str(f["n"]), "o": f.get("o", []), "amp": bool(f.get("amp", false)), "t": 0.8, "life": 0.8})
			"newrx":
				_newrx = str(f["n"])
				_newrx_t = 2.0
			"boom":
				_fxs.append({"k": "kill", "a": Vector2(f["x"], f["y"]), "big": true, "t": 0.45, "life": 0.45})
			"puddle":
				_fxs.append({"k": "puddle", "a": Vector2(f["x"], f["y"]), "t": float(f["t"]), "life": float(f["t"])})
			"kill":
				_fxs.append({"k": "kill", "a": Vector2(f["x"], f["y"]), "big": bool(f.get("big", false)), "t": 0.45, "life": 0.45})
			"num":
				var at := Vector2(f["x"], f["y"])
				var merged := false
				for o in _fxs:
					if o["k"] == "num" and float(o["t"]) > 0.55 and (o["a"] as Vector2).distance_to(at) < 0.8:
						o["n"] = int(o["n"]) + int(f["n"])
						merged = true
						break
				if not merged:
					_fxs.append({"k": "num", "a": at, "n": int(f["n"]), "t": 0.8, "life": 0.8})
	s.fx = []
	if _fxs.size() > 140:
		_fxs = _fxs.slice(_fxs.size() - 140)


## 카메라: WASD·방향키, 화면 가장자리, 준비 시작 때 x1 잠깐
func _update_camera(delta: float) -> void:
	var m := s.m
	_newrx_t -= delta
	if m.phase != _last_phase:
		if m.phase == "prep" and _last_phase != "":
			_overview_t = 1.0
		_last_phase = m.phase
	if _overview_t > 0.0:
		_overview_t -= delta
	if _typing() or _chat_typing:
		return
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1
	if bool(cfg.get("edge", true)) and _pan.is_empty() and DisplayServer.window_is_focused():
		var mp := get_viewport().get_mouse_position()
		var v := get_viewport_rect().size
		if mp.x >= 0 and mp.y >= 0 and mp.x < v.x and mp.y < v.y:
			if mp.x < 8:
				d.x -= 1
			elif mp.x > v.x - 8:
				d.x += 1
			if mp.y < 8:
				d.y -= 1
			elif mp.y > v.y - 8:
				d.y += 1
	if d != Vector2.ZERO:
		var sp := CAM_SPEED * (2.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0) * (2.0 if _zoom == 1 else 1.0)
		_cam += d.normalized() * sp * delta
		_clamp_cam()


func _view_zoom() -> int:
	return 1 if _overview_t > 0.0 else _zoom


func _clamp_cam() -> void:
	_cam.x = clampf(_cam.x, 1.0, float(GData.W) - 1.0)
	_cam.y = clampf(_cam.y, 1.0, float(GData.H) - 1.0)


## MAP·CELL 을 카메라에 맞춘다. 칸 = 원본 19px x 배율, 위치는 원본 1픽셀 단위로 맞춘다
func _apply_camera() -> void:
	if _screen != "game" or s == null or s.m == null:
		return
	var z := _view_zoom()
	CELL = TILE * z
	var cam := _cam if z == 2 else Vector2(GData.W, GData.H) * 0.5
	var at := VIEW_C - cam * CELL
	MAP = (at / z).floor() * z


func _cam_to(g: Vector2) -> void:
	_cam = g
	_overview_t = 0.0
	_clamp_cam()


## 휠·Z·X: 커서 자리를 그대로 두고 x1 ↔ x2
func _set_zoom(z: int, at_screen := Vector2(-1, -1)) -> void:
	if z == _zoom:
		return
	_overview_t = 0.0
	var p := at_screen if at_screen.x >= 0 else VIEW_C
	var g := (p - MAP) / CELL
	_zoom = z
	if z == 2:
		_cam = g + (VIEW_C - p) / (TILE * 2.0)
	_clamp_cam()


func _update_hover() -> void:
	var mp := get_local_mouse_position() - _off
	var grid := (mp - MAP) / CELL
	var inside := grid.x >= 0 and grid.y >= 0 and grid.x < GData.W and grid.y < GData.H and get_viewport().gui_get_hovered_control() == self and not _over_hud(mp)
	hover = grid if inside else Vector2(-1, -1)
	if _trail.is_empty() or not inside:
		return
	var m := s.m
	var c := Vector2i(grid)
	var cells: Array = _trail["cells"]
	var last: Vector2i = cells[-1] if not cells.is_empty() else m.board.paths[int(_trail["e"])][int(_trail["i"])]
	if c == last:
		return
	var guard := 0
	while last != c and guard < 40:      # 마우스가 빨리 움직여도 한 칸씩 잇는다
		guard += 1
		var d := c - last
		var step := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
		var n := last + step
		_trail_step(m, n)
		cells = _trail["cells"]
		last = cells[-1] if not cells.is_empty() else m.board.paths[int(_trail["e"])][int(_trail["i"])]
		if int(_trail.get("j", -1)) != -1:
			return


## 길 그리기 한 칸: 뒤로 가면 지우고, 같은 길에 닿으면 끝점(B)
func _trail_step(m: GMatch, n: Vector2i) -> void:
	var e := int(_trail["e"])
	var path: Array = m.board.paths[e]
	var cells: Array = _trail["cells"]
	_trail["j"] = -1
	var back := cells.find(n)
	if back >= 0:
		_trail["cells"] = cells.slice(0, back + 1)
		return
	if n == path[int(_trail["i"])]:
		_trail["cells"] = []
		return
	if Board.is_castle(n):
		return
	var j := path.find(n)
	if j >= 0:
		_trail["j"] = j
		cells.append(n)
		return
	var f := m.board.lane_of(n)
	if f >= 0:      # 다른 길에 닿으면 그 길과 합류
		_trail["j"] = -2
		_trail["f"] = f
		_trail["fj"] = m.board.paths[f].find(n)
		cells.append(n)
		return
	cells.append(n)
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if Board.is_castle(n + d):      # 본부 바로 옆: 여기서 놓으면 새 끝
			_trail["j"] = -3
			return


## 지금 그리는 선으로 만든 새 경로 (끝점이 없으면 빈 배열)
func _trail_path(m: GMatch) -> Array:
	if _trail.is_empty() or int(_trail.get("j", -1)) == -1:
		return []
	var e := int(_trail["e"])
	var j := int(_trail["j"])
	var cells: Array = (_trail["cells"] as Array).duplicate()
	if j >= 0:
		cells.pop_back()
		return m.board.spliced(e, int(_trail["i"]), j, cells)
	var out: Array = m.board.paths[e].slice(0, int(_trail["i"]) + 1)
	if j == -2:
		cells.pop_back()
		out.append_array(cells)
		out.append_array(m.board.paths[int(_trail["f"])].slice(int(_trail["fj"])))
		return out
	out.append_array(cells)
	return out


func _gain(m: GMatch, e: int, path: Array) -> int:
	return GBot.gain_of(m, e, path, selected if m.towers.has(selected) else -1)


## 내 포탑을 고른 채 길 그리기를 누르면 그 포탑을 가장 많이 감싸는 다시 그리기를 바로 미리보기로 올린다
func _auto_wrap() -> void:
	var m := s.m
	if not m.towers.has(selected) or int(m.towers[selected]["owner"]) != s.seat:
		return
	var mat := int(m.players[s.seat]["mat"])
	var best := {}
	var best_gain := 0
	for e in m.board.paths.size():
		for i in m.board.paths[e].size():
			for kind in Board.SHAPES:
				for side in [1, -1]:
					var path := m.board.candidate(e, i, kind, side)
					if path.is_empty():
						continue
					var r := m.check_route(s.seat, e, path)
					if r.has("err") or int(r["cost"]) > mat or not (r["moves"] as Array).is_empty():
						continue
					var g := GBot.gain_of(m, e, path, selected)
					if g > best_gain:
						best_gain = g
						best = {"e": e, "path": path, "cost": r["cost"]}
	if best.is_empty():
		_say("이 포탑 둘레에 내 자재로 늘릴 수 있는 길이 없어요 · 직접 끌어서 그려 보세요")
		return
	s.command({"op": "draft", "e": best["e"], "path": Board.flat(best["path"])})
	_say("이 포탑 사거리 안 길이 %d칸 늘어나요 · 자재 %d · 다른 모양은 길을 직접 끌어서" % [best_gain, int(best["cost"])])


func _update_hud() -> void:
	var m := s.m
	var prep := m.phase == "prep"
	var me: Dictionary = m.players[s.seat]
	var locked := _trans_t > 0.0
	var kit: Array = me["kit"]
	for i in slot_btns.size():
		var k: String = kit[i] if i < kit.size() else ""
		slot_btns[i].disabled = k == "" or locked or not prep or int(me["gold"]) < int(GData.TOWERS[k]["cost"])
	build_btns["kit"].disabled = not prep
	if prep and _pick_wave != m.wave:      # 준비 시작: 카드 띠가 올라온다
		_pick_wave = m.wave
		_kit_pick = []
		_kit_open = not bool(me["picked"])
	if not prep:
		_kit_open = false
	for i in pick_btns.size():
		_vis(pick_btns[i], _kit_open and i < (me["hand"] as Array).size())
	_vis(pick_go, _kit_open)
	_vis(pick_reroll, _kit_open)
	for i in lock_btns.size():
		_vis(lock_btns[i], prep and i < kit.size() and not _kit_open)
		lock_btns[i].position = slot_btns[i].position + Vector2(slot_btns[i].size.x - 24, 2)
		lock_btns[i].size = Vector2(22, 22)
	if _kit_open:
		pick_reroll.disabled = int(me["gold"]) < m.reroll_cost(s.seat)
	var can_road := prep and not locked
	road_btns["draw"].visible = prep
	road_btns["draw"].disabled = not can_road
	road_btns["draw"].toggle_mode = true
	road_btns["draw"].set_pressed_no_signal(mode == "road:draw")
	road_btns["undo"].visible = prep
	road_btns["undo"].disabled = not can_road or not m.undo_ready(s.seat)
	var any_draft := _confirmable(m)
	var drawing := mode.begins_with("road:") or m.drafts.has(s.seat) or not _trail.is_empty()
	confirm_btn.visible = prep and drawing
	cancel_btn.visible = prep and drawing
	var prop := _proposal(m)
	accept_btn.visible = not prop.is_empty()
	reject_btn.visible = accept_btn.visible
	if accept_btn.visible:
		accept_btn.disabled = locked or int(prop["cost"]) > int(me["mat"])
	confirm_btn.disabled = not can_road or any_draft.is_empty()
	cancel_btn.disabled = not m.drafts.has(s.seat) and _trail.is_empty()
	ability_btn.disabled = m.phase != "combat" or bool(me["used"])
	ready_btn.visible = prep
	ready_btn.disabled = locked
	if prep:
		var r: bool = me["ready"]
		ready_btn.text = ""
		_style(ready_btn, "sec" if r else "pri")
	for b in speed_btns:
		b.visible = m.phase == "combat"
	call_btn.visible = m.can_call()
	if call_btn.visible:
		var mine := bool(m.players[s.seat].get("call", false))
		var alive := int(m.enemies.size())
		call_btn.text = "일찍 +%d · %d/%d" % [GData.early_bonus(alive), m.call_votes(), m.online_count()]
		if mine:
			call_btn.text = "부르기 취소 %d/%d" % [m.call_votes(), m.online_count()]
		_style(call_btn, "sec" if mine else "pri")
	var voting := m.phase == "reward"
	for k in reward_btns:
		reward_btns[k].visible = voting
	if int(m.summary.get("wave", 0)) != _summary_wave:
		_summary_wave = int(m.summary.get("wave", 0))
		_summary_t = 7.0
	_summary_t -= get_process_delta_time()
	_update_tutorial(m)
	_layout_hud()
	_update_inspector(prep)


func _update_inspector(prep: bool) -> void:
	# 보이기 여부는 한 번만 정해서 넣는다 (숨겼다 다시 보이면 누르던 클릭이 취소된다)
	var m := s.m
	if selected >= 0 and not m.towers.has(selected):
		selected = -1
	var t: Dictionary = m.towers.get(selected, {})
	if t.is_empty() or int(t["lv"]) != 2:
		_branch_pick = false
	var mine := not t.is_empty() and int(t["owner"]) == s.seat
	var show_prio: bool = mine and not (GMatch.is_trap(t) or t["type"] == "signal") if not t.is_empty() else false
	var show_up := false
	var show_ab := false
	var show_fix := false
	var show_sell := mine and prep
	if not t.is_empty():
		_inspector_layout(_inspector_rect(m, t), mine, prep, int(t["lv"]))      # 첫 클릭이 버튼에 닿게 자리를 먼저
		if mine:
			for k in prio_btns:
				prio_btns[k].set_pressed_no_signal(k == t["prio"])
	if not t.is_empty() and mine and prep:
		var d: Dictionary = GData.TOWERS[t["type"]]
		var gold: int = m.players[s.seat]["gold"]
		var free := int(m.players[s.seat].get("free_up", 0)) > 0
		var lv := int(t["lv"])
		if lv <= 2:
			show_up = true
			up_btn.disabled = not free and gold < int(d["up"][lv - 1])
		if lv == 2 and _branch_pick:
			show_ab = true
			show_prio = false
			a_btn.disabled = up_btn.disabled
			b_btn.disabled = up_btn.disabled
		if GMatch.is_trap(t):
			var full := int(GData.tower_stats(t["type"], lv, str(t["branch"]))["uses"])
			show_fix = int(t["uses"]) < full
			fix_btn.disabled = int(m.players[s.seat]["mat"]) < GData.TRAP_REPAIR
			fix_btn.position = sell_btn.position + Vector2(0, -40)
			fix_btn.size = Vector2(_ly()["insp"].size.x - 16, 32)
	for k in prio_btns:
		_vis(prio_btns[k], show_prio)
	_vis(up_btn, show_up)
	_vis(a_btn, show_ab)
	_vis(b_btn, show_ab)
	_vis(fix_btn, show_fix)
	_vis(sell_btn, show_sell)
	_vis(move_btn, false)


func _vis(b: Control, v: bool) -> void:
	if b.visible != v:
		b.visible = v


func _side_top(m: GMatch) -> float:
	var r: Rect2 = _ly()["side"]
	return r.position.y


func _inspector_rect(m: GMatch, t: Dictionary) -> Rect2:
	return _ly()["insp"]


func _save_record() -> void:
	if _record_done or s == null or s.m == null or not web:
		return
	_record_done = true
	var m := s.m
	var reached := m.wave if not m.cleared else GData.LAST_WAVE
	if reached <= int(_record.get("wave", 0)):
		return
	var friends := []
	for i in m.players.size():
		if i != s.seat:
			friends.append(str(m.players[i]["name"]))
	_record = {"wave": reached, "friend": ", ".join(friends) if not s.solo else "연습", "theme": str(GData.THEMES[GData.theme_of(m.wave)]["name"]), "time": m.time}
	JavaScriptBridge.get_interface("GilUI").save_key("record", JSON.stringify(_record))


func _update_result() -> void:
	_save_record()
	var lost := s.state == "lost"
	retry_btn.text = ""
	retry_btn.disabled = not (lost or s.is_host) or (lost and s.is_host)
	back_btn.visible = not lost and not s.solo and s.is_host


# ── 입력 ──

func _set_mode(v: String) -> void:
	mode = "" if mode == v else v
	_flip = 0
	if mode != "" and not mode.begins_with("road:"):   # 길 미리보기 중에는 고른 포탑의 사거리 변화를 계속 보여 준다
		selected = -1
	_trail = {}
	if mode == "road:draw":
		_auto_wrap()


func _on_vote(k: String) -> void:
	s.command({"op": "vote", "v": k})


func _skip_tutorial() -> void:
	_tut = -1
	if web:
		JavaScriptBridge.get_interface("GilUI").save_key("tutorial", "done")


## 첫 판 안내: 건설 → 길 바꾸기 → 긴급 냉각
func _update_tutorial(m: GMatch) -> void:
	if _tut < 0 or _paused:
		_vis(tut_skip, false)
	if _tut < 0:
		return
	var me: Dictionary = m.players[s.seat]
	var mine := 0
	for id in m.towers:
		if int(m.towers[id]["owner"]) == s.seat:
			mine += 1
	if _tut == 0 and mine >= 1:
		_tut = 1
	if _tut == 1 and (int(me.get("mat", 0)) < GData.MAT_START or m.wave >= 3):
		_tut = 2
	if _tut == 2 and (int(me.get("support", 0)) > 0 or m.wave >= 4):
		_skip_tutorial()
	pass


func _on_ready() -> void:
	if s and s.m and s.m.phase == "prep" and _trans_t <= 0.0:
		s.command({"op": "ready", "v": not bool(s.m.players[s.seat]["ready"])})
		mode = ""


func _on_prio(v: String) -> void:
	s.command({"op": "prio", "id": selected, "v": v})


func _on_upgrade(branch: String) -> void:
	s.command({"op": "upgrade", "id": selected, "branch": branch})
	_branch_pick = false


## [강화]: MK-2 는 바로, MK-3 은 갈래 카드 두 장을 펼친다
func _on_up_press() -> void:
	if not s.m.towers.has(selected):
		return
	if int(s.m.towers[selected]["lv"]) == 1:
		_on_upgrade("")
	else:
		_branch_pick = not _branch_pick


func _on_move() -> void:
	if selected >= 0:
		mode = "move:%d" % selected


func _on_sell() -> void:
	s.command({"op": "sell", "id": selected})
	selected = -1


## 확정할 미리보기: 내 것, 없으면 동료의 제안 (내 자재로 확정)
func _confirmable(m: GMatch) -> Dictionary:
	if m.drafts.has(s.seat):
		return m.drafts[s.seat]
	for k in m.drafts:
		return m.drafts[k]
	return {}


func _on_confirm() -> void:
	var d := _confirmable(s.m)
	if d.is_empty():
		return
	s.command({"op": "edit", "e": d["e"], "path": d["path"]})
	mode = ""
	_trail = {}


func _on_undo() -> void:
	s.command({"op": "undo"})


func _on_fix() -> void:
	s.command({"op": "repair", "id": selected})


func _on_slot(i: int) -> void:
	var kit: Array = s.m.players[s.seat]["kit"]
	if i < kit.size():
		_set_mode("build:" + str(kit[i]))


func _has_towers(m: GMatch) -> bool:
	for id in m.towers:
		if int(m.towers[id]["owner"]) == s.seat:
			return true
	return false


func _toggle_kit() -> void:
	_kit_open = not _kit_open


func _on_kit_pick(i: int) -> void:
	if s.m == null:
		return
	var hand: Array = s.m.players[s.seat]["hand"]
	if i >= hand.size():
		return
	var k: String = hand[i]
	var need := GData.KIT_SIZE - (1 if str(s.m.players[s.seat]["lock"]) != "" else 0)
	if _kit_pick.has(k):
		_kit_pick.erase(k)
	elif _kit_pick.size() < need:
		_kit_pick.append(k)


func _on_pick_go() -> void:
	var need := GData.KIT_SIZE - (1 if str(s.m.players[s.seat]["lock"]) != "" else 0)
	if _kit_pick.size() != need:
		_say("%d장을 골라 주세요" % need)
		return
	s.command({"op": "pick", "v": _kit_pick.duplicate()})
	_kit_open = false


func _on_reroll() -> void:
	_kit_pick = []
	s.command({"op": "reroll"})


func _on_lock(i: int) -> void:
	var kit: Array = s.m.players[s.seat]["kit"]
	if i < kit.size():
		s.command({"op": "lock", "v": kit[i]})


## 동료 길 제안: 수락은 내 자재로 확정, 거절은 내 화면에서만 접는다
func _proposal(m: GMatch) -> Dictionary:
	if m == null or m.phase != "prep":
		return {}
	for k in m.drafts:
		if int(k) == s.seat:
			continue
		var d: Dictionary = m.drafts[k]
		if _dismissed.get(int(k), []) == d["path"]:
			continue
		return {"seat": int(k), "e": int(d["e"]), "path": d["path"], "cost": int(d["cost"])}
	return {}


func _on_accept() -> void:
	var p := _proposal(s.m)
	if p.is_empty():
		return
	s.command({"op": "edit", "e": p["e"], "path": p["path"]})


func _on_reject() -> void:
	var p := _proposal(s.m)
	if not p.is_empty():
		_dismissed[int(p["seat"])] = p["path"]


func _on_quick() -> void:
	_quick_open = not _quick_open


func _on_cancel_draft() -> void:
	_trail = {}
	s.command({"op": "draft"})


func _on_ping_kind(k: String) -> void:
	_set_mode("ping:" + k)


func _gui_input(ev: InputEvent) -> void:
	if s == null or s.m == null or _screen != "game":
		return
	if ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not _wheel.is_empty():
		var kind := _wheel_kind()
		var at: Vector2 = _wheel["at"]
		_wheel = {}
		s.command({"op": "ping", "kind": kind, "x": at.x, "y": at.y})
		return
	if ev is InputEventMouseButton and ev.pressed and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_set_zoom(2 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1, ev.position - _off)
		return
	if ev is InputEventMouseButton and ev.pressed and (ev.button_index == MOUSE_BUTTON_MIDDLE or ev.button_index == MOUSE_BUTTON_RIGHT):
		_pan = {"from": ev.position, "cam": _cam, "button": ev.button_index, "moved": false}
		if ev.button_index == MOUSE_BUTTON_MIDDLE:
			return
	if ev is InputEventMouseMotion and not _pan.is_empty():
		var dd: Vector2 = ev.position - _pan["from"]
		if dd.length() > 6.0:
			_pan["moved"] = true
		if _pan["moved"]:
			if _zoom == 1:
				_zoom = 2
			_cam = Vector2(_pan["cam"]) - dd / (TILE * 2.0)
			_overview_t = 0.0
			_clamp_cam()
		return
	if ev is InputEventMouseButton and not ev.pressed and not _pan.is_empty() and ev.button_index == int(_pan["button"]):
		var moved := bool(_pan["moved"])
		_pan = {}
		if moved or ev.button_index == MOUSE_BUTTON_MIDDLE:
			return
		mode = ""
		selected = -1
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = ev.position - _off
		if _minimap_click(p) or _arrow_click(p):
			return
		if _over_hud(p):
			return
	if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and _minimap_rect().has_point(ev.position - _off) and _trail.is_empty() and _drag.is_empty():
		_minimap_click(ev.position - _off)
		return
	if ev is InputEventMouseMotion and not _drag.is_empty():
		var g: Vector2 = (ev.position - _off - MAP) / CELL
		if Vector2i(g) != _drag["from"] and s.m.phase == "prep":
			mode = "move:%d" % int(_drag["id"])
	if ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not _drag.is_empty():
		var g: Vector2 = (ev.position - _off - MAP) / CELL
		var was := mode.begins_with("move:")
		_drag = {}
		if was:
			if Vector2i(g).x >= 0 and Vector2i(g).y >= 0 and g.x < GData.W and g.y < GData.H:
				_click(g)
			mode = ""
		return
	if ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not _trail.is_empty():
		var path := _trail_path(s.m)
		if not path.is_empty():
			s.command({"op": "draft", "e": int(_trail["e"]), "path": Board.flat(path)})
		elif (_trail["cells"] as Array).size() > 0:
			_say("같은 길, 다른 길(합류) 또는 본부 바로 옆에서 놓아야 해요")
		_trail = {}
		return
	if ev is InputEventMouseButton and ev.pressed:
		_menu_open = false
		var grid: Vector2 = (ev.position - _off - MAP) / CELL
		var inside := grid.x >= 0 and grid.y >= 0 and grid.x < GData.W and grid.y < GData.H
		if ev.button_index == MOUSE_BUTTON_LEFT and inside:
			if ev.alt_pressed:
				_wheel = {"at": grid, "from": ev.position - _off}
			else:
				_click(grid)


## 휠에서 고른 핑: 위 주목, 오른쪽 위험, 오른쪽 아래 건설 요청, 왼쪽 아래 길 변경, 왼쪽 내가 맡을게
func _wheel_kind() -> String:
	var d: Vector2 = (get_local_mouse_position() - _off) - Vector2(_wheel["from"])
	if d.length() < 22.0:
		return "look"
	var a := fposmod(rad_to_deg(d.angle()) + 90.0 + 36.0, 360.0)
	return PING_ORDER[int(a / 72.0) % 5]


func _draw_wheel() -> void:
	if _wheel.is_empty():
		return
	var c: Vector2 = _wheel["from"]
	var pick := _wheel_kind()
	var labels := {"look": "주목", "danger": "위험", "build": "건설 요청", "road": "길 변경", "mine": "내가 맡을게"}
	_pcircle(c, 104.0, Color(0.1, 0.11, 0.12, 0.92))
	for i in 5:
		var k: String = PING_ORDER[i]
		var a0 := deg_to_rad(-90.0 - 36.0 + i * 72.0)
		var pts := PackedVector2Array()
		for n in 13:
			pts.append(c + Vector2.from_angle(a0 + deg_to_rad(72.0) * n / 12.0) * 100.0)
		for n in 13:
			pts.append(c + Vector2.from_angle(a0 + deg_to_rad(72.0) * (12 - n) / 12.0) * 36.0)
		if k == pick:
			draw_colored_polygon(pts, Color(PING_COL[i], 0.85))
		pts.append(pts[0])
		_ppoly(pts, Color(0.06, 0.07, 0.08), 2.0, true)
		var mid := c + Vector2.from_angle(a0 + deg_to_rad(36.0)) * 68.0
		_icon(Vector2i(i, 1), Rect2(mid + Vector2(-10, -22), Vector2(20, 20)), Color.WHITE if k == pick else PING_COL[i])
		_t(mid + Vector2(0, 0), labels[k], T.LABEL, INK, 1)
	_pcircle(c, 34.0, Color(0.16, 0.17, 0.19))
	_t(c + Vector2(0, -8), "Alt", T.LABEL, SUB, 1)


## 빠른 요청 (F1~F4): Alt 를 누르고 있거나 핑 휠을 열면 보인다
func _chevrons(c: Vector2, col: Color) -> void:
	c = _ev(c)
	for k in 2:
		for j in 5:
			var dx := (4 - absi(j - 2) * 2) - 8 + k * 10
			_prect(Rect2(c + Vector2(dx, (j - 2) * 4 - 2), Vector2(4, 4)), col)


func _draw_quick() -> void:
	if _wheel.is_empty() and not Input.is_key_pressed(KEY_ALT) and not _quick_open:
		return
	var r := Rect2(16, 220, 230, 196)
	if _quick_open:
		r = Rect2(quick_btn.position + Vector2(0, -204), Vector2(230, 196))
	_card(r, Color(0.11, 0.12, 0.13, 0.94), LINE)
	_t(r.position + Vector2(12, 10), "빠른 요청 · 숫자키", T.LABEL, SUB)
	for i in QUICK.size():
		var b := Rect2(r.position + Vector2(12, 36 + i * 38), Vector2(206, 32))
		_metal(b, PANEL_HI, PANEL_LO, LINE, 4.0)
		_t(b.position + Vector2(84, 7), QUICK[i], T.STRONG, INK, 1)
		_key_chip(b.position + Vector2(170, 6), str(i + 1))


func _click(grid: Vector2) -> void:
	var c := Vector2i(grid)
	if _trans_t > 0.0 and (mode.begins_with("build:") or mode.begins_with("move:") or mode.begins_with("road:")):
		return
	if mode.begins_with("build:"):
		s.command({"op": "build", "type": mode.substr(6), "x": c.x, "y": c.y})
	elif mode.begins_with("move:"):
		s.command({"op": "move", "id": int(mode.substr(5)), "x": c.x, "y": c.y})
		mode = ""
	elif mode.begins_with("road:"):
		var e := s.m.board.lane_of(c)
		if e < 0:
			_say("길 위의 한 칸을 누른 채 끌어서 같은 길의 다른 칸에서 놓아요")
		else:
			_trail = {"e": e, "i": s.m.board.paths[e].find(c), "cells": [], "j": -1}
	elif mode == "ability":
		s.command({"op": "ability", "x": grid.x, "y": grid.y})
		mode = ""
	elif mode.begins_with("ping:"):
		s.command({"op": "ping", "kind": mode.substr(5), "x": grid.x, "y": grid.y})
		mode = ""
	else:
		var cells := s.m.tower_cells()
		selected = int(cells[c]) if cells.has(c) else -1
		_branch_pick = false
		if selected >= 0 and s.m.phase == "prep" and int(s.m.towers[selected]["owner"]) == s.seat:
			_drag = {"id": selected, "from": c}


func _typing() -> bool:
	return web and bool(JavaScriptBridge.get_interface("GilUI").typing())


func _unhandled_key_input(ev: InputEvent) -> void:
	if not ev.pressed or ev.echo or _typing():
		return
	if ev.keycode == KEY_ESCAPE:
		if _panel != "":
			_close_panel()
		elif _code_open:
			_code_open = false
			_place()
		elif _screen == "game" and (mode != "" or selected >= 0) and not _paused:
			mode = ""
			selected = -1
		elif _screen == "game" and _tut >= 0 and not _paused:
			_skip_tutorial()
		elif _screen == "game" and chat_open and not _paused:
			chat_open = false
			_place()
		elif _screen == "game":
			_toggle_pause()
		return
	if _screen == "menu" and _panel == "":
		var dir := 0
		if ev.keycode == KEY_DOWN:
			dir = 1
		elif ev.keycode == KEY_UP:
			dir = -1
		if dir != 0:
			for _i in menu_items.size():
				_menu_focus = posmod(_menu_focus + dir, menu_items.size())
				if not menu_items[_menu_focus].disabled:
					break
		elif ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
			var b: Button = menu_items[_menu_focus]
			if _menu_focus == 0 and room != "":
				_on_join()
			elif not b.disabled:
				b.pressed.emit()
		return
	if s == null or _paused or _panel != "":
		return
	if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
		if _screen == "game" and _kit_open:
			_on_pick_go()
		elif _screen == "game":
			_open_chat()
		elif web and _screen != "menu":
			JavaScriptBridge.get_interface("GilUI").focus("chat")
		return
	if s.m == null or _screen != "game":
		return
	match ev.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			var i: int = ev.keycode - KEY_1
			if _kit_open:
				_on_kit_pick(i)
				return
			if _quick_open and i < QUICK.size():
				s.command({"op": "chat", "text": QUICK[i]})
				_quick_open = false
				return
			if i < slot_btns.size() and not slot_btns[i].disabled:
				_on_slot(i)
		KEY_K:
			if not build_btns["kit"].disabled:
				_toggle_kit()
		KEY_Z:
			if ev.ctrl_pressed or ev.meta_pressed:
				if road_btns["undo"].visible and not road_btns["undo"].disabled:
					_on_undo()
			else:
				_set_zoom(2, get_local_mouse_position() - _off)
		KEY_X:
			_set_zoom(1)
		KEY_G:
			_key_mode("road:draw", road_btns["draw"])
		KEY_H:
			_cam_to(Vector2(GData.CASTLE.get_center()))
		KEY_T:
			_quick_open = not _quick_open
		KEY_E:
			if confirm_btn.visible and not confirm_btn.disabled:
				_on_confirm()
		KEY_Q: _key_mode("ability", ability_btn)
		KEY_F1, KEY_F2, KEY_F3, KEY_F4:
			var e: int = ev.keycode - KEY_F1
			if e < s.m.board.paths.size():
				_cam_to(Vector2(s.m.board.paths[e][0]) + Vector2(0.5, 0.5))
		KEY_SPACE: _on_ready()
		KEY_N: _on_call()


func _key_mode(v: String, b: Button) -> void:
	if not b.disabled:
		_set_mode(v)


# ── 그리기 공통 ──

func _t(p: Vector2, text: String, st: int, col := INK, align := 0) -> void:
	var f: Array = _style_font(st)
	_tx(Rect2(p, Vector2(0, float(f[2]))), text, st, col, align)


## r 안에서 세로 가운데. align 0 왼쪽(r.x) · 1 가운데 · 2 오른쪽(r.end.x)
func _tx(r: Rect2, text: String, st: int, col := INK, align := 0) -> void:
	if _has_hangul(text):
		_hangul_drawn += 1
	if st == T.KEY and _has_hangul(text) and not _warned.has(text):
		_warned[text] = true
		push_warning("KEY 스타일에 한글: " + text)
	var f: Array = _style_font(st)
	var font: Font = f[0]
	var size: int = f[1]
	var asc := font.get_ascent(size)
	var h := asc + font.get_descent(size)
	var at := Vector2(r.position.x, r.position.y + (r.size.y - h) * 0.5 + asc)
	if align != 0:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		at.x = (r.position.x + r.size.x * 0.5 - w * 0.5) if align == 1 else (r.end.x - w)
	at = _ev(at)
	if col.a > 0.5 and col.get_luminance() > 0.45:      # 1픽셀(화면 2px) 아래 검정 그림자
		draw_string(font, at + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, OUTLINE)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


var _warned := {}
var _hangul_drawn := 0      # 이번 프레임에 그린 한글 글줄 수 (확인용)


func _has_hangul(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 0xAC00 and c <= 0xD7A3:
			return true
	return false


func _card(r: Rect2, fill := PANEL, edge := LINE, radius := 3) -> void:
	if fill == PANEL:
		_nine(r, "panel_steel")
	elif fill == WELL or fill.get_luminance() < 0.14:
		_nine(r, "panel_well")
	else:
		_prect(r, Color(fill, 1.0) if fill.a > 0.8 else fill)
	if edge == AMBER or edge == DANGER:
		_prect(r.grow(-2), edge, false, 2.0)


func _hazard(r: Rect2) -> void:
	var info = _ui_rects.get("hazard")
	var src := Rect2(info["rect"][0], info["rect"][1], info["rect"][2], info["rect"][3])
	var x := r.position.x
	while x < r.end.x:
		var w := minf(src.size.x, r.end.x - x)
		draw_texture_rect_region(TEX_UI, Rect2(x, r.position.y, w, r.size.y), Rect2(src.position, Vector2(w, src.size.y)))
		x += src.size.x


func _blueprint() -> void:
	var v := get_viewport_rect().size
	draw_set_transform(Vector2.ZERO)
	_prect(Rect2(Vector2.ZERO, v), BG)
	var grid := Color(0.55, 0.63, 0.67, 0.07)
	var x := 0.0
	while x < v.x:
		_pline(Vector2(x, 0), Vector2(x, v.y), grid, 1.0)
		x += 24.0
	var y := 0.0
	while y < v.y:
		_pline(Vector2(0, y), Vector2(v.x, y), grid, 1.0)
		y += 24.0
	draw_set_transform(_off)


## 아이콘은 원본 16px 의 2배(32) 또는 1배(16)만
func _icon(index: Vector2i, r: Rect2, tint := Color.WHITE) -> void:
	var size := 32.0 if r.size.x >= 22.0 else 16.0
	var at := _ev(r.get_center() - Vector2(size, size) * 0.5)
	draw_texture_rect_region(TEX_ICONS, Rect2(at, Vector2(size, size)), Rect2(index.x * 64, index.y * 64, 64, 64), tint)


func _tag(center: Vector2, col: int, size_px := 18.0) -> void:
	var h := size_px * 0.5
	_prect(Rect2(center - Vector2(h, h), Vector2(size_px, size_px)), WELL)
	_prect(Rect2(center - Vector2(h - 1.5, h - 1.5), Vector2(size_px - 3, size_px - 3)), OWNER[col])
	var r := size_px * 0.26
	var w := maxf(size_px * 0.11, 1.4)
	match col:
		0:
			_parc(center, r, 0, TAU, 18, Color.WHITE, w, true)
		1:
			var p := PackedVector2Array([center + Vector2(0, -r * 1.15), center + Vector2(r * 1.1, r * 0.8), center + Vector2(-r * 1.1, r * 0.8), center + Vector2(0, -r * 1.15)])
			_ppoly(p, Color.WHITE, w, true)
		2:
			_prect(Rect2(center - Vector2(r, r), Vector2(r, r) * 2), Color.WHITE, false, w)
		_:
			var p := PackedVector2Array([center + Vector2(0, -r * 1.25), center + Vector2(r * 1.25, 0), center + Vector2(0, r * 1.25), center + Vector2(-r * 1.25, 0), center + Vector2(0, -r * 1.25)])
			_ppoly(p, Color.WHITE, w, true)


func _mk(t: Dictionary) -> int:
	var lv := int(t["lv"])
	return 0 if lv <= 1 else (1 if lv == 2 else (2 if str(t["branch"]) == "a" else 3))


## 지도 위 포탑: 칸 왼쪽 위(cell_pos)에 기초를 두고 위로 솟는다 (3/4 시점)
## 지도 위 포탑: 그림 아래 19줄이 칸, 위로 솟는다
func _tower_sprite(type: String, lv: int, branch: String, col: int, cell_pos: Vector2, cell_px: float, tint := Color.WHITE) -> void:
	var mk := 0 if lv <= 1 else (1 if lv == 2 else (2 if branch == "a" else 3))
	var k := cell_px / TILE
	var at := cell_pos + Vector2(cell_px * 0.5 - TW.x * 0.5 * k, cell_px - TW.y * k)
	draw_texture_rect_region(TEX_TOWERS, Rect2(at.round(), TW * k), _tower_src(type, mk, col), tint)


func _tower_src(type: String, mk: int, col: int) -> Rect2:
	return Rect2((mk * 4 + col) * TW.x, int(TOWER_ROW[type]) * TW.y, TW.x, TW.y)


## 공구함 칸 아이콘: 2배 그대로, 칸 높이만큼 위쪽(머리)만
func _tower_head(type: String, col: int, r: Rect2, tint := Color.WHITE) -> void:
	var src := _tower_src(type, 0, col)
	var top := _art_top(src)
	var rows := floorf(minf(TW.y - top, r.size.y * 0.5))
	src.position.y += top
	src.size.y = rows
	var w := TW.x * 2.0
	var at := _ev(Vector2(r.get_center().x - w * 0.5, r.position.y))
	draw_texture_rect_region(TEX_TOWERS, Rect2(at, Vector2(w, rows * 2.0)), src, tint)


var _top_cache := {}
var _towers_img: Image


## 프레임에서 처음 칠해진 줄
func _art_top(src: Rect2) -> float:
	var key := src.position
	if _top_cache.has(key):
		return _top_cache[key]
	if _towers_img == null:
		_towers_img = TEX_TOWERS.get_image()
	var top := 0
	if _towers_img != null:
		top = int(src.size.y) - 1
		for y in int(src.size.y):
			var hit := false
			for x in int(src.size.x):
				if _towers_img.get_pixel(int(src.position.x) + x, int(src.position.y) + y).a > 0.1:
					hit = true
					break
			if hit:
				top = y
				break
	_top_cache[key] = float(top)
	return float(top)


## 버튼·정보창 아이콘: 그림 전체를 r 안에 맞춘다
func _tower_icon(type: String, lv: int, branch: String, col: int, r: Rect2, tint := Color.WHITE) -> void:
	var mk := 0 if lv <= 1 else (1 if lv == 2 else (2 if branch == "a" else 3))
	var k := 2.0 if r.size.x >= TW.x * 2.0 and r.size.y >= TW.y * 2.0 else 1.0
	if k < 2.0 and (r.size.y < TW.y or r.size.x < TW.x):
		_tower_head(type, col, r, tint)
		return
	var size := TW * k
	draw_texture_rect_region(TEX_TOWERS, Rect2(_ev(r.position + (r.size - size) * Vector2(0.5, 1.0)), size), _tower_src(type, mk, col), tint)


func _enemy_icon(type: String, r: Rect2, tint := Color.WHITE) -> void:
	var look: Array = GData.ENEMIES[type]["look"]
	var t := tint
	if str(look[1]) != "":
		t = tint * Color.WHITE.lerp(Color(str(look[1])), 0.55)
	var k := minf(r.size.x / EW.x, r.size.y / EW.y)
	var size := EW * k
	draw_texture_rect_region(TEX_ENEMIES, Rect2(r.position + (r.size - size) * 0.5, size), Rect2(int(look[0]) * EW.x, 0, EW.x, EW.y), t)


## 적 그림 한 칸의 화면 배율
func _enemy_px(type: String) -> float:
	return (CELL / TILE) * (0.75 if type == "mini" else 1.0)


func _gate_badge(center: Vector2, e: int) -> void:
	var w := 30.0
	var h := 12.0
	var pts := PackedVector2Array([center + Vector2(-w, 0), center + Vector2(-w + 9, -h), center + Vector2(w - 9, -h), center + Vector2(w, 0), center + Vector2(w - 9, h), center + Vector2(-w + 9, h)])
	draw_colored_polygon(pts, Color("2A1E12"))
	pts.append(pts[0])
	_ppoly(pts, AMBER, 2.0, true)
	var ic := center + Vector2(-11, 0)
	if e == 0:
		var star := PackedVector2Array()
		for k in 10:
			star.append(ic + Vector2.from_angle(-PI * 0.5 + TAU * k / 10.0) * (7.0 if k % 2 == 0 else 3.0))
		draw_colored_polygon(star, AMBER)
	elif e == 1:
		_parc(ic + Vector2(2, 0), 6.5, PI * 0.62, PI * 1.38, 14, AMBER, 2.2, true)
	else:
		draw_colored_polygon(PackedVector2Array([ic + Vector2(2, -8), ic + Vector2(-5, 1), ic + Vector2(-1, 1), ic + Vector2(-3, 8), ic + Vector2(5, -2), ic + Vector2(1, -2)]), AMBER)
	_t(center + Vector2(9, -10), str(e + 1), T.STRONG, AMBER, 1)


# ── 지도 ──

func _p(g: Vector2) -> Vector2:
	return MAP + g * CELL + (Vector2(sin(_tick * 60.0), cos(_tick * 53.0)) * _shake * float(cfg["shake"]) / 30.0).round() * 2.0


## 지도 그림: 픽셀 원본을 칸 배율(칸/19)대로 키운다
func _frame_rect() -> Rect2:
	var tex := _tex(_theme, "base")
	var k := CELL / TILE
	return Rect2(_p(Vector2.ZERO) - GData.ART_ORIGIN * k, tex.get_size() * k)


func _frame_rect_for(theme: int) -> Rect2:
	var tex := _tex(theme, "base")
	var k := CELL / TILE
	return Rect2(MAP - GData.ART_ORIGIN * k, tex.get_size() * k)


## 화면에 보이는 부분만 그린다
func _draw_tex_clip(tex: Texture2D, dst: Rect2, tint := Color.WHITE) -> void:
	var view := Rect2(-_off, get_viewport_rect().size)
	var vis := dst.intersection(view)
	if vis.size.x <= 0 or vis.size.y <= 0:
		return
	var k := dst.size.x / tex.get_size().x
	var src := Rect2((vis.position - dst.position) / k, vis.size / k)
	draw_texture_rect_region(tex, vis, src, tint)


func _draw_ground(theme := -1) -> void:
	var tex := _tex(_theme if theme < 0 else theme, "base")
	_prect(Rect2(-_off, get_viewport_rect().size), Color("1E2A1A"))
	_draw_tex_clip(tex, _frame_rect())


func _draw_grid(m: GMatch) -> void:
	var building := mode.begins_with("build:") or mode.begins_with("move:")
	var editing := mode.begins_with("road:")
	if building:
		var cells := m.tower_cells()
		var trap := mode.begins_with("build:") and bool(GData.tower_stats(mode.substr(6), 1, "")["trap"])
		for y in GData.H:
			for x in GData.W:
				var c := Vector2i(x, y)
				if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(floorf(hover.x) + 0.5, floorf(hover.y) + 0.5)) > _build_range(m) + 0.3:
					continue
				if m.board.can_build(c, cells, m.theme(), trap) == "":
					_corners(_p(Vector2(c)), Color("E8E2CF"))
	if building or editing:
		for r in [GData.LANDMARK] + ([] if m.board.opened else [GData.BLOCKED]):
			var a := _p(Vector2(r.position))
			var b := _p(Vector2(r.end))
			_dashed_rect(Rect2(a, b - a), LAMP)
		_dashed_rect(Rect2(_p(Vector2.ZERO), Vector2(GData.W, GData.H) * CELL), Color(1, 1, 1, 0.5))


## 칸 모서리 꺾쇠 (각 모서리 3픽셀 L자)
func _build_range(m: GMatch) -> float:
	if not mode.begins_with("build:"):
		return 3.0
	var type := mode.substr(6)
	var c := Vector2i(hover)
	return maxf(m.tower_range({"type": type, "lv": 1, "branch": "", "x": c.x, "y": c.y}), 1.5)


func _corners(at: Vector2, col: Color) -> void:
	var s6 := 6.0
	var e := CELL - 2.0
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var o: Vector2 = at + corner * e
		var dx := -1.0 if corner.x > 0 else 1.0
		var dy := -1.0 if corner.y > 0 else 1.0
		draw_rect(Rect2(o + Vector2(minf(0.0, dx * s6) + (0.0 if dx > 0 else 2.0), 0), Vector2(s6, 2)), col)
		draw_rect(Rect2(o + Vector2(0, minf(0.0, dy * s6) + (0.0 if dy > 0 else 2.0)), Vector2(2, s6)), col)


func _draw_zones() -> void:
	var m := s.m
	var th := _theme
	var editing := mode.begins_with("road:") or mode.begins_with("build:")
	# 연못: 설원에서는 얼어 길을 낼 수 있다
	if GData.pond_state(th) == "ice":
		for r in GData.PONDS:
			var on_road := false
			for p in m.board.paths:
				for c in p:
					if (r as Rect2i).has_point(c):
						on_road = true
			if on_road or editing:
				_zone_cells(r, Color("BFE8F7"), Color("5FC7EA"), "얼음 · 길만 · 빙판 가속", Vector2i(0, 2), on_road)
	for c in m.ice_t:      # 보스가 남긴 빙판 자국
		var a := _p(Vector2(c))
		_prect(Rect2(a + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), Color("BFE8F7", 0.55))
	# 사막: 옛 도로는 자재 없이 길을 낼 수 있다
	if th >= 2:
		for r in GData.OLD_ROADS:
			var a := _p(Vector2(r.position))
			var b := _p(Vector2(r.end))
			_dashed_rect(Rect2(a, b - a), Color("FFE9A8"))
			if editing:
				_zone_tag(_tag_spot(r), "옛 도로 · 자재 0", Color("FFE9A8"))
	# 화산부터: 균열 칸을 지나는 적은 지속 피해
	if th >= 3:
		for c in GData.CRACKS:
			var a := _p(Vector2(c))
			var live := m.board.is_path(c)
			_prect(Rect2(a + Vector2(4, 4), Vector2(CELL - 8, CELL - 8)), Color(FIRE, 0.75 if live else 0.35))
			_prect(Rect2(a + Vector2(8, 8), Vector2(CELL - 16, CELL - 16)), Color("FFB347", (0.6 + 0.25 * sin(_tick * 3.0 + c.x + c.y)) * (1.0 if live else 0.5)))
			if editing:
				_prect(Rect2(a - Vector2(CELL, CELL), Vector2(CELL * 3, CELL * 3)), Color(LAMP, 0.6), false, 1.0)
		if editing:
			_zone_tag(_p(Vector2(GData.CRACKS[0]) + Vector2(0.5, -0.6)), "균열 · 지속 피해 · 옆 칸 건설 금지", Color("FFE08A"))
	# 사막: 이번 웨이브 모래바람 (준비 단계에 공개)
	var spot := m.sand_spot()
	if spot.x > -50:
		var center := _p(spot)
		var radius := GData.SAND_RADIUS * CELL
		_dash_ring(center, radius, Color("E8C35A"), 2.0)
		for i in 5:
			var y := -radius * 0.6 + i * radius * 0.3
			var half := sqrt(maxf(radius * radius - y * y, 0.0)) * 0.72
			var drift := fmod(_tick * 9.0 + i * 7.0, 14.0) - 7.0
			_pline(center + Vector2(-half + drift, y), center + Vector2(half + drift, y), Color("8C673A", 0.55), 1.4)
		_dash_ring(center, radius, Color("FFE9A8"), 4.0 if bool(cfg["thick"]) else 2.0)
		_zone_tag(center + Vector2(0, radius + 12), "모래바람 · 사거리 -25%", Color("FFE9A8"))


func _zone_cells(r: Rect2i, fill: Color, edge: Color, label: String, _icon_cell: Vector2i, tag := true) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var at := _p(Vector2(x, y))
			_prect(Rect2(at + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), Color(fill, 0.82))
			if fill == FIRE:
				_prect(Rect2(at + Vector2(6, 6), Vector2(CELL - 12, CELL - 12)), Color("FFB347", 0.72 + 0.2 * sin(_tick * 3.0 + x + y)))
			else:
				var c := at + Vector2(CELL, CELL) * 0.5
				_ppoly(PackedVector2Array([c + Vector2(-5, -2), c + Vector2(0, 3), c + Vector2(5, -2)]), Color("3F8FB0"), 1.6, true)
	var a := _p(Vector2(r.position))
	var b := _p(Vector2(r.end))
	_dashed_rect(Rect2(a, b - a), edge)
	if bool(cfg["thick"]):
		_dashed_rect(Rect2(a, b - a).grow(1.5), edge)
		_dashed_rect(Rect2(a, b - a).grow(-1.5), edge)
	if tag:
		_zone_tag(_tag_spot(r), label, edge)


## 구역 이름표 자리: 위·아래·왼쪽·오른쪽 중 길도 포탑도 없는 쪽
func _tag_spot(r: Rect2i) -> Vector2:
	var m := s.m
	var cells := m.tower_cells()
	var mid := Vector2(r.position) + Vector2(r.size) * 0.5
	var tries := [Vector2(mid.x, r.end.y + 0.5), Vector2(mid.x, r.position.y - 0.5), Vector2(r.position.x - 2.2, mid.y), Vector2(r.end.x + 2.2, mid.y)]
	for p in tries:
		var free := true
		for dx in range(-2, 3):
			var c := Vector2i(int(p.x) + dx, int(p.y))
			if m.board.is_path(c) or cells.has(c):
				free = false
		if free:
			return _p(p)
	return _p(tries[0])


func _zone_tag(center: Vector2, text: String, edge: Color) -> void:
	var w := _sz(text, T.LABEL).x + 14
	var x := clampf(center.x - w * 0.5, MAP.x, MAP.x + GData.W * CELL - w)
	draw_style_box(_box(Color(0.07, 0.08, 0.09, 0.92), edge, 2), Rect2(x, center.y - 10, w, 20))
	_t(Vector2(x + 7, center.y - 9), text, T.LABEL, Color.WHITE)


var _mini_clip := false


func _draw_road(path_in: Array, theme := -1, broken := false) -> void:
	var px: Array = GData.THEMES[_theme if theme < 0 else theme]["px"]
	var path := path_in
	if not path_in.is_empty():      # 입구는 맵 밖에서 들어오는 것처럼 가장자리 너머로 잇는다
		var g: Vector2i = path_in[0]
		var out := Vector2i(-1 if g.x == 0 else (1 if g.x == GData.W - 1 else 0), 0)
		if out == Vector2i.ZERO:
			out = Vector2i(0, -1 if g.y == 0 else (1 if g.y == GData.H - 1 else 0))
		if out != Vector2i.ZERO:
			path = [g + out * 3, g + out * 2, g + out] + path_in
	if _mini_clip:
		path = path.filter(func(c): return c.x >= 0 and c.y >= 0 and c.x < GData.W and c.y < GData.H)
	var on := {}
	for c in path:
		on[c] = true
	var p := CELL / TILE      # 픽셀 한 칸
	var road_a := Color(str(px[0]))
	var road_b := Color(str(px[1]))
	var paint := Color(str(px[2]))
	var curb := Color(str(px[3]))
	if broken:
		road_a = road_a.lerp(Color("B83A2B"), 0.45)
		road_b = road_b.lerp(Color("B83A2B"), 0.45)
	for c in path:
		var a := _p(Vector2(c)).round()
		var r := Rect2(a, Vector2(CELL, CELL))
		_prect(r, road_b)
		_prect(Rect2(a, Vector2(CELL, p)), road_a)      # 판 이음매
		_prect(Rect2(a, Vector2(p, CELL)), road_a)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if on.has(c + d):
				continue
			var edge: Rect2
			var line: Rect2
			match d:
				Vector2i.LEFT:
					edge = Rect2(a, Vector2(p, CELL))
					line = Rect2(a + Vector2(p, 0), Vector2(p, CELL))
				Vector2i.RIGHT:
					edge = Rect2(a + Vector2(CELL - p, 0), Vector2(p, CELL))
					line = Rect2(a + Vector2(CELL - 2 * p, 0), Vector2(p, CELL))
				Vector2i.UP:
					edge = Rect2(a, Vector2(CELL, p))
					line = Rect2(a + Vector2(0, p), Vector2(CELL, p))
				_:
					edge = Rect2(a + Vector2(0, CELL - p), Vector2(CELL, p))
					line = Rect2(a + Vector2(0, CELL - 2 * p), Vector2(CELL, p))
			_prect(line, paint)
			_prect(edge, curb)


func _draw_chevrons(path: Array, col := Color(0.1, 0.08, 0.05, 0.8)) -> void:
	var marks: Array = [1.0, 2.6, path.size() - 2.4]
	if mode.begins_with("road:"):      # 경로 확인 중에는 전체 방향을 보여 준다
		marks = []
		var k := 1.0
		while k < path.size() - 1:
			marks.append(k)
			k += 2.0
	for d in marks:
		var a := Board.pos_on(path, float(d))
		var dir := (Board.pos_on(path, float(d) + 0.08) - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		var p := _p(a)
		_ppoly(PackedVector2Array([p - dir * 3 + n * 4, p + dir * 2, p - dir * 3 - n * 4]), col, 1.6, true)


func _draw_over(theme := -1) -> void:
	_draw_tex_clip(_tex(_theme if theme < 0 else theme, "over"), _frame_rect())


## 체력이 줄면 연기·경고등·외벽 손상 (테마 장식과 별개)
func _draw_castle_damage(m: GMatch) -> void:
	var ratio := float(m.hp) / GData.CASTLE_HP
	if ratio >= 0.75:
		return
	var r := GData.CASTLE
	var at := _p(Vector2(r.position))
	var size_px := Vector2(r.size) * CELL
	_ppoly(PackedVector2Array([at + size_px * Vector2(0.14, 0.2), at + size_px * Vector2(0.24, 0.32), at + size_px * Vector2(0.18, 0.42)]), Color(0.05, 0.05, 0.05, 0.9), 1.6)
	if ratio < 0.5:
		_ppoly(PackedVector2Array([at + size_px * Vector2(0.86, 0.62), at + size_px * Vector2(0.76, 0.72), at + size_px * Vector2(0.82, 0.86)]), Color(0.05, 0.05, 0.05, 0.9), 1.6)
		var blink := 0.45 + 0.55 * absf(sin(_tick * 4.0))
		_pcircle(at + size_px * Vector2(0.5, 0.06), 3.2, Color(LAMP, blink))
	if not fx_low:
		var puffs := 3 if ratio >= 0.5 else 6
		for i in puffs:
			var k := fmod(_tick * 0.45 + i / float(puffs), 1.0)
			var p := at + size_px * Vector2(0.3 + 0.08 * i, 0.2) + Vector2(sin(k * 5.0 + i) * 5.0, -k * 26.0)
			_pcircle(p, 3.0 + k * 6.0, Color(0.16, 0.16, 0.16, 0.42 * (1.0 - k)))


## 환경 움직임. 수에 상한을 두고, 낮은 효과 설정에서는 더 줄인다
func _draw_env() -> void:
	var id := str(GData.THEMES[_theme]["id"])
	var f := FRAME
	var scale_n := 0.3 if fx_low else 1.0
	match id:
		"snow":
			for i in int(46 * scale_n):
				var x := fposmod(i * 73.3 + sin(_tick * 0.7 + i) * 12.0 + _tick * 9.0, f.size.x)
				var y := fposmod(i * 41.7 + _tick * (26.0 + i % 5 * 5.0), f.size.y)
				_pcircle(f.position + Vector2(x, y), 1.0 + (i % 3) * 0.5, Color(1, 1, 1, 0.68))
		"sand":
			for i in int(28 * scale_n):
				var x := fposmod(i * 91.0 + _tick * (70.0 + i % 4 * 18.0), f.size.x)
				var y := fposmod(i * 37.3, f.size.y)
				var p := f.position + Vector2(x, y)
				_pline(p, p + Vector2(minf(14.0, f.end.x - p.x), 0.5), Color("F0DCA8", 0.34), 1.0)
		"lava":
			for i in int(24 * scale_n):
				var k := fmod(_tick * (0.12 + i % 4 * 0.03) + i * 0.137, 1.0)
				var x := fposmod(i * 83.1 + sin(k * 7.0 + i) * 8.0, f.size.x)
				var y := f.size.y * (1.0 - k)
				_pcircle(f.position + Vector2(x, y), 1.4, Color(1.0, 0.55 + 0.3 * (1.0 - k), 0.2, 0.85 * (1.0 - k)))
		"ghost":
			if not fx_low:
				for i in 6:      # 낮은 안개는 길 바깥쪽 위아래로만 흐른다
					var top := i % 2 == 0
					var y := (f.position.y + 18.0 + i * 5.0) if top else (f.end.y - 18.0 - i * 5.0)
					var x := f.position.x + fposmod(i * 151.0 + _tick * (9.0 + i), f.size.x + 180.0) - 90.0
					var w := minf(90.0, minf(x - f.position.x + 90.0, f.end.x - x))
					if w > 8.0:
						_prect(Rect2(clampf(x - w * 0.5, f.position.x, f.end.x), y - 7, minf(w, f.end.x - clampf(x - w * 0.5, f.position.x, f.end.x)), 14), Color(0.75, 0.9, 0.85, 0.07))
			for i in int(12 * scale_n):
				var k := fmod(_tick * 0.09 + i * 0.21, 1.0)
				_pcircle(f.position + Vector2(fposmod(i * 113.0 + sin(k * 6.0) * 10.0, f.size.x), f.size.y * k), 1.2, Color("9FF0D0", 0.5 * sin(k * PI)))
		_:
			if not fx_low:
				for i in 7:
					var k := fmod(_tick * 0.08 + i * 0.17, 1.0)
					_pcircle(f.position + Vector2(fposmod(i * 139.0 + k * 90.0, f.size.x), fposmod(i * 83.0, f.size.y)), 2.0 + k * 3.0, Color(0.72, 0.62, 0.44, 0.2 * sin(k * PI)))


## 공통 가림 효과 + 도착 테마 색
func _draw_transition() -> void:
	if _trans_t <= 0.0:
		return
	var t := 1.0 - _trans_t / TRANSITION
	var p := clampf((t - 0.16) / 0.8, 0.0, 1.0)
	var col := Color(str(GData.THEMES[_theme_goal]["wipe"]))
	var left := lerpf(-1.25, 1.0, p)
	var a := FRAME.position.x + FRAME.size.x * clampf(left, 0.0, 1.0)
	var b := FRAME.position.x + FRAME.size.x * clampf(left + 1.25, 0.0, 1.0)
	if b > a:
		_prect(Rect2(a, FRAME.position.y, b - a, FRAME.size.y), Color(col, 0.97))
		for i in 18:
			var y := FRAME.position.y + fposmod(i * 37.0, FRAME.size.y)
			var x0 := lerpf(a, b, fposmod(i * 0.37 + t * 2.0, 1.0))
			_pline(Vector2(x0, y), Vector2(minf(x0 + 70.0, b), y), Color(1, 1, 1, 0.3), 1.5)
	_banner("%s 도착" % GData.THEMES[_theme_goal]["name"], AMBER)


## 화면에 보일 미리보기들: 지금 끌고 있는 선, 그다음 확정 전 미리보기(자리마다)
func _draft_data(m: GMatch) -> Dictionary:
	if not _trail.is_empty():
		var tp := _trail_path(m)
		var e := int(_trail["e"])
		if tp.is_empty():
			var partial: Array = m.board.paths[e].slice(0, int(_trail["i"]) + 1)
			partial.append_array(_trail["cells"])
			return {"e": e, "path": partial, "seat": s.seat, "live": true, "open": true}
		var r := m.check_route(s.seat, e, tp)
		return {"e": e, "path": tp, "seat": s.seat, "live": true, "cost": int(r.get("cost", 0)), "err": str(r.get("err", ""))}
	if m.drafts.has(s.seat):
		return _draft_of(m, s.seat)
	for k in m.drafts:
		return _draft_of(m, int(k))
	return {}


func _draft_of(m: GMatch, seat: int) -> Dictionary:
	var d: Dictionary = m.drafts[seat]
	return {"e": int(d["e"]), "path": Board.unflat(d["path"]), "seat": seat, "cost": int(d["cost"]), "err": ""}


func _draw_draft(m: GMatch, edit: Dictionary) -> void:
	for k in m.drafts:      # 다른 사람이 그리는 길은 그 사람 색으로 잠겨 보인다
		if int(k) != int(edit.get("seat", -1)):
			var other := _draft_of(m, int(k))
			_draw_draft_one(m, other, Color(OWNER[int(m.players[int(k)].get("col", 0)) % 4], 0.8))
	if not edit.is_empty():
		var col := AMBER if str(edit.get("err", "")) == "" else LAMP
		_draw_draft_one(m, edit, col)


func _draw_draft_one(m: GMatch, edit: Dictionary, col: Color) -> void:
	var path: Array = edit["path"]
	var old: Array = m.board.paths[int(edit["e"])]
	var fresh := []
	for i in path.size():
		if not old.has(path[i]):
			fresh.append(i)
	if fresh.is_empty():
		return
	var from := maxi(int(fresh[0]) - 1, 0)
	var to := mini(int(fresh[-1]) + 1, path.size() - 1)
	var w := CELL * 0.46
	if not bool(edit.get("open", false)):
		for c in old:
			if not path.has(c):
				var a := _p(Vector2(c))
				_prect(Rect2(a + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), Color(0.31, 0.26, 0.2, 0.9))
				_pline(a + Vector2(8, 8), a + Vector2(CELL - 8, CELL - 8), Color.WHITE, 2.4)
				_pline(a + Vector2(CELL - 8, 8), a + Vector2(8, CELL - 8), Color.WHITE, 2.4)
	for i in range(from + 1, to + 1):
		_pline(_p(Vector2(path[i - 1]) + Vector2(0.5, 0.5)), _p(Vector2(path[i]) + Vector2(0.5, 0.5)), WELL, w + 5.0)
	for i in range(from + 1, to + 1):
		_pline(_p(Vector2(path[i - 1]) + Vector2(0.5, 0.5)), _p(Vector2(path[i]) + Vector2(0.5, 0.5)), col, w)
	for i in range(from, to + 1):
		var c := _p(Vector2(path[i]) + Vector2(0.5, 0.5))
		_prect(Rect2(c - Vector2(w, w) * 0.5, Vector2(w, w)), col)
	for i in range(from + 1, to + 1):
		_pdash(_p(Vector2(path[i - 1]) + Vector2(0.5, 0.5)), _p(Vector2(path[i]) + Vector2(0.5, 0.5)), WELL, 2.0, 6.0)
	var mv: Array = []
	if m.drafts.has(int(edit.get("seat", -1))) and not bool(edit.get("live", false)):
		mv = m.drafts[int(edit["seat"])].get("moves", [])
	for row in mv:      # 길을 막던 내 포탑이 옮겨 갈 자리
		var a := _p(Vector2(int(row[1]), int(row[2])))
		_dashed_rect(Rect2(a + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), AMBER)


func _ab_marker(at: Vector2, label: String) -> void:
	_pcircle(at, 13.0, Color("2A1E12"))
	_parc(at, 13.0, 0, TAU, 24, AMBER, 2.4, true)
	_t(at + Vector2(0, -9), label, T.STRONG, AMBER, 1)


func _draw_ab(m: GMatch) -> void:
	if _trail.is_empty():
		return
	var e := int(_trail["e"])
	var a: Vector2i = m.board.paths[e][int(_trail["i"])]
	_ab_marker(_p(Vector2(a) + Vector2(0.5, 0.5)), "A")
	var cells: Array = _trail["cells"]
	if not cells.is_empty():
		_ab_marker(_p(Vector2(cells[-1]) + Vector2(0.5, 0.5)), "B")


## 길을 그리는 동안 왼쪽 아래 자재 계기: 지금 → 확정하면
func _draw_mat_gauge(m: GMatch) -> void:
	if not mode.begins_with("road:"):
		return
	var mat := int(m.players[s.seat]["mat"])
	var edit := _draft_data(m)
	var cost := 0 if edit.is_empty() or bool(edit.get("open", false)) else int(edit.get("cost", 0))
	var after := clampi(mat - cost, 0, GData.MAT_MAX)
	var rd: Rect2 = _ly()["road"]
	var r := Rect2(rd.position.x, rd.end.y + 4, rd.size.x, 40)
	_nine(r, "panel_dark")
	for k in GData.MAT_MAX:
		var lit := k < mat
		var spend := k >= after and k < mat
		var col := (AMBER if spend else Color("C9A15F")) if lit else Color(0.3, 0.32, 0.35)
		if cost < 0 and k >= mat and k < after:
			col = OK_GREEN
		_prect(Rect2(r.position + Vector2(8 + k * 8, 14), Vector2(6, 12)), col)
	_t(Vector2(r.end.x - 8, r.position.y + 8), "%d→%d" % [mat, after] if cost != 0 else str(mat), T.LABEL, INK, 2)


func _draw_draft_info(m: GMatch, edit: Dictionary) -> void:
	if edit.is_empty():
		return
	var path: Array = edit["path"]
	var e := int(edit["e"])
	var old: Array = m.board.paths[e]
	var seat := clampi(int(edit.get("seat", s.seat)), 0, m.players.size() - 1)
	var who: Dictionary = m.players[seat]
	var mat := int(m.players[s.seat]["mat"])
	if bool(edit.get("open", false)):
		return
	var err := str(edit.get("err", ""))
	var cost := int(edit.get("cost", 0))
	var join := ""
	for o in m.board.paths.size():
		if o != e and not m.board.paths[e].any(func(c): return m.board.paths[o].has(c)) and path.any(func(c): return m.board.paths[o].has(c)):
			join = " · %d번 길과 합류" % (o + 1)
	var price := ("자재 %d 사용" % cost) if cost > 0 else (("자재 %d 돌려받음" % -cost) if cost < 0 else "자재 0")
	if seat != s.seat:
		return
	var trial: Array = m.board.paths.duplicate()
	trial[e] = path
	var before := 0
	var after := 0
	var label := "전체 포탑 사거리 안 길"
	var ids: Array = [selected] if m.towers.has(selected) else m.towers.keys()
	if m.towers.has(selected):
		var t: Dictionary = m.towers[selected]
		label = "%s %s 사거리 안 길" % [m.players[int(t["owner"])]["name"], GData.TOWERS[t["type"]]["name"]]
	for id in ids:
		var t: Dictionary = m.towers[id]
		if GMatch.is_trap(t) or t["type"] == "signal":
			continue
		var c := Vector2i(int(t["x"]), int(t["y"]))
		var rr := m.tower_range(t)
		before += Board.coverage(c, rr, m.board.paths)
		after += Board.coverage(c, rr, trial)
	if not _trail.is_empty():
		var removed := 0
		for c in old:
			if not path.has(c):
				removed += 1
		var added := 0
		for c in path:
			if not old.has(c):
				added += 1
		var mouse := get_local_mouse_position() - _off
		var lines := ["옛 구간 %d칸 → 새 구간 %d칸   자재 %s" % [removed, added, ("-%d" % cost) if cost > 0 else ("+%d" % -cost)],
			"%s %d → %d칸" % [label, before, after], "%d번 길 %d → %d칸 / 최대 %d" % [e + 1, old.size(), path.size(), m.cap()]]
		var w := 0.0
		for l in lines:
			w = maxf(w, _sz(l, T.LABEL).x)
		var bw := 0.0
		for l in lines:
			bw = maxf(bw, _sz(l, T.LABEL).x)
		var br := Rect2(_ev(mouse + Vector2(22, -30)), _ev(Vector2(bw + 24, 76)))
		br.position.x = minf(br.position.x, 1020 - br.size.x)
		_nine(br, "panel_dark")
		_prect(br.grow(-2), AMBER, false, 2.0)
		for i in lines.size():
			_t(br.position + Vector2(12, 6 + i * 22), lines[i], T.LABEL, INK if i < 2 else SUB)
		return
	pass


func _banner(text: String, col: Color, danger := false) -> void:
	var w := minf(_sz(text, T.LABEL).x + 44, 1000.0)
	var r := Rect2(_ev(Vector2(640 - w * 0.5, _ly()["banner"])), Vector2(_ev(Vector2(w, 0)).x, 36))
	_nine(r, "panel_dark")
	if danger:
		_prect(r.grow(-2), DANGER, false, 2.0)
	_prect(Rect2(r.position + Vector2(12, 14), Vector2(8, 8)), col)
	_tx(Rect2(r.position + Vector2(28, 0), Vector2(r.size.x - 36, r.size.y)), text, T.LABEL, Color("ffd2d3") if danger else INK)


func _draw_tower(m: GMatch, t: Dictionary) -> void:
	var at := _p(Vector2(int(t["x"]), int(t["y"])))
	var owner_col := int(m.players[int(t["owner"])].get("col", 0)) % 4
	var trap := GMatch.is_trap(t)
	var broken := trap and int(t["uses"]) <= 0
	if trap:
		_tower_sprite(t["type"], int(t["lv"]), str(t["branch"]), owner_col, at, CELL, Color(0.55, 0.5, 0.5, 0.8) if broken else Color.WHITE)
	else:
		_tower_sprite(t["type"], int(t["lv"]), str(t["branch"]), owner_col, at, CELL, Color(1.0, 0.6, 0.5) if float(t.get("heat", 0.0)) > 0.0 else Color.WHITE)
	if trap:      # 남은 내구
		var full := float(GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))["uses"])
		var ratio := clampf(float(t["uses"]) / maxf(full, 1.0), 0.0, 1.0)
		_prect(Rect2(at + Vector2(3, CELL - 6), Vector2(CELL - 6, 3)), WELL)
		_prect(Rect2(at + Vector2(3, CELL - 6), Vector2((CELL - 6) * ratio, 3)), AMBER if ratio > 0.3 else LAMP)
		if broken:
			_t(at + Vector2(CELL * 0.5, CELL * 0.2), "수리", T.LABEL, LAMP, 1)
	if float(t.get("heat", 0.0)) > 0.0:
		_t(at + Vector2(CELL * 0.5, -10), "과열", T.LABEL, FIRE, 1)
	if bool(cfg["pattern"]):      # 색 대신 무늬: 주인 기호를 크게
		_tag(at + Vector2(CELL * 0.8, CELL * 0.18), owner_col, 11.0)
	if int(t["id"]) == selected:
		var radius := m.tower_range(t) * CELL
		var center := at + Vector2(CELL, CELL) * 0.5
		_parc(center, radius, 0, TAU, 0, Color.WHITE)
		_corners(at, AMBER)


func _draw_enemy(m: GMatch, en: Dictionary) -> void:
	var path: Array = m.board.paths[int(en["e"])]
	var d: float = _disp.get(int(en["id"]), float(en["dist"]))
	var pos := Board.pos_on(path, d)
	var dir := Board.pos_on(path, d + 0.12) - pos
	var foot := _p(pos) + Vector2(0, CELL * 0.3)
	var unit := _enemy_px(en["type"])
	var size_px := 26.0 * unit
	var center := foot + Vector2(0, -size_px * 0.42)
	var ghost := m.is_ghost(en)
	var look: Array = GData.ENEMIES[en["type"]]["look"]
	_parc(foot, size_px * 0.34, 0, TAU, 18, Color("F4BB60", 0.55), 1.4, true)   # 발밑 사프란 고리 (어떤 바닥에서도 읽힘)
	if str(look[1]) != "":      # 테마 전용 적: 색 고리
		_parc(foot, size_px * 0.42, 0, TAU, 20, Color(str(look[1])), 2.2, true)
	if absf(dir.x) > 0.02:
		_face[int(en["id"])] = -1.0 if dir.x < 0.0 else 1.0
	var face: float = _face.get(int(en["id"]), 1.0)
	var origin := (foot - Vector2(22, 38) * unit * Vector2(face, 1.0)).round()
	draw_set_transform(_off + origin, 0.0, Vector2(face, 1.0))
	var tint := Color(0.72, 1, 0.92, 0.42) if ghost else Color.WHITE
	if str(look[1]) != "":
		tint = tint * Color.WHITE.lerp(Color(str(look[1])), 0.55)
	draw_texture_rect_region(TEX_ENEMIES, Rect2(Vector2.ZERO, EW * unit), Rect2(int(look[0]) * EW.x, 0, EW.x, EW.y), tint)
	draw_set_transform(_off)
	if ghost:
		_dash_ring(center, size_px * 0.52, Color("7FE8D0"), 1.6)
	var ratio: float = clampf(float(en["hp"]) / maxf(float(en["max"]), 1.0), 0.0, 1.0)
	var segs := 8
	var w := 3.0 if size_px < 50 else 5.0
	var left := center + Vector2(-(segs * (w + 1)) * 0.5, -size_px * 0.5 - 3)
	_prect(Rect2(left - Vector2(1, 1), Vector2(segs * (w + 1) + 1, 5)), WELL)
	var col := OK_GREEN if ratio > 0.5 else (AMBER if ratio > 0.25 else LAMP)
	var lit := ceili(ratio * segs)
	for k in lit:
		_prect(Rect2(left + Vector2(k * (w + 1), 0), Vector2(w, 3)), col)
	var chip := 4.0 * CELL / TILE
	var n := 0
	for k in GData.STATUS_ORDER:
		if not (en.get("st", {}) as Dictionary).has(k) or n >= 3:
			continue
		var cp := _ev(left + Vector2(n * (chip + 2), -chip - 4))
		_prect(Rect2(cp - Vector2(2, 2), Vector2(chip + 4, chip + 4)), OUTLINE)
		_prect(Rect2(cp, Vector2(chip, chip)), Color(str(GData.STATUS[k]["col"])))
		n += 1
	if float(en["slow"]) > 0.0 and n < 3:
		_icon(Vector2i(0, 0), Rect2(center + Vector2(size_px * 0.22, -size_px * 0.5 - 2), Vector2(13, 13)))
	if float(en.get("stun", 0.0)) > 0.0:      # 멈춤
		for i in 3:
			_prect(Rect2(_ev(center + Vector2(-8 + i * 8, -size_px * 0.5 - 12 - (i % 2) * 4)), Vector2(4, 4)), Color("F2D640"))
	if float(en.get("sh", 0.0)) > 0.0:      # 수송차 보호막
		_parc(center, size_px * 0.58, 0, TAU, 20, Color("E9B935", 0.8), 1.8, true)


func _draw_fx() -> void:
	for f in _fxs:
		var k: float = float(f["t"]) / float(f["life"])
		match str(f["k"]):
			"shot":
				var a := _p(f["a"] * 1.0)
				var b := _p(f["b"] * 1.0)
				match str(f["ty"]):
					"gun":
						_pline(a, b, Color(1, 0.92, 0.6, k), 1.6)
					"cannon":
						var radius: float = float(f["r"]) * CELL * (1.25 - k * 0.55)
						_pcircle(b, radius * 1.15, Color(1, 0.95, 0.75, k * k * 0.5))
						_pcircle(b, radius, Color(FIRE, k * 0.5))
						_pcircle(b, radius * 0.5, Color(1, 0.86, 0.5, k * 0.8))
						for n in 8:
							var dir := Vector2.from_angle(TAU * n / 8.0)
							_pline(b + dir * radius * 0.9, b + dir * radius * 1.25, Color(FIRE, k), 2.0)
					"cold":
						_pline(a, b, Color(ICE, k), 2.0)
						_pcircle(b, float(f["r"]) * CELL, Color(ICE, k * 0.16))
			"ability":
				var c := _p(f["a"] * 1.0)
				var rr := GData.ABILITY_RADIUS * CELL
				_pcircle(c, rr, Color(ICE, k * 0.3))
				_dash_ring(c, rr * (1.15 - k * 0.15), Color.WHITE, 2.4, k)
			"kill":
				var c := _p(f["a"] * 1.0)
				var big: bool = f["big"]
				var rr := CELL * (0.35 + (1.0 - k) * (1.1 if big else 0.6))
				_parc(c, rr, 0, TAU, 20, Color(1, 0.85, 0.5, k), 2.5 if big else 1.8, true)
				for n in 6:
					var d := Vector2.from_angle(TAU * n / 6.0 + 0.4)
					_pline(c + d * rr * 0.6, c + d * rr * 1.1, Color(1, 0.7, 0.3, k), 2.0)
			"rx":
				var c := _p(f["a"] * 1.0) + Vector2(0, -CELL * 0.9 - (1.0 - k) * 16.0)
				var rd: Dictionary = GData.REACTIONS[str(f["n"])]
				var label := str(rd["name"]) + (" ×2" if bool(f["amp"]) else "")
				var w := _sz(label, T.LABEL).x
				_tx(Rect2(_ev(c - Vector2(w * 0.5, 12)), Vector2(w, 24)), label, T.LABEL, Color(str(rd["col"])))
				var os: Array = f["o"]
				for i in os.size():
					var o := int(os[i])
					if o >= 0 and o < s.m.players.size():
						var dp := _ev(c + Vector2(-8 + i * 10, 14))
						_prect(Rect2(dp, Vector2(8, 8)), OUTLINE)
						_prect(Rect2(dp + Vector2(2, 2), Vector2(4, 4)), OWNER[int(s.m.players[o].get("col", 0)) % 4])
			"puddle":
				var c := _p(f["a"] * 1.0)
				var pw := CELL * 0.7
				_prect(Rect2(_ev(c - Vector2(pw * 0.5, CELL * 0.18)), _ev(Vector2(pw, CELL * 0.36))), Color("2A1E12"))
				_prect(Rect2(_ev(c - Vector2(pw * 0.3, CELL * 0.12)), _ev(Vector2(pw * 0.2, 2))), Color("6A5438"))
			"num":
				if bool(cfg["dmg"]):
					var c := _p(f["a"] * 1.0) + Vector2(0, -CELL * 0.6 - (1.0 - k) * 18.0)
					_t(c + Vector2(1, 1), str(f["n"]), T.STRONG, Color(0, 0, 0, k * 0.7), 1)
					_t(c, str(f["n"]), T.STRONG, Color(1, 0.93, 0.6, k), 1)
			"gate":
				var lane := int(f["e"])
				if lane < s.m.board.paths.size():
					var g := _p(Vector2(s.m.board.paths[lane][0]) + Vector2(0.5, -0.3)) + Vector2(0, -(1.0 - k) * 24.0)
					_t(g + Vector2(1, 1), "-%d" % int(f["n"]), T.BIG, Color(0, 0, 0, k * 0.7), 1)
					_t(g, "-%d" % int(f["n"]), T.BIG, Color(DANGER, k), 1)
			"hit":
				if not bool(cfg["dmg"]):
					continue
				var r := GData.CASTLE
				var at := _p(Vector2(r.position.x + r.size.x, r.position.y)) + Vector2(-6, -8 - (1.0 - k) * 22.0)
				_t(at, "-%d" % int(f["n"]), T.BIG, Color(LAMP, k))


func _dash_ring(center: Vector2, radius: float, col: Color, _w := 2.0, alpha := 1.0) -> void:
	_parc(center, radius, 0.0, TAU, 0, Color(col, alpha))


## 미리보기 포탑: 바둑판 디더(한 칸 건너 2x2 만 칠함)
func _dither_tower(type: String, lv: int, branch: String, col: int, at: Vector2) -> void:
	var mk := 0 if lv <= 1 else (1 if lv == 2 else (2 if branch == "a" else 3))
	var src := _tower_src(type, mk, col)
	var k := CELL / TILE
	var size := TW * k
	var pos := (at + Vector2(CELL * 0.5 - size.x * 0.5, CELL - size.y)).round()
	for yy in int(TW.y):
		for xx in int(TW.x):
			if (xx + yy) % 2 == 1:
				continue
			draw_texture_rect_region(TEX_TOWERS, Rect2(pos + Vector2(xx, yy) * k, Vector2(k, k)), Rect2(src.position + Vector2(xx, yy), Vector2.ONE))


func _draw_pings() -> void:
	for p in s.pings:
		var who := int(p["seat"])
		if _muted.has(who):
			continue
		var idx := PING_ORDER.find(str(p["kind"]))
		var center := _p(Vector2(float(p["x"]), float(p["y"])))
		var size_px := 64.0
		var r := Rect2(_ev(center - Vector2(size_px * 0.5, size_px * 0.62)), Vector2(size_px, size_px))
		draw_texture_rect_region(TEX_ICONS, r, Rect2(maxi(idx, 0) * 128, 192, 128, 128))
		_tag(r.position + Vector2(size_px * 0.585, size_px * 0.255), _col_of_seat(who), 9.0)


func _draw_cursor(m: GMatch) -> void:
	if hover.x < 0:
		return
	var c := Vector2i(hover)
	var at := _p(Vector2(c))
	var center := at + Vector2(CELL, CELL) * 0.5
	if mode.begins_with("build:") or mode.begins_with("move:"):
		var type: String
		var lv := 1
		var branch := ""
		if mode.begins_with("build:"):
			type = mode.substr(6)
		else:
			var t: Dictionary = m.towers.get(int(mode.substr(5)), {})
			if t.is_empty():
				return
			type = t["type"]
			lv = int(t["lv"])
			branch = str(t["branch"])
		var trap := bool(GData.tower_stats(type, 1, "")["trap"])
		var cells := m.tower_cells()
		if mode.begins_with("move:"):
			cells.erase(Vector2i(int(m.towers[int(mode.substr(5))]["x"]), int(m.towers[int(mode.substr(5))]["y"])))
		var ok := m.board.can_build(c, cells, m.theme(), trap) == ""
		var col := AMBER if ok else LAMP
		var st := GData.tower_stats(type, lv, branch)
		st["range"] = m.tower_range({"type": type, "lv": lv, "branch": branch, "x": c.x, "y": c.y})
		_dash_ring(center, float(st["range"]) * CELL, col, 2.0)
		_dither_tower(type, lv, branch, int(m.players[s.seat].get("col", 0)) % 4, at)
		_corners(at, col)
		if not ok:
			var why := m.board.can_build(c, cells, m.theme(), trap)
			if why != "이미 포탑이 있어요":
				_tip(center + Vector2(0, -CELL * 0.95), why)
	elif mode == "ability":
		var p := _p(hover)
		var rr := GData.ABILITY_RADIUS * CELL
		_dash_ring(p, rr, ICE, 2.0)
		_tip(p + Vector2(0, rr + 16), "긴급 냉각 · 반경 %.1f칸 · %d초 · 감속 %d%%" % [GData.ABILITY_RADIUS, int(GData.ABILITY_TIME), roundi(GData.ABILITY_SLOW * 100)])
	elif mode.begins_with("ping:"):
		_parc(_p(hover), CELL * 0.5, 0, TAU, 20, AMBER, 2.0, true)
	elif mode == "" and m.tower_cells().has(c):
		_prect(Rect2(at, Vector2(CELL, CELL)), Color(1, 1, 1, 0.45), false, 1.0)


func _tip(center: Vector2, text: String) -> void:
	var w := _sz(text, T.LABEL).x
	var x := clampf(center.x - w * 0.5, 8, 1272 - w - 8)
	var r := Rect2(_ev(Vector2(x - 10, center.y - 16)), _ev(Vector2(w + 20, 32)))
	_nine(r, "panel_dark")
	_tx(r, text, T.LABEL, INK, 1)


# ── 화면별 그리기 ──

func _draw() -> void:
	_hangul_drawn = 0
	_blueprint()
	match _screen:
		"menu":
			_draw_menu()
		"lobby":
			if s != null:
				_draw_lobby()
		"game":
			if s != null and s.m != null:
				_draw_game()
		"result":
			if s != null:
				_draw_result()
	if _paused or _panel != "":
		_draw_pause()
	if _toast_t > 0.0 and _screen != "game":
		_tip(Vector2(640, 118), _toast)


func _draw_title(at: Vector2, _px: int) -> void:
	_icon(Vector2i(4, 2), Rect2(at + Vector2(0, 4), Vector2(32, 32)))
	_t(at + Vector2(44, 2), "길 좀 막아봐", T.BIG, INK)


func _draw_menu() -> void:
	var v := get_viewport_rect().size
	if GData.LAYOUT != "v2":
		GData.use_layout(2)
	_prect(Rect2(-_off, v), Color("1E2A1A"))
	var keep := _shake
	_shake = 0.0
	CELL = TILE * 2.0
	MAP = (Vector2(880, 380) - Vector2(GData.CASTLE.get_center()) * CELL / 1.0 / 2.0 * 2.0).floor()
	MAP = (MAP / 2.0).floor() * 2.0
	_draw_tex_clip(_tex(0, "base"), _frame_rect_for(0))
	for path in Board.new(2).paths:
		_draw_road(path, 0)
	_draw_tex_clip(_tex(0, "over"), _frame_rect_for(0))
	var demo := [["cannon", Vector2i(13, 5), 0], ["sniper", Vector2i(14, 6), 1], ["gun", Vector2i(18, 6), 0], ["shock", Vector2i(24, 14), 1],
		["cold", Vector2i(27, 17), 0], ["cannon", Vector2i(22, 17), 1], ["gun", Vector2i(16, 8), 1], ["flame", Vector2i(24, 18), 0]]
	for d in demo:
		_tower_sprite(d[0], 2, "", d[2], _p(Vector2(d[1])), CELL)
	_shake = keep
	# 왼쪽 판 + 디더 가장자리
	_prect(Rect2(-_off.x, -_off.y, 380 + _off.x, v.y), Color("1A1917"))
	_dim_screen(Rect2(380, -_off.y, 40, v.y))
	_tx(Rect2(32, 52, 300, 24), "CO-OP ENDLESS DEFENSE", T.LABEL, AMBER)
	_tx(Rect2(32, 80, 320, 40), "길 좀 막아봐", T.BIG, INK)
	_hazard(Rect2(32, 132, 300, 8))
	_tx(Rect2(32, 150, 320, 24), "친구와 길을 바꾸고 포탑을 세워", T.LABEL, INK)
	_tx(Rect2(32, 174, 320, 24), "본부를 지켜요 · 2~4인 협동", T.LABEL, SUB)
	if room != "":
		_t(Vector2(32, 226), "친구의 방에 초대받았어요", T.LABEL, AMBER)
	var r := Rect2(34, 554, 308, 84)
	_nine(r, "panel_steel")
	_tx(Rect2(r.position + Vector2(10, 8), Vector2(r.size.x - 20, 24)), "최고 기록", T.LABEL, SUB)
	if _record.is_empty():
		_tx(Rect2(r.position + Vector2(10, 34), Vector2(r.size.x - 20, 28)), "아직 기록이 없어요", T.BODY, SUB)
	else:
		_tx(Rect2(r.position + Vector2(10, 30), Vector2(r.size.x - 20, 28)), "웨이브 %d · %s" % [int(_record.get("wave", 0)), str(_record.get("theme", "-"))], T.STRONG, AMBER)
		var who := str(_record.get("friend", "-"))
		var line := ("%s와" % who.left(8)) if who != "연습" else "연습 동료와"
		if _record.has("time"):
			line += " · " + _clock2(float(_record["time"]))
		_tx(Rect2(r.position + Vector2(10, 56), Vector2(r.size.x - 20, 24)), line, T.LABEL, SUB)
	_t(Vector2(1270, 10), "v0.4 · 최대 4인", T.LABEL, SUB, 2)
	_draw_plates(menu)
	var f := maxi(_menu_focus, 0)
	if f < menu_items.size() and menu_items[f].visible:
		_prect(Rect2(18, menu_items[f].position.y + 10, 8, 24), AMBER)
	var keys := [["↑↓", "이동"], ["ENTER", "선택"], ["ESC", "뒤로"]]
	var total := 0.0
	for k in keys:
		total += _ev(Vector2(_sz(str(k[0]), T.KEY).x + 12, 0)).x + 8 + _sz(str(k[1]), T.LABEL).x + 20
	var kp := Rect2(_ev(Vector2(1272 - total - 20, 670)), _ev(Vector2(total + 20, 42)))
	_nine(kp, "panel_dark")
	var kx := kp.position.x + 12
	for k in keys:
		_key_chip(Vector2(kx, 680), str(k[0]))
		var w := _ev(Vector2(_sz(str(k[0]), T.KEY).x + 12, 0)).x
		_tx(Rect2(kx + w + 8, 670, 100, 42), str(k[1]), T.LABEL, INK)
		kx += w + 8 + _sz(str(k[1]), T.LABEL).x + 20
	if _code_open:
		_draw_join()


func _clock2(sec: float) -> String:
	var t := int(sec)
	return "%d:%02d" % [t / 60, t % 60]


## 코드로 참가 모달
func _draw_join() -> void:
	_dim_screen()
	var r := Rect2(382, 202, 516, 296)
	_modal(r, "코드로 참가")
	_t(Vector2(400, 246), "방장이 보낸 12자리 코드를 넣어요", T.LABEL, INK)
	_nine(Rect2(398, 282, 482, 54), "panel_well")
	_t(Vector2(400, 342), "붙여넣기 Ctrl+V · 초대 링크도 돼요", T.LABEL, SUB)
	var st := Rect2(400, 372, 478, 42)
	_nine(st, "panel_dark")
	var ok := _code_len == 12
	_prect(Rect2(st.position + Vector2(6, 8), Vector2(6, st.size.y - 16)), OK_GREEN if ok else (LAMP if _code_len > 12 else SUB))
	var msg := "코드 12자리 확인 · 참가를 눌러요" if ok else ("코드가 너무 길어요" if _code_len > 12 else "%d/12자" % _code_len)
	_t(st.position + Vector2(20, 8), msg, T.LABEL, OK_GREEN if ok else (LAMP if _code_len > 12 else SUB))
	_draw_plates(menu)
	_glyph_enter(code_go.position + Vector2(code_go.size.x * 0.5 + 30, 12), AMBER_INK)


func _draw_menu_icons() -> void:
	for i in menu_items.size():
		var b: Button = menu_items[i]
		if not b.visible:
			continue
		var tw := _sz(b.text, T.STRONG).x
		var c := Vector2(b.position.x + b.size.x * 0.5 - tw * 0.5 - 20, b.position.y + 23)
		var col := AMBER_INK if i == 0 else (Color(SUB, 0.6) if b.disabled else INK)
		match i:
			0:
				_pcircle(c + Vector2(-3, -4), 4.0, col, false, 1.6)
				_parc(c + Vector2(-3, 7), 7.0, PI, TAU, 10, col, 1.6)
				_parc(c + Vector2(6, 5), 5.0, PI * 1.2, TAU, 8, col, 1.6)
			1:
				_pcircle(c + Vector2(-4, 0), 4.5, col, false, 1.6)
				_pline(c + Vector2(0, 0), c + Vector2(9, 0), col, 1.6)
				_pline(c + Vector2(7, 0), c + Vector2(7, 4), col, 1.6)
			2:
				_prect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), col, false, 1.6)
				_pcircle(c, 2.0, col)
			3:
				_ppoly(PackedVector2Array([c + Vector2(-4, -7), c + Vector2(6, 0), c + Vector2(-4, 7), c + Vector2(-4, -7)]), col, 1.6)
			4:
				_pcircle(c, 4.0, col, false, 1.6)
				for a in 8:
					var d := Vector2.from_angle(TAU * a / 8.0)
					_pline(c + d * 6.0, c + d * 8.5, col, 1.6)


func _key_chip(at: Vector2, text: String) -> void:
	var w := _ev(Vector2(_sz(text, T.KEY).x + 12, 0)).x
	var r := Rect2(_ev(at), Vector2(w, 22))
	_prect(r, OUTLINE)
	_prect(r, AMBER, false, 2.0)
	_tx(r, text, T.KEY, AMBER, 1)


func _draw_lobby() -> void:
	var v := get_viewport_rect().size
	_hazard(Rect2(-_off.x, -_off.y, v.x, 8))
	_tx(Rect2(22, 16, 200, 40), "방 대기실", T.BIG, INK)
	_tx(Rect2(170, 16, 400, 40), "친구가 다 모이면 시작해요", T.LABEL, SUB)
	var cr := Rect2(942, 14, 328, 46)
	_nine(cr, "panel_dark")
	var code: String = _room_code() if s.is_host or net.code() != "" else "연결 중"
	if s.is_host and net.status() != "hosting":
		code = "여는 중…" if net.status() != "error" else "실패"
	_tx(Rect2(cr.position + Vector2(12, 0), Vector2(80, cr.size.y)), "방 코드", T.LABEL, SUB)
	_tx(Rect2(cr.position + Vector2(100, 0), Vector2(220, cr.size.y)), code.to_upper(), T.STRONG, AMBER)
	# 왼쪽: 방 설정
	var L := Rect2(8, 74, 298, 446)
	_nine(L, "panel_steel")
	_tx(Rect2(L.position + Vector2(10, 8), Vector2(200, 24)), "방 설정", T.LABEL, SUB)
	_tx(Rect2(16, 158, 200, 24), "지도", T.LABEL, SUB)
	_draw_mini(Rect2(16, 188, 282, 184), null)
	var n := s.seats.size()
	_tx(Rect2(16, 374, 280, 24), ("%d인 합류 맵 · 입구 2" % maxi(n, 2)) if n <= 2 else "%d인 네 갈래 맵 · 입구 %d" % [n, n], T.LABEL, INK)
	_tx(Rect2(16, 406, 200, 24), "난이도", T.LABEL, SUB)
	var dd: Array = GData.DIFFICULTY[s.difficulty]
	_tx(Rect2(16, 480, 280, 24), "적 체력 ×%.2f" % float(dd[0]), T.LABEL, SUB)
	# 가운데: 팀원 4칸 + 내 공구함
	for i in GSession.MAX_SEATS:
		_draw_crew(i)
	_draw_lobby_kit()
	# 오른쪽: 채팅
	var ch := Rect2(1010, 74, 260, 446)
	_nine(ch, "panel_steel")
	_prect(Rect2(ch.position + Vector2(10, 12), Vector2(10, 8)), INK)
	_t(ch.position + Vector2(26, 2), "방 채팅", T.LABEL, INK)
	# 아래: 시작 전 확인 · 나가기 · 시작
	_prect(Rect2(-_off.x, 530, v.x, v.y), Color("1E1C1A"))
	_hazard(Rect2(-_off.x, 528, v.x, 6))
	var ck := Rect2(16, 552, 598, 152)
	_nine(ck, "panel_dark")
	_t(ck.position + Vector2(12, 6), "시작 전 확인", T.LABEL, AMBER)
	var lines := []
	lines.append([n >= 2, "팀원 %d명 · %d인 지도" % [n, maxi(n, 2)] if n >= 2 else "팀원이 1명 · 친구를 불러요"])
	lines.append([true, "포탑 카드는 웨이브마다 골라요"])
	var waiting := []
	for i in n:
		if not s.seats[i]["ready"]:
			waiting.append(str(s.seats[i]["name"]))
	lines.append([waiting.is_empty(), "모두 준비 완료" if waiting.is_empty() else "%s 아직 준비 중" % ", ".join(waiting).left(18)])
	for i in lines.size():
		var y := ck.position.y + 40 + i * 34
		_prect(Rect2(ck.position.x + 14, y + 8, 12, 12), OK_GREEN if lines[i][0] else Color("6A6660"))
		_t(Vector2(ck.position.x + 36, y), str(lines[i][1]), T.STRONG, INK if lines[i][0] else SUB)
	_draw_plates(lobby)
	_key_chip(Vector2(764, 618), "ESC")
	var ready_n := 0
	for st in s.seats:
		if st["ready"]:
			ready_n += 1
	var sb := Rect2(start_btn.position, start_btn.size)
	var on := not start_btn.disabled
	var ink := AMBER_INK if on else SUB
	if s.is_host:
		_t(Vector2(sb.get_center().x, sb.position.y + 10), "시작 · 준비 %d/%d" % [ready_n, n], T.BIG, ink, 1)
		_t(Vector2(sb.get_center().x, sb.position.y + 54), "모두 준비하면 방장이 시작", T.LABEL, ink, 1)
	else:
		var st: String = net.status()
		var msg := "방장이 시작하기를 기다려요"
		if st == "error":
			msg = str(net.error_text()).left(20)
		elif s.seat < 0:
			msg = "방에 들어가는 중…"
		_t(Vector2(sb.get_center().x, sb.position.y + 10), "준비 %d/%d" % [ready_n, n], T.BIG, SUB, 1)
		_t(Vector2(sb.get_center().x, sb.position.y + 54), msg, T.LABEL, SUB, 1)
	_t(Vector2(sb.get_center().x, 674), "게임 중 K 로 포탑 카드를 다시 열 수 있어요", T.LABEL, SUB, 1)


func _crew_rect(i: int) -> Rect2:
	return Rect2(322 + i * 170, 74, 162, 236)


func _draw_crew(i: int) -> void:
	var box := _crew_rect(i)
	var at := box.position
	var has := i < s.seats.size()
	if not has:
		_dashed_rect(box, Color("5C5850"))
		var c := box.get_center() + Vector2(0, -30)
		_prect(Rect2(c - Vector2(8, 2), Vector2(16, 4)), INK)
		_prect(Rect2(c - Vector2(2, 8), Vector2(4, 16)), INK)
		_t(Vector2(c.x, c.y + 18), "빈자리", T.STRONG, SUB, 1)
		_t(Vector2(c.x, c.y + 52), "초대 링크로", T.LABEL, SUB, 1)
		_t(Vector2(c.x, c.y + 72), "불러요" if not (s.seats.size() == 3 and i == 3) else "비우면 3인 맵", T.LABEL, SUB, 1)
		return
	var col := int(s.seats[i]["col"])
	_nine(box, "panel_steel")
	_prect(Rect2(at + Vector2(2, 2), Vector2(box.size.x - 4, 6)), OWNER[col % 4])
	if not (i == s.seat and web):
		_tx(Rect2(at + Vector2(10, 12), Vector2(140, 28)), str(s.seats[i]["name"]).left(6), T.STRONG, INK)
	var role := "방장" if i == 0 else "손님"
	if i == s.seat:
		role += " · 나"
	_tx(Rect2(at + Vector2(10, 40), Vector2(140, 24)), role, T.LABEL, SUB)
	for c in 4:
		var r := Rect2(at + Vector2(10 + c * 28, 70), Vector2(24, 24))
		var taken := false
		for k in s.seats.size():
			if k != i and int(s.seats[k]["col"]) == c:
				taken = true
		_prect(r, OUTLINE)
		_prect(r.grow(-2), OWNER[c] if not taken or c == col else Color(OWNER[c].darkened(0.6)))
		if c == col:
			_prect(r.grow(2), INK, false, 2.0)

	if i != s.seat:
		var is_ready: bool = s.seats[i]["ready"]
		var rb := Rect2(at + Vector2(8, 194), Vector2(146, 34))
		_nine(rb, "btn_amber" if is_ready else "btn_normal")
		_tx(rb, "준비 완료" if is_ready else "고르는 중…", T.LABEL, AMBER_INK if is_ready else SUB, 1)


## 내 공구함: 10종 중 5종, 팀원과 겹치면 표시, 팀 전체에서 빠진 종류
func _draw_lobby_kit() -> void:
	var r := Rect2(322, 318, 676, 202)
	_nine(r, "panel_steel")
	_tx(Rect2(r.position + Vector2(10, 8), Vector2(r.size.x - 20, 24)), "포탑은 게임 중에 골라요", T.LABEL, SUB)
	_tx(Rect2(r.position + Vector2(10, 36), Vector2(r.size.x - 20, 28)), "준비가 시작될 때마다 카드 6장 중 4장 · 잠금 1칸 · 다시 뽑기", T.LABEL, INK)
	_tx(Rect2(r.position + Vector2(10, 66), Vector2(r.size.x - 20, 24)), "팀원 포탑과 반응이 맞는 카드엔 그 사람 색으로 표시돼요", T.LABEL, AMBER)
	var col := int(s.seats[maxi(s.seat, 0)]["col"]) % 4 if s.seat >= 0 and s.seat < s.seats.size() else 0
	var pool := GData.unlocked(1)
	for i in pool.size():
		var cell := Rect2(r.position + Vector2(10 + i * 66, 100), Vector2(60, 92))
		_nine(cell, "panel_dark")
		_tower_icon(pool[i], 1, "", col, Rect2(cell.position + Vector2(5, 4), Vector2(50, 50)))
		var st := str(GData.tower_stats(pool[i], 1, "")["st"])
		if st != "":
			_prect(Rect2(cell.position + Vector2(24, 60), Vector2(12, 12)), OUTLINE)
			_prect(Rect2(cell.position + Vector2(26, 62), Vector2(8, 8)), Color(str(GData.STATUS[st]["col"])))


func _dashed_rect(r: Rect2, col: Color) -> void:
	var a := r.position
	var b := r.position + Vector2(r.size.x, 0)
	var c := r.end
	var d := r.position + Vector2(0, r.size.y)
	for seg in [[a, b], [b, c], [c, d], [d, a]]:
		_pdash(seg[0], seg[1], col, 1.5, 6.0)


func _draw_mini(r: Rect2, m) -> void:
	_draw_schematic(r, m)


## 작은 지도 도식: 칸 크기는 짝수 px 정수 (로비는 인원으로, 결과는 경기 상태로)
func _draw_schematic(r: Rect2, m = null) -> void:
	if m == null:
		GData.use_layout(maxi(s.seats.size(), 2))
	var c := floorf(minf(r.size.x / GData.W, r.size.y / GData.H) / 2.0) * 2.0
	var size := Vector2(GData.W, GData.H) * c
	var at := _ev(r.position + (r.size - size) * 0.5)
	_prect(Rect2(at - Vector2(4, 4), size + Vector2(8, 8)), OUTLINE)
	_prect(Rect2(at, size), Color("4E6A34"))
	for rr in GData.RIVERS + GData.PONDS:
		_prect(Rect2(at + Vector2((rr as Rect2i).position) * c, Vector2((rr as Rect2i).size) * c), Color("3E6E8C"))
	for rr in GData.HIGH:
		_prect(Rect2(at + Vector2((rr as Rect2i).position) * c, Vector2((rr as Rect2i).size) * c), Color("6C8A45"))
	var lanes: Array = m.board.paths if m != null else Board.new(GData.lanes_for(s.seats.size())).paths
	var worst := -1
	if m != null and not m.cleared and s.state != "lost":
		worst = _worst_gate(m)
	for e in lanes.size():
		for cell in lanes[e]:
			_prect(Rect2(at + Vector2(cell) * c, Vector2(c, c)), LAMP if e == worst else Color("A8A296"))
	var cs := GData.CASTLE
	_prect(Rect2(at + Vector2(cs.position) * c, Vector2(cs.size) * c), OUTLINE)
	_prect(Rect2(at + Vector2(cs.position) * c + Vector2(2, 2), Vector2(cs.size) * c - Vector2(4, 4)), Color("8C939A"))
	if m != null:
		for id in m.towers:
			var t: Dictionary = m.towers[id]
			var col := int(m.players[int(t["owner"])].get("col", 0)) % 4
			_prect(Rect2(at + Vector2(int(t["x"]), int(t["y"])) * c, Vector2(c, c)), OUTLINE)
			_prect(Rect2(at + Vector2(int(t["x"]), int(t["y"])) * c + Vector2(2, 2), Vector2(c - 4, c - 4)), OWNER[col])


## 새로 열린 입구 (그림에 없는 입구): 경고등 기둥 두 개 + 번호판
func _draw_gate(cell: Vector2i, e: int) -> void:
	var c := _p(Vector2(cell) + Vector2(0.5, 0.5))
	var across := Vector2(1, 0) if cell.y == 0 or cell.y == GData.H - 1 else Vector2(0, 1)
	for side in [-1.0, 1.0]:
		var base: Vector2 = c + across * side * CELL * 0.62
		_prect(Rect2(base + Vector2(-3, -CELL * 0.9), Vector2(6, CELL * 0.9)), Color("24282C"))
		for k in 3:
			_prect(Rect2(base + Vector2(-3, -CELL * 0.9 + 6 + k * 9), Vector2(6, 4)), Color("D9A21B"))
		_pcircle(base + Vector2(0, -CELL * 0.9), 4.0, LAMP)
		_pcircle(base + Vector2(0, -CELL * 0.9), 7.0, Color(LAMP, 0.25 + 0.15 * sin(_tick * 5.0)))
	_gate_badge(c + Vector2(0, -CELL * 1.25), e)


func _draw_game() -> void:
	var m := s.m
	var edit := _draft_data(m)
	_draw_ground()                     # 00~02 외곽·지면·절벽
	for path in m.board.paths:         # 03 길
		_draw_road(path)
		_draw_chevrons(path)
	if m.board.extra < GData.EXTRA_PATHS.size():      # 다음 테마에 열릴 길: 흐린 점선 (그 땅은 지을 수 있다)
		var ex: Array = GData.EXTRA_PATHS[m.board.extra]
		for i in range(1, ex.size()):
			_pdash(_p(Vector2(ex[i - 1]) + Vector2(0.5, 0.5)), _p(Vector2(ex[i]) + Vector2(0.5, 0.5)), Color(1, 1, 1, 0.28), 3.0, 7.0)
	for jn in m.board.junctions():     # 합류 지점: 뚫리면 적이 한꺼번에 온다
		var at := _p(Vector2(jn[0]) + Vector2(0.5, 0.5))
		_dash_ring(at, CELL * 0.62, AMBER, 2.0)
		_zone_tag(at + Vector2(0, -CELL * 0.95), "%d·%d번 합류" % [int(jn[1]) + 1, int(jn[2]) + 1], AMBER)
	_draw_zones()                      # 실제 효과 구역
	_draw_grid(m)
	_draw_draft(m, edit)
	_draw_over()                       # 04~05 작업장·랜드마크·본부·입구
	_draw_castle_damage(m)
	var stand := []      # 서 있는 것은 아래쪽(y)이 큰 것을 나중에 그린다
	for id in m.towers:
		var t: Dictionary = m.towers[id]
		stand.append([float(t["y"]) + (0.0 if GMatch.is_trap(t) else 0.9), 0, t])
	for en in m.enemies:
		var pos := Board.pos_on(m.board.paths[int(en["e"])], float(_disp.get(int(en["id"]), float(en["dist"]))))
		stand.append([pos.y + 0.28, 1, en])
	stand.sort_custom(func(a, b): return a[0] < b[0])
	for row in stand:
		if int(row[1]) == 0:
			_draw_tower(m, row[2])
		else:
			_draw_enemy(m, row[2])
	_draw_fx()
	_draw_env()                        # 07 환경 효과
	_draw_pings()                      # 08 선택·핑·건설 정보
	_draw_ab(m)
	_draw_cursor(m)
	if _flash_t > 0.0:
		_parc(_p(_flash), CELL * (0.8 + 0.25 * sin(_tick * 9.0)), 0, TAU, 28, AMBER, 3.0, true)
	if _paused:
		_prect(Rect2(-_off, get_viewport_rect().size), Color(0.08, 0.09, 0.1, 0.45))
		_draw_vitals(m)
		return
	var boss := {}
	for en in m.enemies:
		if GData.is_boss(en["type"]) and not bool(en.get("cl", false)):
			boss = en
	if not edit.is_empty():
		_draw_draft_info(m, edit)
	if m.phase != "reward" and _draw_tutorial(m):
		pass
	elif not boss.is_empty():
		_boss_bar(boss)
	elif m.phase == "combat" and m.wave % GData.THEME_LEN == 0:
		var bt: String = GData.THEME_BOSS[GData.theme_of(m.wave)]
		_banner("보스 접근 · %s · 도착 시 본부 −15" % GData.ENEMIES[bt]["name"], DANGER, true)
	elif m.phase == "prep" and _summary_t > 0.0 and not m.summary.is_empty():
		_banner(_summary_text(m), AMBER)
	elif _newrx_t > 0.0 and GData.REACTIONS.has(_newrx):
		_banner("새 반응 · %s" % GData.REACTIONS[_newrx]["name"], Color(str(GData.REACTIONS[_newrx]["col"])))
	elif _notice_t > 0.0 and _trans_t <= 0.0:
		var th: Dictionary = GData.THEMES[_theme]
		_banner("%s — %s" % [th["name"], th["desc"]], AMBER)
	if s.host_away:
		_banner("방장이 다른 탭을 보고 있어 게임이 잠시 멈췄어요", DANGER, true)
	_draw_transition()
	if _toast_t > 0.0:
		_tip(Vector2(640, 150), _toast)
	_draw_vitals(m)
	_draw_team(m)
	_draw_side(m)
	_draw_chat()
	_draw_minimap(m)
	_draw_arrows(m)
	_draw_bar(m)
	_draw_plates(hud)
	_draw_bar_art(m)
	_draw_marks(m)
	_draw_kit_marks(m)
	if m.phase == "reward":
		_draw_reward(m)
	_draw_hint(m)
	_draw_quick()
	_draw_wheel()


func _summary_text(m: GMatch) -> String:
	var sm: Dictionary = m.summary
	var leaks: Array = sm.get("leaks", [])
	var total := 0
	var parts := []
	for e in leaks.size():
		total += int(leaks[e])
		if int(leaks[e]) > 0:
			parts.append("%d번 %d" % [e + 1, int(leaks[e])])
	var text := "웨이브 %d 결과 · " % int(sm.get("wave", 0))
	text += ("새어 나간 적 %d (%s)" % [total, " · ".join(parts)]) if total > 0 else "모두 막았어요"
	text += " · +%dG" % int(sm.get("gold", 0))
	if int(sm.get("early", 0)) > 0:
		text += " · 일찍 부르기 +%dG" % int(sm["early"])
	if str(sm.get("reward", "")) != "":
		text += " · 보상: %s" % GData.REWARDS[str(sm["reward"])]
	return text


func _boss_bar(boss: Dictionary) -> void:
	var d: Dictionary = GData.ENEMIES[boss["type"]]
	var r := Rect2(460, _ly()["banner"], 360, 36)
	_prect(r, OUTLINE)
	_prect(r.grow(-2), Color("C0412F"))
	_prect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 2)), Color("E0654F"))
	_skull(r.position + Vector2(12, 8))
	_tx(Rect2(r.position + Vector2(42, 0), Vector2(150, 36)), str(d["name"]), T.LABEL, Color("FFE9E2"))
	var ratio := clampf(float(boss["hp"]) / maxf(float(boss["max"]), 1.0), 0.0, 1.0)
	var cells := 16
	var x0 := r.end.x - 14 - cells * 10
	_prect(Rect2(x0 - 4, r.position.y + 9, cells * 10 + 6, 18), OUTLINE)
	for k in cells:
		_prect(Rect2(x0 + k * 10, r.position.y + 11, 8, 14), Color("FF8A75") if float(k) / cells < ratio else Color("5A1E18"))


func _skull(at: Vector2) -> void:
	var rows := ["01110", "11111", "10101", "11111", "01010"]
	for y in rows.size():
		for x in 5:
			if rows[y][x] == "1":
				_prect(Rect2(at + Vector2(x, y) * 4, Vector2(4, 4)), Color("FFE9E2"))


func _draw_reward(m: GMatch) -> void:
	_dim_screen()
	var r := Rect2(300, 160, 680, 340)
	_nine(r, "panel_steel")
	_prect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, 34)), Color("2A2723"))
	_hazard_tag(r.position + Vector2(8, 10))
	_t(r.position + Vector2(22, 6), "%s 대장을 넘겼어요 · 팀 보상" % GData.THEMES[GData.theme_of(m.wave - 1)]["name"], T.STRONG, INK)
	_t(r.position + Vector2(20, 46), "모두 고르면 다음 준비로 넘어가요 · 동점이면 왼쪽", T.LABEL, SUB)
	var info := {"heal": [Vector2i(1, 2), "본부 수리", "내구도 +10"], "gold": [Vector2i(6, 2), "보급금", "전원 +150골드"], "up": [Vector2i(2, 1), "무료 강화", "전원 1회"]}
	var i := 0
	var voted := 0
	var waiting := []
	for p in m.players:
		if p["online"] and str(p.get("vote", "")) != "":
			voted += 1
		elif p["online"]:
			waiting.append(str(p["name"]))
	for k in GData.REWARDS:
		var c := Rect2(r.position.x + 20 + i * 216, r.position.y + 86, 206, 190)
		var mine: bool = str(m.players[s.seat].get("vote", "")) == k
		_nine(c, "panel_dark")
		if mine:
			_prect(c.grow(-2), Color("3A3024"))
			_prect(c.grow(-2), AMBER, false, 2.0)
		_prect(Rect2(c.position + Vector2(6, 6), Vector2(22, 24)), Color("3A3A3A"))
		_t(c.position + Vector2(17, 4), str(i + 1), T.LABEL, INK, 1)
		var row: Array = info.get(k, [Vector2i(2, 1), str(GData.REWARDS[k]), ""])
		var box := Rect2(c.position + Vector2(c.size.x * 0.5 - 30, 16), Vector2(60, 60))
		_nine(box, "panel_well")
		_icon(row[0], box.grow(-14))
		_t(Vector2(c.get_center().x, c.position.y + 88), str(row[1]), T.STRONG, INK, 1)
		_t(Vector2(c.get_center().x, c.position.y + 118), str(row[2]), T.LABEL, SUB, 1)
		var dots := []
		for p in m.players:
			if str(p.get("vote", "")) == k:
				dots.append(int(p.get("col", 0)) % 4)
		if dots.is_empty():
			_t(Vector2(c.get_center().x, c.position.y + 152), "아직 0표", T.LABEL, SUB, 1)
		else:
			var dx := c.get_center().x - dots.size() * 10
			for j in dots.size():
				_prect(Rect2(dx + j * 20, c.position.y + 156, 14, 14), OUTLINE)
				_prect(Rect2(dx + j * 20 + 2, c.position.y + 158, 10, 10), OWNER[dots[j]])
		reward_btns[k].position = c.position
		reward_btns[k].size = c.size
		i += 1
	var foot := "%d/%d 골랐어요" % [voted, m.online_count()]
	if not waiting.is_empty() and voted > 0:
		foot += " · %s 고르는 중…" % ", ".join(waiting)
	_t(Vector2(640, r.end.y - 44), foot, T.LABEL, AMBER, 1)


## 디더 배경: 2x2 바둑판으로 어둡게
func _dim_screen(r := Rect2()) -> void:
	if _dither == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in 4:
			for x in 4:
				if ((x / 2) + (y / 2)) % 2 == 0:
					img.set_pixel(x, y, Color("0E0D0C"))
		_dither = ImageTexture.create_from_image(img)
	if r.size == Vector2.ZERO:
		r = Rect2(-_off, get_viewport_rect().size)
	draw_texture_rect(_dither, r, true)


## 본부 내구도(왼쪽 위)와 웨이브(가운데 위)
func _ly() -> Dictionary:
	var combat := s != null and s.m != null and s.m.phase != "prep"
	var n := 2 if s == null or s.m == null else s.m.players.size()
	var drawing := mode.begins_with("road:") or (s != null and s.m != null and s.m.drafts.has(s.seat)) or not _trail.is_empty()
	var L: Dictionary = {"four": false, "castle": Rect2(8, 8, 280, 46), "wave": Rect2(500, 8, 278, 46), "mat": Rect2(992, 8, 244, 46),
		"pause": Rect2(1244, 8, 28, 46), "banner": 68.0, "x0": 8.0, "w": 204.0, "top": 114.0, "rx": 1030.0,
		"chat_min": Rect2(8, 456, 204, 40), "chat_max": Rect2(8, 250, 204, 246), "mini": Rect2(8, 504, 204, 108),
		"bar": Rect2(0, 618, 1280, 102), "gold": Rect2(8, 628, 140, 84), "ability": Rect2(154, 632, 76, 78),
		"slot": Vector2(84, 78), "slot_x": 248.0, "slot_y": 632.0, "slot_gap": 92.0, "kit": Rect2(616, 632, 50, 78),
		"ping_x": 780.0, "ping_y": 632.0, "ready": Rect2(1010, 630, 262, 82)}
	var x0: float = L["x0"]
	var w: float = L["w"]
	var top: float = L["top"]
	L["road"] = Rect2(x0, top, w, 152 if drawing else 96)
	L["prop"] = Rect2(x0, (L["road"] as Rect2).end.y + 12, w, 104)
	if combat:
		L["chat_max"] = Rect2(x0, top, w, (L["chat_min"] as Rect2).end.y - top)
	L["chat"] = L["chat_max"] if (chat_open or _chat_typing) else L["chat_min"]
	var rx: float = L["rx"]
	var rw := 1272.0 - rx
	L["team"] = Rect2(rx, top, rw, 44 + n * 26)
	var ry := (L["team"] as Rect2).end.y + 10
	L["side"] = Rect2(rx, ry, rw, 160)
	L["insp"] = Rect2(rx, ry, rw, 300)
	L["call"] = Rect2(rx, 566.0, rw, 40)
	L["hint"] = (L["bar"] as Rect2).position.y - 44
	return L


## 이 자리가 HUD 판 위인지 (지도 클릭이 아님)
func _over_hud(p: Vector2) -> bool:
	if _screen != "game" or s == null or s.m == null:
		return false
	var L := _ly()
	var rects: Array = [L["castle"], L["wave"], L["mat"], L["pause"], L["chat"], L["mini"], L["team"], L["bar"]]
	if s.m.phase == "prep":
		rects.append(L["road"])
		if not _proposal(s.m).is_empty():
			rects.append(L["prop"])
	rects.append(L["insp"] if s.m.towers.has(selected) else _side_rect)
	if _kit_open:
		rects.append(Rect2(230, 394, 794, 218))
	if call_btn.visible:
		rects.append(L["call"])
	for r in rects:
		if (r as Rect2).has_point(p):
			return true
	return false


var _side_rect := Rect2()
var _view_send_t := 0.0
var _arrows: Array = []        # 화면 밖 알림 [{r, g}]


func _minimap_rect() -> Rect2:
	if _screen != "game" or s == null or s.m == null:
		return Rect2()
	return _ly()["mini"]


## 작은 지도 안: 한 칸 = 4px (52칸 맵은 3px)
func _minimap_cell() -> float:
	return 4.0 if GData.W <= 40 else 3.0


func _minimap_origin() -> Vector2:
	var r := _minimap_rect()
	var c := _minimap_cell()
	return _ev(r.get_center() - Vector2(GData.W, GData.H) * c * 0.5)


func _minimap_click(p: Vector2) -> bool:
	var r := _minimap_rect()
	if not r.has_point(p):
		return false
	var g := (p - _minimap_origin()) / _minimap_cell()
	if _zoom == 1:
		_zoom = 2
	_cam_to(g)
	return true


func _arrow_click(p: Vector2) -> bool:
	for a in _arrows:
		if (a["r"] as Rect2).grow(4).has_point(p):
			if _zoom == 1:
				_zoom = 2
			_cam_to(a["g"])
			return true
	return false


func _draw_minimap(m: GMatch) -> void:
	var r := _minimap_rect()
	_nine(r, "panel_steel")
	var c := _minimap_cell()
	var o := _minimap_origin()
	_prect(Rect2(o - Vector2(2, 2), Vector2(GData.W, GData.H) * c + Vector2(4, 4)), OUTLINE)
	_prect(Rect2(o, Vector2(GData.W, GData.H) * c), Color("4E6A34"))
	for rr in GData.RIVERS + GData.PONDS:
		_prect(Rect2(o + Vector2((rr as Rect2i).position) * c, Vector2((rr as Rect2i).size) * c), Color("3E6E8C"))
	for rr in GData.HIGH:
		_prect(Rect2(o + Vector2((rr as Rect2i).position) * c, Vector2((rr as Rect2i).size) * c), Color("6C8A45"))
	for p in m.board.paths:
		for cell in p:
			_prect(Rect2(o + Vector2(cell) * c, Vector2(c, c)), Color("A8A296"))
	for e in m.board.paths.size():
		_prect(Rect2(o + Vector2(m.board.paths[e][0]) * c - Vector2(2, 2), Vector2(c + 4, c + 4)), AMBER)
	var cs := GData.CASTLE
	_prect(Rect2(o + Vector2(cs.position) * c, Vector2(cs.size) * c), INK)
	for id in m.towers:
		var t: Dictionary = m.towers[id]
		var col := int(m.players[int(t["owner"])].get("col", 0)) % 4
		_prect(Rect2(o + Vector2(int(t["x"]), int(t["y"])) * c, Vector2(c, c)), OWNER[col])
	for en in m.enemies:
		var pos := Board.pos_on(m.board.paths[int(en["e"])], float(en["dist"]))
		_prect(Rect2(_ev(o + pos * c - Vector2(1, 1)), Vector2(2, 2)), LAMP)
	for pg in s.pings:
		_prect(Rect2(_ev(o + Vector2(float(pg["x"]), float(pg["y"])) * c - Vector2(3, 3)), Vector2(6, 6)), AMBER, false, 2.0)
	# 내가 보는 곳
	var view_a := (Vector2(220, 60) - MAP) / CELL
	var view_b := (Vector2(1022, 612) - MAP) / CELL
	var vr := Rect2(o + view_a * c, (view_b - view_a) * c).intersection(Rect2(o, Vector2(GData.W, GData.H) * c))
	if vr.size.x > 0:
		_prect(Rect2(_ev(vr.position), _ev(vr.size)), Color.WHITE, false, 2.0)
	_view_send_t -= get_process_delta_time()
	if _view_send_t <= 0.0:
		_view_send_t = 0.5
		s.set_view([snappedf(view_a.x, 0.5), snappedf(view_a.y, 0.5), snappedf(view_b.x - view_a.x, 0.5), snappedf(view_b.y - view_a.y, 0.5)])
	for k in s.views:      # 팀원이 보고 있는 곳
		if int(k) == s.seat or int(k) >= m.players.size():
			continue
		var v: Array = s.views[k]
		var tr := Rect2(o + Vector2(float(v[0]), float(v[1])) * c, Vector2(float(v[2]), float(v[3])) * c).intersection(Rect2(o, Vector2(GData.W, GData.H) * c))
		if tr.size.x > 0:
			_prect(Rect2(_ev(tr.position), _ev(tr.size)), OWNER[int(m.players[int(k)].get("col", 0)) % 4], false, 2.0)


## 화면 밖 핑·본부 가까운 적은 가장자리 화살표
func _draw_arrows(m: GMatch) -> void:
	_arrows = []
	var area := Rect2(228, 112, 786, 496)
	var targets := []
	for pg in s.pings:
		targets.append([Vector2(float(pg["x"]), float(pg["y"])), OWNER[_col_of_seat(int(pg["seat"])) % 4]])
	var cc := Vector2(GData.CASTLE.get_center())
	for en in m.enemies:
		var pos := Board.pos_on(m.board.paths[int(en["e"])], float(en["dist"]))
		if pos.distance_to(cc) <= 4.5:
			targets.append([pos, LAMP])
			break
	for tg in targets:
		var sp := MAP + Vector2(tg[0]) * CELL
		if area.has_point(sp):
			continue
		var c := area.get_center()
		var d := (sp - c)
		var k := minf(absf(area.size.x * 0.5 / maxf(absf(d.x), 0.01)), absf(area.size.y * 0.5 / maxf(absf(d.y), 0.01)))
		var at := _ev(c + d * minf(k, 1.0))
		var r := Rect2(at - Vector2(16, 16), Vector2(32, 32))
		_prect(r, OUTLINE)
		_prect(r.grow(-2), tg[1])
		_arrow_glyph(r.get_center(), d.normalized(), OUTLINE)
		_arrows.append({"r": r, "g": tg[0]})


func _arrow_glyph(c: Vector2, d: Vector2, col: Color) -> void:
	for k in 4:
		var p := _ev(c + d * (k * 2 - 2))
		var side := Vector2(-d.y, d.x) * (6 - k * 2)
		_prect(Rect2(_ev(p - side) - Vector2(1, 1), Vector2(2, 2)), col)
		_prect(Rect2(_ev(p + side) - Vector2(1, 1), Vector2(2, 2)), col)
	_prect(Rect2(_ev(c + d * 6) - Vector2(1, 1), Vector2(2, 2)), col)


## HUD 버튼 자리 (매 프레임, 배치가 맵마다 다르다)
func _layout_hud() -> void:
	var L := _ly()
	var four: bool = L["four"]
	var pz: Rect2 = L["pause"]
	menu_btn.position = pz.position
	menu_btn.size = pz.size
	var rd: Rect2 = L["road"]
	var bw := rd.size.x - 16
	var small := 44.0
	road_btns["draw"].position = rd.position + Vector2(8, 36)
	road_btns["draw"].size = Vector2(bw - small - 6, 48)
	road_btns["undo"].position = rd.position + Vector2(rd.size.x - 8 - small, 36)
	road_btns["undo"].size = Vector2(small, 48)
	confirm_btn.position = rd.position + Vector2(8, 92)
	confirm_btn.size = Vector2(bw - small - 6, 48)
	cancel_btn.position = rd.position + Vector2(rd.size.x - 8 - small, 92)
	cancel_btn.size = Vector2(small, 48)
	var pr: Rect2 = L["prop"]
	var half_p := floorf((pr.size.x - 30) * 0.55 / 2.0) * 2.0
	accept_btn.position = pr.position + Vector2(16, 44)
	accept_btn.size = Vector2(half_p, 48)
	reject_btn.position = pr.position + Vector2(22 + half_p, 44)
	reject_btn.size = Vector2(pr.size.x - 30 - half_p, 48)
	var ab: Rect2 = L["ability"]
	ability_btn.position = ab.position
	ability_btn.size = ab.size
	var sl: Vector2 = L["slot"]
	for i in slot_btns.size():
		slot_btns[i].position = Vector2(L["slot_x"] + i * L["slot_gap"], L["slot_y"])
		slot_btns[i].size = sl
	var kr: Rect2 = L["kit"]
	build_btns["kit"].position = kr.position
	build_btns["kit"].size = kr.size
	for i in ping_btns.size():
		ping_btns[i].position = Vector2(L["ping_x"] + i * 42, L["ping_y"])
		ping_btns[i].size = Vector2(38, 40)
	quick_btn.visible = false
	var rr: Rect2 = L["ready"]
	ready_btn.position = rr.position
	ready_btn.size = rr.size
	var half := floorf((rr.size.x - 12) * 0.5 / 2.0) * 2.0
	speed_btns[0].position = rr.position
	speed_btns[0].size = Vector2(half, rr.size.y)
	speed_btns[1].position = rr.position + Vector2(half + 12, 0)
	speed_btns[1].size = Vector2(rr.size.x - half - 12, rr.size.y)
	var cr: Rect2 = L["call"]
	call_btn.position = cr.position
	call_btn.size = cr.size
	_place_chat()


func _draw_vitals(m: GMatch) -> void:
	var L := _ly()
	var four: bool = L["four"]
	var r: Rect2 = L["castle"]
	_nine(r, "panel_steel")
	_icon(Vector2i(1, 2), Rect2(r.position + Vector2(8, 7), Vector2(32, 32)))
	var cells := 20
	var lit := ceili(float(m.hp) / GData.CASTLE_HP * cells)
	for k in cells:
		_prect(Rect2(r.position.x + 48 + k * 8, r.position.y + 16, 6, 14), DANGER if k < lit else Color("4A2420"))
	_tx(Rect2(r.position.x, r.position.y, r.size.x - 10, r.size.y), str(m.hp), T.BIG, INK, 2)
	var wv: Rect2 = L["wave"]
	_nine(wv, "panel_steel")
	var step := (m.wave - 1) % GData.THEME_LEN + 1
	var now: Dictionary = GData.THEMES[GData.theme_of(m.wave)]
	var boss := step == GData.THEME_LEN
	_tx(Rect2(wv.position + Vector2(12, 0), Vector2(60, wv.size.y)), "WAVE", T.LABEL, SUB)
	_tx(Rect2(wv.position + Vector2(74, 0), Vector2(60, wv.size.y)), "%02d" % m.wave, T.BIG, AMBER)
	var right := "%s %d/%d" % [now["name"], step, GData.THEME_LEN]
	if m.phase == "combat":
		right = "남은 적 %d" % (m.enemies.size() + m.queued())
	_tx(Rect2(wv.position, Vector2(wv.size.x - 12, wv.size.y)), right, T.LABEL, DANGER if boss or m.phase == "combat" else INK, 2)
	var me: Dictionary = m.players[s.seat]
	var chip: Rect2 = L["mat"]
	_nine(chip, "panel_steel")
	_icon(Vector2i(3, 2), Rect2(chip.position + Vector2(8, 7), Vector2(32, 32)))
	_tx(Rect2(chip.position + Vector2(48, 0), Vector2(80, chip.size.y)), "자재", T.LABEL, INK)
	_tx(Rect2(chip.position, Vector2(chip.size.x - 12, chip.size.y)), "%d/%d" % [int(me.get("mat", 0)), GData.MAT_MAX], T.BIG, AMBER, 2)
	var mouse := get_local_mouse_position() - _off
	if chip.has_point(mouse):
		_tip(Vector2(chip.get_center().x, chip.end.y + 22), "웨이브마다 +%d · 최대 %d" % [GData.MAT_WAVE, GData.MAT_MAX])


## 팀원 (오른쪽 위) + 일시정지 버튼
## 팀원 (오른쪽 위) + 일시정지 버튼
## 팀원: 2인은 오른쪽 위, 4인은 오른쪽 열
func _draw_team(m: GMatch) -> void:
	var L := _ly()
	var r: Rect2 = L["team"]
	_nine(r, "panel_steel")
	_tx(Rect2(r.position + Vector2(10, 8), Vector2(r.size.x - 20, 24)), "팀", T.LABEL, SUB)
	for i in m.players.size():
		var p: Dictionary = m.players[i]
		var row := Rect2(r.position.x + 10, r.position.y + 36 + i * 26, r.size.x - 20, 26)
		var col := int(p.get("col", i)) % 4
		_prect(Rect2(row.position + Vector2(0, 7), Vector2(12, 12)), OUTLINE)
		_prect(Rect2(row.position + Vector2(2, 9), Vector2(8, 8)), OWNER[col])
		_tx(Rect2(row.position + Vector2(20, 0), Vector2(row.size.x - 80, 26)), str(p["name"]).left(6), T.LABEL, INK if p["online"] else SUB)
		var dot := OK_GREEN if (p["ready"] or (m.phase == "reward" and str(p.get("vote", "")) != "")) else Color("4A4640")
		if not p["online"]:
			dot = LAMP
		_prect(Rect2(row.end.x - 66, row.position.y + 10, 8, 8), dot)
		_tx(row, str(int(p["gold"])), T.LABEL, AMBER, 2)


func _team_bottom(m: GMatch) -> float:
	var r: Rect2 = _ly()["team"]
	return r.end.y


## 왼쪽: 길 개조 기회 + 길 담당 도구 / 오른쪽: 다음 테마, 선택한 포탑 또는 다음 웨이브
## 왼쪽: 공사 자재 + 길 고치기 / 오른쪽: 다음 테마, 선택한 포탑 또는 다음 웨이브
func _draw_side(m: GMatch) -> void:
	var L := _ly()
	var me: Dictionary = m.players[s.seat]
	if m.phase == "prep":
		var rd: Rect2 = L["road"]
		_nine(rd, "panel_steel")
		var edit := _draft_data(m)
		var mine_edit: bool = not edit.is_empty() and int(edit.get("seat", -1)) == s.seat
		var head := Rect2(rd.position + Vector2(10, 8), Vector2(rd.size.x - 20, 24))
		_tx(head, "길 고치기", T.LABEL, SUB)
		var err := str(edit.get("err", "")) if mine_edit else ""
		if err != "":
			_tx(head, "막힘", T.LABEL, LAMP, 2)
			if rd.has_point(get_local_mouse_position() - _off):
				_tip(Vector2(rd.get_center().x, rd.end.y + 22), err)
		elif mine_edit and not bool(edit.get("open", false)):
			var cost := int(edit.get("cost", 0))
			_tx(head, ("-%d" % cost) if cost > 0 else ("+%d" % -cost), T.LABEL, AMBER if cost <= int(me["mat"]) else LAMP, 2)
		var prop := _proposal(m)
		if not prop.is_empty():
			var pr: Rect2 = L["prop"]
			_nine(pr, "panel_steel")
			_prect(Rect2(pr.position + Vector2(4, 6), Vector2(4, pr.size.y - 12)), AMBER)
			var who: Dictionary = m.players[int(prop["seat"])]
			_prect(Rect2(pr.position + Vector2(16, 14), Vector2(12, 12)), OUTLINE)
			_prect(Rect2(pr.position + Vector2(18, 16), Vector2(8, 8)), OWNER[int(who.get("col", 0)) % 4])
			var pe := int(prop["e"])
			var after: Array = Board.unflat(prop["path"])
			var d := after.size() - (m.board.paths[pe] as Array).size()
			_tx(Rect2(pr.position + Vector2(36, 8), Vector2(pr.size.x - 44, 24)), "%d번 길 %s%d칸" % [pe + 1, "+" if d >= 0 else "", d], T.LABEL, INK)
			if pr.has_point(get_local_mouse_position() - _off):
				_tip(Vector2(pr.get_center().x, pr.end.y + 22), "%s · %s" % [who["name"], _proposal_reason(m, pe, after)])
	if m.towers.has(selected):
		_draw_inspector(m, _side_top(m))
		_side_rect = _ly()["insp"]
	else:
		_draw_wave_info(m, _side_top(m))


## 버튼 판 위에 올리는 키 표식·기호
func _draw_marks(m: GMatch) -> void:
	if m.phase == "prep":
		var db: Button = road_btns["draw"]
		var r := Rect2(db.position, db.size)
		var on: bool = not db.disabled
		_tx(Rect2(r.position + Vector2(10, 0), Vector2(r.size.x - 44, r.size.y)), "그리기", T.BODY, INK if on else SUB)
		_key_chip(Vector2(r.end.x - 34, r.position.y + 13), "G")
		_glyph_undo(road_btns["undo"].position + road_btns["undo"].size * 0.5, INK if not road_btns["undo"].disabled else SUB)
		if confirm_btn.visible:
			var cr := Rect2(confirm_btn.position, confirm_btn.size)
			var c_on := not confirm_btn.disabled
			_tx(Rect2(cr.position + Vector2(10, 0), Vector2(cr.size.x - 44, cr.size.y)), "확정", T.BODY, AMBER_INK if c_on else SUB)
			_key_chip(Vector2(cr.end.x - 34, cr.position.y + 13), "E")
			_glyph_x(cancel_btn.position + cancel_btn.size * 0.5, INK if not cancel_btn.disabled else SUB)
	if m.towers.has(selected):
		var t: Dictionary = m.towers[selected]
		_draw_insp_buttons(m, t, int(t["owner"]) == s.seat, m.phase == "prep", int(t["lv"]))
	if accept_btn.visible:
		var ar := Rect2(accept_btn.position, accept_btn.size)
		_tx(Rect2(ar.position + Vector2(10, 0), Vector2(ar.size.x - 40, ar.size.y)), "수락", T.BODY, AMBER_INK if not accept_btn.disabled else SUB)
		_key_chip(Vector2(ar.end.x - 30, ar.position.y + 13), "E")
		var rr := Rect2(reject_btn.position, reject_btn.size)
		_tx(rr, "거절", T.BODY, INK, 1)


func _proposal_reason(m: GMatch, e: int, path: Array) -> String:
	var trial: Array = m.board.paths.duplicate()
	trial[e] = path
	var before := 0
	var after := 0
	for id in m.towers:
		var t: Dictionary = m.towers[id]
		if GMatch.is_trap(t) or t["type"] == "signal":
			continue
		var c := Vector2i(int(t["x"]), int(t["y"]))
		before += Board.coverage(c, m.tower_range(t), m.board.paths)
		after += Board.coverage(c, m.tower_range(t), trial)
	if after > before:
		return "포탑이 더 오래 쏴요 +%d" % (after - before)
	if after < before:
		return "사거리 안 길 -%d" % (before - after)
	return "길 모양만 바뀌어요"


## 작은 표식 (도트)
func _hazard_tag(at: Vector2) -> void:
	for k in 3:
		_prect(Rect2(at + Vector2(0, k * 6), Vector2(4, 4)), AMBER)


func _glyph_x(c: Vector2, col: Color) -> void:
	c = _ev(c)
	for k in range(-5, 6, 2):
		_prect(Rect2(c + Vector2(k - 1, k - 1), Vector2(2, 2)), col)
		_prect(Rect2(c + Vector2(k - 1, -k - 1), Vector2(2, 2)), col)


func _glyph_undo(c: Vector2, col: Color) -> void:
	c = _ev(c)
	_prect(Rect2(c + Vector2(-6, -4), Vector2(12, 2)), col)
	_prect(Rect2(c + Vector2(4, -4), Vector2(2, 10)), col)
	_prect(Rect2(c + Vector2(-6, 4), Vector2(12, 2)), col)
	_prect(Rect2(c + Vector2(-4, -8), Vector2(2, 10)), col)
	_prect(Rect2(c + Vector2(-8, -6), Vector2(2, 6)), col)


func _draw_chat() -> void:
	var L := _ly()
	var expanded := chat_open or _chat_typing
	var r: Rect2 = L["chat"]
	var n := s.chat.size()
	if n != _chat_seen:
		_chat_seen = n
		_chat_flash = 5.0
	_chat_flash -= get_process_delta_time()
	_nine(r, "panel_steel")
	_prect(Rect2(r.position + Vector2(10, 14), Vector2(12, 10)), INK)
	_prect(Rect2(r.position + Vector2(12, 24), Vector2(2, 2)), INK)
	if expanded:
		_tx(Rect2(r.position + Vector2(30, 8), Vector2(r.size.x - 40, 24)), "채팅", T.LABEL, SUB)
		return
	if _chat_flash > 0.0 and n > 0:
		var row: Dictionary = s.chat[-1]
		var who := int(row["seat"])
		var x := r.position.x + 30
		if who >= 0:
			_prect(Rect2(x, r.position.y + 16, 8, 8), OWNER[int(row.get("col", _col_of_seat(who))) % 4])
			x += 14
		var text := str(row["text"])
		while text.length() > 1 and _sz(text, T.LABEL).x > r.end.x - x - 8:
			text = text.left(text.length() - 1)
		_tx(Rect2(x, r.position.y, r.end.x - x - 8, r.size.y), text, T.LABEL, INK if who >= 0 else SUB)
	else:
		_tx(Rect2(r.position + Vector2(30, 0), Vector2(r.size.x - 40, r.size.y)), "Enter 채팅", T.LABEL, SUB)


## 조작 안내는 무언가를 고른 순간에만 액션바 바로 위에
func _draw_hint(m: GMatch) -> void:
	var head := ""
	var val := ""
	var sub := ""
	var mouse := get_local_mouse_position() - _off
	if mode.begins_with("build:"):
		var key := mode.substr(6)
		head = str(GData.TOWERS[key]["name"])
		val = str(int(GData.TOWERS[key]["cost"]))
		sub = "클릭 짓기 · 우클릭 취소"
	elif mode == "ability":
		head = "긴급 냉각"
		val = "%d초" % int(GData.ABILITY_TIME)
		sub = "클릭 사용 · 우클릭 취소"
	elif mode.begins_with("road:") and _trail.is_empty():
		head = "길 다시 그리기"
		val = "자재 %d" % int(m.players[s.seat].get("mat", 0))
		sub = "길 위 칸에서 끌기"
	elif mode.begins_with("move:"):
		head = "옮기기"
		sub = "놓을 빈 칸 · 무료"
	elif mode.begins_with("ping:"):
		head = str(GData.PING_KINDS[mode.substr(5)])
		sub = "알릴 곳 클릭"
	elif mode == "":
		# 작업대 위에 마우스: 이름 말풍선
		var me: Dictionary = m.players[s.seat]
		for i in slot_btns.size():
			if slot_btns[i].is_hovered() and i < (me["kit"] as Array).size():
				var k: String = me["kit"][i]
				head = str(GData.TOWERS[k]["name"])
				val = str(int(GData.TOWERS[k]["cost"]))
				sub = str(GData.TOWERS[k]["role"])
		if ability_btn.is_hovered():
			head = "긴급 냉각"
			sub = "전투 중 1회 · 반경 %.1f칸" % GData.ABILITY_RADIUS
		for i in ping_btns.size():
			if ping_btns[i].is_hovered():
				head = str(GData.PING_KINDS[PING_ORDER[i]])
				sub = "누르고 지도 클릭"
		if build_btns["kit"].is_hovered():
			head = "공구함 바꾸기"
			sub = "1웨이브 준비 중, 짓기 전"
	if head == "":
		return
	var w := maxf(_sz(head, T.STRONG).x + _sz(val, T.STRONG).x + 36, _sz(sub, T.LABEL).x + 24)
	var r := Rect2(_ev(mouse + Vector2(24, 14)), _ev(Vector2(w, 64)))
	r.position.x = minf(r.position.x, 1270 - r.size.x)
	r.position.y = minf(r.position.y, 612 - r.size.y)
	_nine(r, "panel_dark")
	var top := Rect2(r.position + Vector2(12, 6), Vector2(r.size.x - 24, 28))
	_tx(top, head, T.STRONG, INK)
	if val != "":
		_tx(top, val, T.STRONG, AMBER, 2)
	_tx(Rect2(r.position + Vector2(12, 34), Vector2(r.size.x - 24, 24)), sub, T.LABEL, SUB)


func _draw_tutorial(m: GMatch) -> bool:
	if _tut < 0 or m.phase == "reward":
		_vis(tut_skip, false)
		return false
	var steps := [["1/3", "공구함에서 포탑을 골라 빈 칸에 지어요"],
		["2/3", "G 로 길 위 칸에서 끌어 길을 다시 그려요"],
		["3/3", "전투가 시작되면 Q 로 긴급 냉각"]]
	var row: Array = steps[_tut]
	var w := _sz(str(row[1]), T.LABEL).x + _sz("ESC 건너뛰기", T.LABEL).x + 100
	var r := Rect2(_ev(Vector2(640 - w * 0.5, _ly()["banner"])), Vector2(_ev(Vector2(w, 0)).x, 36))
	_nine(r, "panel_dark")
	_tx(Rect2(r.position + Vector2(14, 0), Vector2(40, 36)), str(row[0]), T.LABEL, AMBER)
	_tx(Rect2(r.position + Vector2(64, 0), Vector2(w, 36)), str(row[1]), T.LABEL, INK)
	_tx(Rect2(r.position, Vector2(r.size.x - 14, 36)), "ESC 건너뛰기", T.LABEL, SUB, 2)
	_vis(tut_skip, true)
	tut_skip.position = Vector2(r.end.x - _sz("ESC 건너뛰기", T.LABEL).x - 20, r.position.y)
	tut_skip.size = Vector2(_sz("ESC 건너뛰기", T.LABEL).x + 20, 36)
	return true


## 하단 액션바: 골드 → 지원 능력 → 건설 → 핑 → 준비/배속
## 하단 액션바: 골드 → 지원 능력 → 공구함 → 핑 → 준비/배속 (맨 위 4px 위험 띠)
func _draw_bar(m: GMatch) -> void:
	var L := _ly()
	var r: Rect2 = L["bar"]
	_prect(r, Color("1E1C1A"))
	_hazard(Rect2(r.position, Vector2(r.size.x, 6)))
	var me: Dictionary = m.players[s.seat]
	var g: Rect2 = L["gold"]
	_icon(Vector2i(6, 2), Rect2(g.position + Vector2(4, (g.size.y - 32) * 0.5), Vector2(32, 32)))
	_tx(Rect2(g.position + Vector2(44, 0), Vector2(g.size.x - 44, g.size.y)), str(int(me["gold"])), T.BIG, AMBER)
	if g.has_point(get_local_mouse_position() - _off):
		var free := int(me.get("free_up", 0))
		_tip(Vector2(g.get_center().x + 40, g.position.y - 20), ("무료 강화 %d회" % free) if free > 0 else "웨이브마다 +%d" % GData.wave_gold(m.wave))
	if not L["four"]:
		_tx(Rect2(L["ping_x"], L["ping_y"] + 46, 210, 24), "핑 Alt+클릭", T.LABEL, SUB)
	if m.phase == "reward":
		var rr: Rect2 = L["ready"]
		_nine(rr, "btn_disabled")
		_tx(rr, "보상 투표 중", T.BODY, SUB, 1)


func _draw_bar_art(m: GMatch) -> void:
	var L := _ly()
	var me: Dictionary = m.players[s.seat]
	var my_col := int(me.get("col", 0)) % 4
	# 긴급 냉각: 그림 + Q
	var ab := Rect2(ability_btn.position, ability_btn.size)
	var usable: bool = m.phase == "combat" and not bool(me["used"])
	var on := mode == "ability"
	_nine(ab, "panel_steel")
	if usable or on:
		_prect(ab.grow(-2), AMBER, false, 2.0)
	_icon(Vector2i(0, 0), Rect2(ab.position + Vector2((ab.size.x - 32) * 0.5, 8), Vector2(32, 32)), Color.WHITE if usable or on else Color(0.6, 0.6, 0.6))
	_key_chip(Vector2(ab.get_center().x - 11, ab.end.y - 30), "Q")
	# 공구함 칸: 머리 그림 + 번호·값
	var names: Array = me["kit"]
	for i in names.size():
		var b: Button = slot_btns[i]
		var t := Rect2(b.position, b.size)
		var cost := int(GData.TOWERS[names[i]]["cost"])
		var afford := int(me["gold"]) >= cost
		var usable_t: bool = not b.disabled
		var picked: bool = mode == "build:" + str(names[i])
		_nine(t, "panel_steel" if not picked else "panel_dark")
		if picked:
			_prect(t.grow(-2), AMBER, false, 2.0)
		elif b.is_hovered() and usable_t:
			_prect(t.grow(-2), Color("8C939A"), false, 2.0)
		var tint := Color.WHITE if usable_t or (m.phase == "prep" and not afford) else Color(0.55, 0.55, 0.55)
		_tower_head(str(names[i]), my_col, Rect2(t.position + Vector2(4, 4), Vector2(t.size.x - 8, t.size.y - 28)), tint)
		var foot := Rect2(t.position + Vector2(6, t.size.y - 26), Vector2(t.size.x - 12, 22))
		_tx(foot, str(i + 1), T.KEY, SUB)
		_tx(foot, str(cost), T.KEY, (AMBER if afford else LAMP) if m.phase == "prep" else SUB, 2)
		if m.phase != "prep":
			_lock(t.position + Vector2(t.size.x - 12, 10))
		elif str(me["lock"]) == str(names[i]):
			_prect(Rect2(t.position + Vector2(t.size.x - 22, 4), Vector2(18, 18)), AMBER)
			_lock_glyph(t.position + Vector2(t.size.x - 13, 13), AMBER_INK)
		elif lock_btns[i].is_hovered():
			_lock_glyph(t.position + Vector2(t.size.x - 13, 13), SUB)
	var kb := Rect2(build_btns["kit"].position, build_btns["kit"].size)
	var kb_on: bool = not build_btns["kit"].disabled
	_nine(kb, "panel_steel" if not _kit_open else "panel_dark")
	if _kit_open:
		_prect(kb.grow(-2), AMBER, false, 2.0)
	_chevrons(kb.position + Vector2(kb.size.x * 0.5, 26), INK if kb_on else SUB)
	_tx(Rect2(kb.position + Vector2(0, kb.size.y - 26), Vector2(kb.size.x, 22)), "K", T.KEY, INK if kb_on else SUB, 1)
	if _kit_open:
		_draw_kit(m)
	for i in ping_btns.size():
		var pr := Rect2(ping_btns[i].position, ping_btns[i].size)
		var active := mode == "ping:" + str(PING_ORDER[i])
		_nine(pr, "panel_dark" if not active else "panel_amber")
		_icon(Vector2i(i, 1), Rect2(pr.position + Vector2(11, 12), Vector2(16, 16)), PING_COL[i] if not active else AMBER_INK)
	var rr: Rect2 = L["ready"]
	if ready_btn.visible:
		var r_on: bool = me["ready"]
		var cnt := 0
		for p in m.players:
			if p["ready"]:
				cnt += 1
		var col := INK if r_on else AMBER_INK
		_tx(Rect2(rr.position + Vector2(0, 8), Vector2(rr.size.x, 36)), "준비 취소" if r_on else "준비 완료", T.BIG, col, 1)
		_tx(Rect2(rr.position + Vector2(0, rr.size.y - 32), Vector2(rr.size.x, 24)), "SPACE · %d/%d" % [cnt, m.players.size()], T.LABEL, col if not r_on else SUB, 1)
	if m.phase == "combat":
		var votes := m.fast_votes()
		for k in 2:
			var b: Button = speed_btns[k]
			var br := Rect2(b.position, b.size)
			var act := (m.speed == 1) if k == 0 else (m.speed == 2)
			_nine(br, "btn_amber" if act else "btn_normal")
			var c := AMBER_INK if act else INK
			if k == 0 or act:
				_tx(br, "%d배" % (k + 1), T.BIG, c, 1)
			else:
				_tx(Rect2(br.position + Vector2(0, 8), Vector2(br.size.x, 36)), "2배", T.BIG, c, 1)
				_tx(Rect2(br.position + Vector2(0, br.size.y - 32), Vector2(br.size.x, 24)), "%d/%d" % [votes, m.online_count()], T.LABEL, SUB, 1)


## 공구함: 10종 중 5종 (1웨이브 준비 중, 짓기 전에만 바꿀 수 있다)
func _draw_kit(m: GMatch) -> void:
	var me: Dictionary = m.players[s.seat]
	var hand: Array = me["hand"]
	var lock := str(me["lock"])
	var need := GData.KIT_SIZE - (1 if lock != "" else 0)
	var r := Rect2(230, 394, 794, 218)
	_nine(r, "panel_steel")
	var head := Rect2(r.position + Vector2(12, 8), Vector2(r.size.x - 24, 28))
	var title := "포탑 고르기 %d/%d" % [_kit_pick.size(), need]
	if lock != "":
		title += " · 잠금 %s" % GData.TOWERS[lock]["name"]
	_tx(head, title, T.LABEL, INK)
	# 팀 공구함으로 만들 수 있는 반응 수
	var sts := {}
	for i in m.players.size():
		var kit: Array = _kit_pick + ([lock] if lock != "" else []) if i == s.seat else m.players[i]["kit"]
		for k in kit:
			var st := str(GData.tower_stats(k, 1, "")["st"])
			if st != "":
				sts[st] = true
	var rx := {}
	for a in sts:
		for b in sts:
			var name := GData.reaction_of(a, b)
			if name != "":
				rx[name] = true
	_tx(Rect2(head.position + Vector2(_sz(title, T.LABEL).x + 16, 0), Vector2(200, 28)), "· 반응 %d종 가능" % rx.size(), T.LABEL, AMBER)
	# 팀원이 고른 것
	var tx := r.position.x + 12
	var ty := r.position.y + 36
	for i in m.players.size():
		if i == s.seat:
			continue
		var p: Dictionary = m.players[i]
		_prect(Rect2(tx, ty + 7, 10, 10), OWNER[int(p.get("col", i)) % 4])
		var names := []
		for k in p["kit"]:
			names.append(str(GData.TOWERS[k]["name"]).replace("탑", ""))
		var line := " · ".join(names) + ("" if bool(p["picked"]) else " (고르는 중)")
		_tx(Rect2(tx + 16, ty, 380, 24), line, T.LABEL, SUB)
		tx += 16 + minf(_sz(line, T.LABEL).x, 360) + 20
	# 카드 6장
	var my_col := int(me.get("col", 0)) % 4
	var cw := 124.0
	var fresh := GData.fresh_unlocks(m.wave)
	for i in hand.size():
		var k: String = hand[i]
		var c := Rect2(r.position.x + 10 + i * (cw + 6), r.position.y + 64, cw, 146)
		pick_btns[i].position = c.position
		pick_btns[i].size = c.size
		var on := _kit_pick.has(k)
		_nine(c, "panel_dark")
		if on:
			_prect(c.grow(-2), Color("3A3024"))
			_prect(c.grow(-2), AMBER, false, 2.0)
		elif pick_btns[i].is_hovered():
			_prect(c.grow(-2), Color("8C939A"), false, 2.0)
		_tx(Rect2(c.position + Vector2(6, 4), Vector2(20, 20)), str(i + 1), T.KEY, SUB)
		if fresh.has(k):
			_prect(Rect2(c.end.x - 40, c.position.y + 6, 34, 18), AMBER)
			_tx(Rect2(c.end.x - 40, c.position.y + 4, 34, 20), "NEW", T.KEY, AMBER_INK, 1)
		_tower_icon(k, 1, "", my_col, Rect2(c.position + Vector2((cw - 50) * 0.5, 4), Vector2(50, 50)))
		_tx(Rect2(c.position + Vector2(6, 56), Vector2(cw - 12, 24)), str(GData.TOWERS[k]["name"]), T.LABEL, INK)
		var row2 := Rect2(c.position + Vector2(8, 82), Vector2(cw - 16, 24))
		_tx(row2, str(int(GData.TOWERS[k]["cost"])), T.KEY, AMBER, 2)
		var st := str(GData.tower_stats(k, 1, "")["st"])
		if st != "":
			_prect(Rect2(row2.position + Vector2(0, 6), Vector2(12, 12)), OUTLINE)
			_prect(Rect2(row2.position + Vector2(2, 8), Vector2(8, 8)), Color(str(GData.STATUS[st]["col"])))
			_tx(Rect2(row2.position + Vector2(16, 0), Vector2(70, 24)), str(GData.STATUS[st]["name"]), T.LABEL, SUB)
		else:
			_tx(Rect2(row2.position, Vector2(70, 24)), "상태 없음", T.LABEL, Color("6A6660"))
		var fit := _card_fit(m, k)
		if not fit.is_empty():
			var line := str(fit[0])
			while line.length() > 2 and _sz(line, T.LABEL).x > cw - 12:
				line = line.left(line.length() - 1)
			_tx(Rect2(c.position + Vector2(6, 112), Vector2(cw - 12, 24)), line, T.LABEL, fit[1])
	pick_go.position = Vector2(r.end.x - 178, r.position.y + 8)
	pick_go.size = Vector2(166, 48)
	pick_reroll.position = Vector2(r.end.x - 346, r.position.y + 8)
	pick_reroll.size = Vector2(160, 48)


## 카드 글자는 버튼 판 위에
func _draw_kit_marks(m: GMatch) -> void:
	if not _kit_open:
		return
	var me: Dictionary = m.players[s.seat]
	var cost := m.reroll_cost(s.seat)
	_tx(Rect2(pick_reroll.position, pick_reroll.size), "다시 뽑기 %s" % ("무료" if cost == 0 else str(cost)), T.LABEL, INK if not pick_reroll.disabled else SUB, 1)
	var need := GData.KIT_SIZE - (1 if str(me["lock"]) != "" else 0)
	_tx(Rect2(pick_go.position + Vector2(10, 0), Vector2(pick_go.size.x - 50, pick_go.size.y)), "확정", T.BODY, AMBER_INK if _kit_pick.size() == need else SUB)
	_key_chip(pick_go.position + Vector2(pick_go.size.x - 66, 13), "ENTER")


## 카드 아래 한 줄: 팀원 포탑과 만들 반응, 이번 웨이브 적과의 상성
func _card_fit(m: GMatch, k: String) -> Array:
	var st := str(GData.tower_stats(k, 1, "")["st"])
	if st != "":
		for i in m.players.size():
			if i == s.seat:
				continue
			var theirs := {}
			for t in m.players[i]["kit"]:
				theirs[str(GData.tower_stats(t, 1, "")["st"])] = true
			for id in m.towers:
				if int(m.towers[id]["owner"]) == i:
					var tt: Dictionary = m.towers[id]
					theirs[str(GData.tower_stats(tt["type"], int(tt["lv"]), str(tt["branch"]))["st"])] = true
			for o in theirs:
				var rx := GData.reaction_of(st, str(o))
				if rx != "":
					return ["%s · %s" % [GData.REACTIONS[rx]["name"], str(m.players[i]["name"]).left(4)], OWNER_TEXT[int(m.players[i].get("col", i)) % 4]]
	var kinds := {}
	for g in m.wave_plan():
		kinds[str(g[1])] = true
	var s1 := GData.tower_stats(k, 1, "")
	for e in kinds:
		var d: Dictionary = GData.ENEMIES[e]
		if bool(d.get("fireproof", false)) and bool(s1["fire"]):
			return ["%s에 약함" % d["name"], LAMP]
		if float(d["armor"]) >= 4.0 and (str(s1["st"]) == "mag" or float(s1["dmg"]) >= 40.0):
			return ["%s에 강함" % d["name"], OK_GREEN]
		if (d.has("phase") or d.has("burrow")) and k == "signal":
			return ["%s 드러냄" % d["name"], OK_GREEN]
	return []


func _lock_glyph(c: Vector2, col: Color) -> void:
	c = _ev(c)
	_prect(Rect2(c + Vector2(-4, -6), Vector2(8, 2)), col)
	_prect(Rect2(c + Vector2(-4, -6), Vector2(2, 4)), col)
	_prect(Rect2(c + Vector2(2, -6), Vector2(2, 4)), col)
	_prect(Rect2(c + Vector2(-6, -2), Vector2(12, 8)), col)


func _lock(at: Vector2) -> void:
	_parc(at + Vector2(0, -1), 3.0, PI, TAU, 8, SUB, 1.3)
	_prect(Rect2(at + Vector2(-4, 0), Vector2(8, 6)), SUB)


func _draw_range_focus(m: GMatch) -> void:
	var t: Dictionary = m.towers[selected]
	var center := Vector2(int(t["x"]), int(t["y"])) + Vector2(0.5, 0.5)
	var radius := m.tower_range(t)
	_prect(_frame_rect(), Color(0.04, 0.05, 0.06, 0.34))
	for path in m.board.paths:
		for c in path:
			if center.distance_to(Vector2(c) + Vector2(0.5, 0.5)) <= radius:
				var at := _p(Vector2(c))
				_prect(Rect2(at + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)), Color(ICE, 0.32))
				_prect(Rect2(at + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)), ICE, false, 1.2)


## 흔들림으로 지형이 틀 밖 패널에 비치지 않게 가장자리를 덮는다
## 3~4인은 한 사람을 두 줄로 줄여 보여 준다
func _draw_inspector(m: GMatch, top: float) -> void:
	var t: Dictionary = m.towers[selected]
	var mine := int(t["owner"]) == s.seat
	var prep := m.phase == "prep"
	var lv := int(t["lv"])
	var r := _inspector_rect(m, t)
	var four: bool = _ly()["four"]
	_nine(r, "panel_steel")
	var d: Dictionary = GData.TOWERS[t["type"]]
	var owner: Dictionary = m.players[int(t["owner"])]
	var col := int(owner.get("col", 0)) % 4
	var head := Rect2(r.position + Vector2(8, 8), Vector2(60, 60) if not four else Vector2(44, 56))
	_nine(head, "panel_well")
	_tower_icon(t["type"], lv, str(t["branch"]), col, head.grow(-4))
	var tx := head.end.x + 10
	_tx(Rect2(tx, r.position.y + 8, r.end.x - tx - 8, 28), str(d["name"]), T.STRONG, INK)
	var mk := "MK-%d" % lv if lv < 3 else "MK-3%s" % str(t["branch"]).to_upper()
	_tx(Rect2(tx, r.position.y + 38, 60, 24), mk, T.LABEL, AMBER)
	_prect(Rect2(tx + _sz(mk, T.LABEL).x + 10, r.position.y + 46, 10, 10), OWNER[col])
	var st := GData.tower_stats(t["type"], lv, str(t["branch"]))
	st["range"] = m.tower_range(t)
	var stn := str(st["st"])
	if stn != "":      # 남기는 상태 칩
		var cx := tx + _sz(mk, T.LABEL).x + 28
		_prect(Rect2(cx, r.position.y + 44, 14, 14), OUTLINE)
		_prect(Rect2(cx + 2, r.position.y + 46, 10, 10), Color(str(GData.STATUS[stn]["col"])))
		_tx(Rect2(cx + 20, r.position.y + 38, 80, 24), str(GData.STATUS[stn]["name"]), T.LABEL, INK)
	var rows: Array = []
	if bool(st["support"]):
		rows = [["사거리 증가", "+%d%%" % roundi(st["buff"] * 100)], ["표식 범위", "%.1f칸" % st["mark_r"]]]
	elif bool(st["trap"]):
		rows = [["피해", "%.0f" % st["dmg"]], ["내구", "%d/%d" % [int(t["uses"]), int(st["uses"])]]]
	elif bool(st["aura"]) and float(st["cd"]) < 0.5:
		rows = [["초당 피해", "%.0f" % (st["dmg"] / st["cd"])], ["범위", "%.1f칸" % st["range"]]]
	else:
		rows = [["피해", "%.0f" % st["dmg"] if int(st["chain"]) == 0 else "%.0f ×%d명" % [st["dmg"], int(st["chain"])]], ["범위" if st["aura"] else "사거리", "%.1f칸" % st["range"]]]
	var kills := 0
	if m.tower_log.has(int(t["id"])):
		kills = int(m.tower_log[int(t["id"])][5])
	rows.append(["처치", str(kills)])
	var y := head.end.y + 8
	for row in rows:
		var rr := Rect2(r.position.x + 10, y, r.size.x - 20, 24)
		_tx(rr, str(row[0]), T.LABEL, SUB)
		_tx(rr, str(row[1]), T.LABEL, INK, 2)
		y += 24
	# 터뜨리는 반응 (팀원 포탑과 무엇이 맞는지)
	if stn != "":
		var names := []
		for rx in GData.reactions_with(stn):
			names.append(str(GData.REACTIONS[rx]["name"]))
		var line := " · ".join(names)
		while line.length() > 2 and _sz(line, T.LABEL).x > r.size.x - 20:
			line = line.left(line.length() - 1)
		_tx(Rect2(r.position.x + 10, y, r.size.x - 20, 24), line, T.LABEL, AMBER)
	# 마우스 올리면 나머지 수치
	var stat_box := Rect2(r.position.x, head.end.y + 8, r.size.x, 96)
	if stat_box.has_point(get_local_mouse_position() - _off):
		var cover := Board.coverage(Vector2i(int(t["x"]), int(t["y"])), float(st["range"]), m.board.paths)
		var more := "사거리 안 길 %d칸 · 간격 %.2f초" % [cover, st["cd"]]
		if stn != "":
			more += " · 반응: " + ", ".join(GData.reactions_with(stn).map(func(k): return GData.REACTIONS[k]["name"]))
		_tip(Vector2(r.position.x - 220, stat_box.get_center().y), more)
	if not mine:
		_tx(Rect2(r.position.x + 10, y + 8, r.size.x - 20, 24), "%s의 포탑" % str(owner["name"]).left(6), T.LABEL, SUB)


## 판매·강화·갈래 카드 글자 (버튼 판 위)
func _draw_insp_buttons(m: GMatch, t: Dictionary, mine: bool, prep: bool, lv: int) -> void:
	var d: Dictionary = GData.TOWERS[t["type"]]
	if sell_btn.visible:
		var sr := Rect2(sell_btn.position, sell_btn.size)
		_tx(Rect2(sr.position + Vector2(0, 2), Vector2(sr.size.x, 26)), "환불" if bool(t.get("fresh", false)) else "판매", T.BODY, INK, 1)
		_tx(Rect2(sr.position + Vector2(0, 24), Vector2(sr.size.x, 22)), "+%d" % m.sell_value(t), T.KEY, SUB, 1)
	if up_btn.visible:
		var ur := Rect2(up_btn.position, up_btn.size)
		var ink := AMBER_INK if not up_btn.disabled else SUB
		var free := int(m.players[s.seat].get("free_up", 0)) > 0
		_tx(Rect2(ur.position + Vector2(0, 2), Vector2(ur.size.x, 26)), "강화" if lv == 1 else "MK-3", T.BODY, ink, 1)
		_tx(Rect2(ur.position + Vector2(0, 24), Vector2(ur.size.x, 22)), "FREE" if free else str(int(d["up"][0 if lv == 1 else 1])), T.KEY, ink, 1)
	if a_btn.visible:
		for k in 2:
			var b: Button = a_btn if k == 0 else b_btn
			var br := Rect2(b.position, b.size)
			var hot := b.is_hovered() and not b.disabled
			_nine(br, "panel_amber" if hot else "panel_dark")
			if not hot:
				_prect(br.grow(-2), AMBER if not b.disabled else LINE, false, 2.0)
			var br_d: Dictionary = d["a" if k == 0 else "b"]
			var ink := AMBER_INK if hot else (AMBER if not b.disabled else SUB)
			_tx(Rect2(br.position + Vector2(8, 6), Vector2(br.size.x - 16, 24)), "A" if k == 0 else "B", T.LABEL, ink)
			var label := str(br_d["label"])
			while label.length() > 1 and _sz(label, T.LABEL).x > br.size.x - 16:
				label = label.left(label.length() - 1)
			_tx(Rect2(br.position + Vector2(8, 30), Vector2(br.size.x - 16, 24)), label, T.LABEL, ink if hot else INK)
			_tx(Rect2(br.position + Vector2(8, br.size.y - 28), Vector2(br.size.x - 16, 22)), str(int(d["up"][1])), T.KEY, ink, 2)
	for k in prio_btns:
		var b: Button = prio_btns[k]
		if b.visible:
			_tx(Rect2(b.position, b.size), PRIO[k], T.LABEL, AMBER if b.button_pressed else INK, 1)


func _inspector_layout(r: Rect2, mine: bool, prep: bool, lv: int) -> void:
	var w := r.size.x - 16
	var bottom := r.end.y - 56
	var gap := 6.0
	var sell_w := floorf((w - gap) * 0.42 / 2.0) * 2.0
	sell_btn.position = Vector2(r.position.x + 8, bottom)
	sell_btn.size = Vector2(sell_w if lv < 3 else w, 48)
	up_btn.position = Vector2(r.position.x + 8 + sell_w + gap, bottom)
	up_btn.size = Vector2(w - sell_w - gap, 48)
	var pw := floorf((w - 8) / 3.0 / 2.0) * 2.0
	var py := bottom - 40
	var keys := ["first", "strong", "near"]
	for i in 3:
		prio_btns[keys[i]].position = Vector2(r.position.x + 8 + i * (pw + 4), py)
		prio_btns[keys[i]].size = Vector2(pw, 32)
	var half := floorf((w - gap) * 0.5 / 2.0) * 2.0
	a_btn.position = Vector2(r.position.x + 8, bottom - 92)
	a_btn.size = Vector2(half, 84)
	b_btn.position = Vector2(r.position.x + 8 + half + gap, bottom - 92)
	b_btn.size = Vector2(w - half - gap, 84)


func _draw_wave_info(m: GMatch, top: float) -> void:
	var L := _ly()
	var four: bool = L["four"]
	var r: Rect2 = L["side"]
	var lanes := m.board.paths.size()
	var counts := []
	var orders := []
	for e in lanes:
		counts.append({})
		orders.append([])
	var rows: Array = m.wave_plan() if m.phase == "prep" else m.remaining()
	for g in rows:
		var e := int(g[0])
		if e >= lanes:
			continue
		if not counts[e].has(g[1]):
			orders[e].append(g[1])
		counts[e][g[1]] = int(counts[e].get(g[1], 0)) + int(g[2])
	var per := 2 if not four else 1
	var row_h := 56.0 if not four else 44.0
	var need := 40.0
	for e in lanes:
		need += ceili(maxf(orders[e].size(), 1) / float(per)) * row_h
	r.size.y = minf(need + 8, (L["call"] as Rect2).position.y - 8 - r.position.y)
	_side_rect = r
	_nine(r, "panel_steel")
	var title := "다음 웨이브" if m.phase == "prep" else "남은 적 %d" % (m.enemies.size() + m.queued())
	_tx(Rect2(r.position + Vector2(10, 8), Vector2(r.size.x - 20, 24)), title, T.LABEL, SUB)
	var y := r.position.y + 40
	var cw := floorf((r.size.x - 36) / per / 2.0) * 2.0
	for e in lanes:
		if y + row_h > r.end.y + 2:
			break
		var order: Array = orders[e]
		var lines := maxi(ceili(order.size() / float(per)), 1)
		var chip := Rect2(r.position.x + 8, y + (row_h - 28) * 0.5, 16, 28)
		_prect(chip, AMBER)
		_tx(chip, str(e + 1), T.KEY, AMBER_INK, 1)
		if order.is_empty():
			_tx(Rect2(r.position.x + 36, y, 100, row_h), "-", T.LABEL, SUB)
		for i in order.size():
			var k: String = order[i]
			var x := r.position.x + 30 + (i % per) * cw
			var yy := y + (i / per) * row_h
			if yy + row_h > r.end.y + 2:
				break
			_enemy_icon(k, Rect2(x, yy + (row_h - 44) * 0.5, 48, 44))
			_tx(Rect2(x + 50, yy, cw - 50, row_h), "×%d" % counts[e][k], T.STRONG if not four else T.LABEL, INK)
		y += lines * row_h


func _draw_result() -> void:
	var v := get_viewport_rect().size
	_hazard(Rect2(-_off.x, -_off.y, v.x, 8))
	var m := s.m
	var lost := s.state == "lost"
	if lost:
		_t(Vector2(32, 24), "연결이 끊겼어요", T.BIG, LAMP)
		_t(Vector2(32, 68), "방장과 연결이 끊겼어요 · 패배 기록이 아니에요", T.LABEL, SUB)
	elif m != null and m.cleared:
		_t(Vector2(32, 24), "%d웨이브 방어 성공" % GData.LAST_WAVE, T.BIG, AMBER)
		_t(Vector2(32, 68), "다섯 테마를 모두 버텨냈어요 · 다음엔 더 적은 피해로?", T.LABEL, SUB)
	else:
		_t(Vector2(32, 24), "본부가 무너졌어요", T.BIG, LAMP)
		if m != null:
			_t(Vector2(32, 68), "웨이브 %d에서 멈췄어요 · 다음엔 %d번 길을 더 길게?" % [m.failed_wave, _worst_gate(m) + 1], T.LABEL, SUB)
	# 아래 띠
	_prect(Rect2(-_off.x, 604, v.x, v.y), Color("1E1C1A"))
	_hazard(Rect2(-_off.x, 602, v.x, 6))
	_nine(Rect2(684, 470, 562, 120), "panel_steel")
	_tx(Rect2(694, 478, 200, 24), "방 채팅", T.LABEL, SUB)
	_draw_plates(result)
	_key_chip(title_btn.position + Vector2(title_btn.size.x * 0.5 + 40, 16), "ESC")
	var rb := Rect2(retry_btn.position, retry_btn.size)
	var ink := AMBER_INK if not retry_btn.disabled else SUB
	if lost:
		_t(Vector2(rb.get_center().x, rb.position.y + 18), "다시 접속", T.BIG, ink, 1)
	else:
		var solo: bool = s.solo
		_tx(Rect2(rb.position + Vector2(0, 6), Vector2(rb.size.x, 36)), "한 판 더", T.BIG, ink, 1)
		_tx(Rect2(rb.position + Vector2(0, 44), Vector2(rb.size.x, 24)), "같은 팀 · 바로 시작" if s.is_host else "방장이 고르는 중", T.LABEL, ink, 1)
	if m == null:
		return
	var held: int = GData.LAST_WAVE if m.cleared else maxi(m.failed_wave - 1, 0)
	var total_kills := 0
	for p in m.players:
		total_kills += int(p["kills"])
	var rx_n := 0
	for k in m.rx_log:
		rx_n += int(m.rx_log[k])
	var stats := [["막은 웨이브", str(held)], ["버틴 시간", _clock2(m.time)], ["처치", str(total_kills)], ["반응", "%d회" % rx_n]]
	for i in 4:
		var r := Rect2(34 + i * 158, 114, 150, 84)
		_nine(r, "panel_steel")
		_tx(Rect2(r.position + Vector2(10, 8), Vector2(r.size.x - 20, 24)), stats[i][0], T.LABEL, SUB)
		_tx(Rect2(r.position + Vector2(10, 38), Vector2(r.size.x - 20, 36)), stats[i][1], T.BIG, AMBER if i == 0 else INK)
	# 웨이브마다 본부 내구도
	var ch := Rect2(34, 210, 628, 200)
	_nine(ch, "panel_steel")
	_tx(Rect2(ch.position + Vector2(10, 8), Vector2(400, 24)), "웨이브마다 본부 내구도", T.LABEL, SUB)
	var last := maxi(m.failed_wave, m.hp_log.size())
	last = maxi(last, 1)
	var step := floorf(minf(74.0, 600.0 / last) / 2.0) * 2.0
	var bw := maxf(step - 20.0, 4.0) if step >= 30.0 else maxf(step - 4.0, 2.0)
	var base_y := ch.end.y - 26
	var top_y := ch.position.y + 42
	for w in last:
		var x := ch.position.x + 16 + w * step
		var hpv := -1
		if w < m.hp_log.size() and m.hp_log[w] != null:
			hpv = int(m.hp_log[w])
		var failed := w + 1 == m.failed_wave
		if failed:
			hpv = maxi(hpv, 0)
		if hpv >= 0:
			var h := maxf((base_y - top_y) * float(hpv) / GData.CASTLE_HP, 6.0)
			if failed:
				h = maxf(h, (base_y - top_y) * 0.5)
			var bar := Rect2(x, base_y - h, bw, h)
			_prect(bar, OUTLINE)
			_prect(bar.grow(-2), LAMP if failed else Color("6CC04A"))
		if last <= 12 or (w + 1) % 5 == 0 or w == 0:
			_t(Vector2(x + bw * 0.5, base_y + 2), str(w + 1), T.LABEL, SUB, 1)
	# 지나온 테마
	_tx(Rect2(42, 416, 120, 32), "지나온 테마", T.LABEL, SUB)
	var chip_x := 160.0
	for i in GData.theme_of(m.wave) + 1:
		var th: Dictionary = GData.THEMES[i]
		var chip_w := _ev(Vector2(_sz(str(th["name"]), T.LABEL).x + 34, 0)).x
		var chip := Rect2(chip_x, 416, chip_w, 32)
		_nine(chip, "panel_dark")
		_prect(Rect2(chip.position + Vector2(8, 9), Vector2(12, 12)), Color(str(th["wipe"])))
		_tx(Rect2(chip.position + Vector2(26, 0), Vector2(chip_w, 32)), str(th["name"]), T.LABEL, INK)
		chip_x += chip_w + 8
	# 길별로 본부까지 온 적
	var lk := Rect2(34, 456, 628, 44 + m.gate_dmg.size() * 24)
	_nine(lk, "panel_steel")
	_tx(Rect2(lk.position + Vector2(10, 8), Vector2(400, 24)), "본부까지 온 적 · 길별", T.LABEL, SUB)
	var most := 1
	for d in m.gate_dmg:
		most = maxi(most, int(d))
	var worst := _worst_gate(m)
	var lanes := m.gate_dmg.size()
	var row_h := 24.0
	for e in lanes:
		var y := lk.position.y + 38 + e * row_h
		_tx(Rect2(lk.position.x + 10, y - 5, 90, 24), "%d번 길" % (e + 1), T.LABEL, INK)
		var wv := 360.0 * float(m.gate_dmg[e]) / most
		if int(m.gate_dmg[e]) > 0:
			_prect(Rect2(lk.position.x + 100, y, wv, 14), OUTLINE)
			_prect(Rect2(lk.position.x + 102, y + 2, maxf(wv - 4, 2), 10), LAMP if e == worst else AMBER)
		_tx(Rect2(lk.position.x + 110 + wv, y - 5, 60, 24), str(int(m.gate_dmg[e])), T.KEY, INK)
	# 팀 기록
	var n := m.players.size()
	var rh := 80.0 if n <= 2 else 44.0
	var tb := Rect2(684, 114, 562, 44 + n * (rh + 8))
	_nine(tb, "panel_steel")
	_tx(Rect2(tb.position + Vector2(10, 8), Vector2(200, 24)), "팀 기록", T.LABEL, SUB)
	_tx(Rect2(tb.position + Vector2(10, 8), Vector2(tb.size.x - 20, 24)), "함께 만든 피해 %s" % _kilo(m.joint_dmg), T.LABEL, AMBER, 2)
	var cols := [["피해", 896.0], ["처치", 986.0], ["포탑", 1078.0], ["길", 1160.0]]
	for c in cols:
		_tx(Rect2(c[1] - 40, tb.position.y + 8, 80, 24), c[0], T.LABEL, SUB, 1)
	var top_dmg := -1
	var top_road := -1
	for i in n:
		if top_dmg < 0 or float(m.players[i]["dmg"]) > float(m.players[top_dmg]["dmg"]):
			top_dmg = i
		if int(m.players[i].get("roads", 0)) > 0 and (top_road < 0 or int(m.players[i].get("roads", 0)) > int(m.players[top_road].get("roads", 0))):
			top_road = i
	for i in n:
		var p: Dictionary = m.players[i]
		var row := Rect2(690, tb.position.y + 44 + i * (rh + 8), 550, rh)
		_nine(row, "panel_dark")
		var col := int(p.get("col", i)) % 4
		var sq_y := 8.0 if n <= 2 else (row.size.y - 20) * 0.5
		_prect(Rect2(row.position + Vector2(12, sq_y), Vector2(20, 20)), OUTLINE)
		_prect(Rect2(row.position + Vector2(14, sq_y + 2), Vector2(16, 16)), OWNER[col])
		_tx(Rect2(row.position + Vector2(42, 6 if n <= 2 else 0), Vector2(140, 28 if n <= 2 else row.size.y)), str(p["name"]).left(6), T.STRONG, INK)
		var badge := ""
		if i == top_road:
			badge = "길 담당"
		elif i == top_dmg:
			badge = "최다 피해"
		if badge != "" and n <= 2:
			var bwid := _ev(Vector2(_sz(badge, T.LABEL).x + 12, 0)).x
			_prect(Rect2(row.position + Vector2(42, 42), Vector2(bwid, 22)), AMBER)
			_t(row.position + Vector2(48, 42), badge, T.LABEL, AMBER_INK)
		var towers := 0
		for id in m.towers:
			if int(m.towers[id]["owner"]) == i:
				towers += 1
		var vals := [_kilo(float(p["dmg"])), str(int(p["kills"])), str(towers), str(int(p.get("roads", 0)))]
		var cy := row.position.y + row.size.y * 0.5 - 16
		for k in 4:
			_tx(Rect2(cols[k][1] - 40, row.position.y, 80, row.size.y), vals[k], T.STRONG if n <= 2 else T.LABEL, INK, 1)
	# 가장 일 많이 한 포탑
	var best := -1
	for id in m.tower_log:
		if best < 0 or float(m.tower_log[id][4]) > float(m.tower_log[best][4]):
			best = id
	var mv := Rect2(684, tb.end.y + 8, 562, 0)
	mv.size.y = 470 - 8 - mv.position.y
	if mv.size.y >= 60:
		_tx(Rect2(mv.position + Vector2(8, 0), Vector2(400, 24)), "가장 일 많이 한 포탑", T.LABEL, SUB)
		var box := Rect2(mv.position + Vector2(0, 26), Vector2(562, mv.size.y - 26))
		_nine(box, "panel_dark")
		if best >= 0:
			var row: Array = m.tower_log[best]
			var lv := int(row[1])
			var owner := clampi(int(row[3]), 0, n - 1)
			var ocol := int(m.players[owner].get("col", owner)) % 4
			_tower_icon(str(row[0]), lv, str(row[2]), ocol, Rect2(box.position + Vector2(10, (box.size.y - 50) * 0.5), Vector2(50, 50)))
			var mk := "MK-%d" % lv if lv < 3 else "MK-3%s" % str(row[2]).to_upper()
			_t(box.position + Vector2(76, 4), "%s %s" % [GData.TOWERS[str(row[0])]["name"], mk], T.STRONG, INK)
			if box.size.y >= 64:
				_t(box.position + Vector2(76, 34), "%s · 처치 %d · 피해 %s" % [m.players[owner]["name"], int(row[5]), _kilo(float(row[4]))], T.LABEL, SUB)
		else:
			_t(box.position + Vector2(12, 8), "기록 없음", T.LABEL, SUB)


func _kilo(v: float) -> String:
	if v >= 1000.0:
		return "%.1fk" % (v / 1000.0)
	return str(int(v))


func _result_row(p: Dictionary, i: int, y: float) -> void:
	_card(Rect2(947, y, 284, 73), Color("2B2F33"), Color("2B2F33"))
	_tag(Vector2(966, y + 16), int(p.get("col", i)) % 4, 15.0)
	_t(Vector2(981, y + 4), str(p["name"]), T.LABEL, INK)
	var cells := [["피해량", "%d" % int(p["dmg"])], ["처치", "%d" % int(p["kills"])], ["감속", "%.0f" % float(p["slow"])], ["지원", "%d회" % int(p["support"])]]
	var xs := [957.0, 1046.0, 1112.0, 1176.0]
	for k in 4:
		_t(Vector2(xs[k], y + 30), cells[k][0], T.LABEL, SUB)
		_t(Vector2(xs[k], y + 48), cells[k][1], T.LABEL, INK)


func _worst_gate(m: GMatch) -> int:
	var best := 0
	for e in m.gate_dmg.size():
		if int(m.gate_dmg[e]) > int(m.gate_dmg[best]):
			best = e
	return best


func _clock(sec: float) -> String:
	var t := int(sec)
	return "%d분 %d초" % [t / 60, t % 60] if t >= 60 else "%d초" % t


func _draw_pause() -> void:
	var v := get_viewport_rect().size
	if _screen == "menu" or _paused or _panel != "":
		_dim_screen()
	if _paused and _panel == "":
		var m := Rect2(442, 142, 396, 424)
		_modal(m, "일시정지")
		var solo: bool = s != null and s.solo
		_t(Vector2(462, 190), "혼자 연습이라 시간이 멈춰요" if solo else "내 화면만 멈춰요 · 팀은 계속 진행", T.LABEL, INK)
		_t(Vector2(462, 214), "같이 할 땐 다른 사람 화면은 계속 진행" if solo else ("방장이 나가면 방이 닫혀요" if s != null and s.is_host else "초대 링크로 다시 들어올 수 있어요"), T.LABEL, LAMP if not solo else SUB)
		_prect(Rect2(462, 488, 356, 2), Color("4A4640"))
		_draw_plates(pause)
		var b: Button = pause_btns["back"]
		_key_chip(b.position + Vector2(b.size.x * 0.5 + 86, 12), "ESC")
		_glyph_x(pause_btns["close"].position + Vector2(14, 14), INK)
		return
	if _panel != "":
		var r := Rect2(302, 82, 676, 554)
		match _panel:
			"settings":
				_modal(r, "설정")
				_draw_settings_rows()
			"help":
				_modal(r, "조작 안내")
				var keys := [["WASD", "카메라 이동 · Shift 빠르게 · H 본부 · F1~F4 입구"], ["휠 Z X", "x2 / x1 확대 · 가운데·우클릭 끌기 이동"], ["1-5", "공구함 포탑 고르기 · 빈 칸 클릭"],
					["G", "길 다시 그리기 · E 확정 · Ctrl+Z 되돌리기"], ["Q", "긴급 냉각 (전투 중 1회)"], ["Alt+클릭", "핑 · T 빠른 요청"], ["SPACE", "준비 완료 / 취소"], ["Esc", "취소 · 일시정지"]]
				for i in keys.size():
					var row := Rect2(320, 136 + i * 54, 640, 46)
					_nine(row, "panel_dark")
					_key_chip(row.position + Vector2(14, 12), str(keys[i][0]))
					_t(row.position + Vector2(140, 8), str(keys[i][1]), T.LABEL, INK)
			"codex":
				_modal(r, "반응 도감 · 이번 판 %d/%d" % [s.m.seen_rx.size() if s.m != null else 0, GData.REACTION_ORDER.size()])
				for i in GData.REACTION_ORDER.size():
					var key: String = GData.REACTION_ORDER[i]
					var rd: Dictionary = GData.REACTIONS[key]
					var seen: bool = s.m != null and s.m.seen_rx.has(key)
					var row := Rect2(320 + (i % 2) * 324, 136 + (i / 2) * 70, 316, 62)
					_nine(row, "panel_dark")
					var cx := row.position.x + 12
					for stk in [rd["a"], rd["b"]]:
						if str(stk) == "":
							continue
						_prect(Rect2(cx, row.position.y + 12, 14, 14), OUTLINE)
						_prect(Rect2(cx + 2, row.position.y + 14, 10, 10), Color(str(GData.STATUS[stk]["col"])))
						cx += 18
					_tx(Rect2(cx + 6, row.position.y + 4, 200, 28), str(rd["name"]), T.STRONG, Color(str(rd["col"])) if seen else SUB)
					if seen and s.m != null:
						_tx(Rect2(row.position.x, row.position.y + 4, row.size.x - 12, 28), "%d회" % int(s.m.rx_log.get(key, 0)), T.LABEL, AMBER, 2)
					_tx(Rect2(row.position.x + 12, row.position.y + 32, row.size.x - 24, 24), str(rd["desc"]), T.LABEL, INK if seen else Color("6A6660"))
			"mute":
				_modal(r, "채팅 음소거 관리")
				_t(Vector2(320, 140), "음소거한 사람의 채팅과 핑을 내 화면에서만 숨겨요", T.LABEL, SUB)
				for i in _player_count():
					var row := Rect2(320, 186 + i * 60, 640, 52)
					_nine(row, "panel_dark")
					var name_ := str(s.m.players[i]["name"]) if s.m != null else str(s.seats[i]["name"])
					_prect(Rect2(row.position + Vector2(14, 14), Vector2(24, 24)), OWNER[_col_of_seat(i) % 4])
					_t(row.position + Vector2(50, 8), name_ + (" (나)" if i == s.seat else ""), T.STRONG, INK)
					if _muted.has(i):
						_t(Vector2(row.end.x - 140, row.position.y + 12), "숨김", T.LABEL, DANGER, 2)
		_draw_plates(pause)
		_glyph_x(cfg_btns["close"].position + Vector2(14, 14), INK)
		if _panel == "settings":
			_draw_settings_art()
			_glyph_enter(cfg_btns["apply"].position + Vector2(cfg_btns["apply"].size.x - 32, 8), AMBER_INK)


## 모달 틀: 위 제목 띠 + 노란 사선 표식
func _modal(r: Rect2, title: String) -> void:
	_nine(r, "panel_steel")
	_prect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, 34)), Color("2A2723"))
	_hazard_tag(r.position + Vector2(8, 10))
	_t(r.position + Vector2(22, 4), title, T.STRONG, INK)


func _glyph_enter(at: Vector2, col: Color) -> void:
	_prect(Rect2(at, Vector2(26, 20)), col, false, 2.0)
	_prect(Rect2(at + Vector2(18, 4), Vector2(2, 8)), col)
	_prect(Rect2(at + Vector2(6, 10), Vector2(14, 2)), col)
	_prect(Rect2(at + Vector2(6, 8), Vector2(2, 6)), col)


func _draw_settings_rows() -> void:
	match _tab:
		1:
			_t(Vector2(322, 194), "조작은 키보드·마우스 기본값으로 고정돼 있어요", T.LABEL, INK)
			_t(Vector2(322, 222), "자세한 키는 일시정지 메뉴의 '조작 안내'에서 볼 수 있어요", T.LABEL, SUB)
		2:
			_t(Vector2(322, 194), "소리 크기는 아직 준비 중이에요", T.LABEL, INK)
	var rows := _settings_rows()
	for i in rows.size():
		var row := Rect2(320, 192 + i * 64, 640, 54)
		_nine(row, "panel_dark")
		var desc := str(rows[i][3])
		_t(row.position + Vector2(14, 4 if desc != "" else 12), str(rows[i][2]), T.STRONG, INK)
		if desc != "":
			_t(row.position + Vector2(14, 32), desc, T.LABEL, SUB)


func _draw_settings_art() -> void:
	for k in toggle_btns:
		var b: Button = toggle_btns[k]
		if not b.visible:
			continue
		var on := bool(_cfg_draft.get(k, false))
		var r := Rect2(b.position, b.size)
		_prect(r, OUTLINE)
		_prect(r.grow(-2), Color("8A6A22") if on else Color("2A2826"))
		_prect(Rect2(r.position + Vector2(r.size.x - 20 if on else 4, 4), Vector2(16, 16)), AMBER if on else Color("6A6660"))
	if shake_btn.visible:
		var y := shake_btn.position.y + 13
		var v := float(_cfg_draft.get("shake", 30)) / 100.0
		_prect(Rect2(680, y - 1, 220, 2), Color("4A4640"))
		_prect(Rect2(680, y - 1, 220 * v, 2), AMBER)
		_prect(Rect2(680 + 220 * v - 6, y - 8, 12, 16), OUTLINE)
		_prect(Rect2(680 + 220 * v - 4, y - 6, 8, 12), Color("8C939A"))
		_t(Vector2(946, y - 14), str(int(_cfg_draft.get("shake", 30))), T.LABEL, AMBER, 2)


# ── 도트 도형: 모든 위치·굵기는 짝수 px, 둥근 것은 계단 ──

func _ev(v: Vector2) -> Vector2:
	return (v * 0.5).round() * 2.0


func _prect(r: Rect2, col: Color, filled := true, width := -1.0, _aa := false) -> void:
	var a := _ev(r.position)
	var b := _ev(r.end)
	var q := Rect2(a, b - a)
	if filled:
		draw_rect(q, col)
		return
	var w := maxf(2.0, roundf(maxf(width, 2.0) * 0.5) * 2.0)
	draw_rect(Rect2(q.position, Vector2(q.size.x, w)), col)
	draw_rect(Rect2(q.position + Vector2(0, q.size.y - w), Vector2(q.size.x, w)), col)
	draw_rect(Rect2(q.position, Vector2(w, q.size.y)), col)
	draw_rect(Rect2(q.position + Vector2(q.size.x - w, 0), Vector2(w, q.size.y)), col)


## 채운 원 → 2px 줄 계단 (테두리만이면 점 고리)
func _pcircle(c: Vector2, r: float, col: Color, filled := true, width := -1.0, _aa := false) -> void:
	if not filled:
		_parc(c, r, 0.0, TAU, 0, col, width)
		return
	c = _ev(c)
	var rr := maxf(2.0, roundf(r * 0.5) * 2.0)
	var y := -rr
	while y < rr:
		var half := roundf(sqrt(maxf(rr * rr - (y + 1.0) * (y + 1.0), 0.0)) * 0.5) * 2.0
		if half > 0.0:
			draw_rect(Rect2(c.x - half, c.y + y, half * 2.0, 2.0), col)
		y += 2.0


## 고리·호 → 둘레 6px 마다 2x2 점, 아래 2px 검정 점
func _parc(c: Vector2, r: float, a0: float, a1: float, _n: int, col: Color, width := -1.0, _aa := false) -> void:
	var span := absf(a1 - a0)
	var count := maxi(4, int(span * r / 6.0))
	var big := width >= 2.5
	for i in count + (0 if span >= TAU - 0.01 else 1):
		var a := a0 + (a1 - a0) * i / float(count)
		var p := _ev(c + Vector2.from_angle(a) * r)
		if col.a > 0.4:
			draw_rect(Rect2(p + Vector2(0, 2), Vector2(2, 2)), Color(OUTLINE, col.a))
		draw_rect(Rect2(p, Vector2(4, 4) if big else Vector2(2, 2)), col)


## 선 → 2px 정사각 점을 이어 찍기
func _pline(a: Vector2, b: Vector2, col: Color, width := -1.0, _aa := false) -> void:
	var w := maxf(2.0, roundf(maxf(width, 2.0) * 0.5) * 2.0)
	a = _ev(a)
	b = _ev(b)
	if a.x == b.x or a.y == b.y:
		var q := Rect2(a.min(b), (b - a).abs() + Vector2(w, w) * (Vector2.ONE if a == b else Vector2(1.0 if a.x == b.x else 0.0, 1.0 if a.y == b.y else 0.0)))
		draw_rect(Rect2(q.position - Vector2(w, w) * 0.5 * Vector2(1.0 if a.x == b.x else 0.0, 1.0 if a.y == b.y else 0.0), q.size), col)
		return
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)) / 2.0)
	for i in n + 1:
		var p := _ev(a.lerp(b, i / float(maxi(n, 1))))
		draw_rect(Rect2(p - Vector2(w, w) * 0.5, Vector2(w, w)), col)


func _pdash(a: Vector2, b: Vector2, col: Color, width := -1.0, dash := 2.0, _aligned := true, _aa := false) -> void:
	var w := maxf(2.0, roundf(maxf(width, 2.0) * 0.5) * 2.0)
	var d := b - a
	var len := d.length()
	if len < 1.0:
		return
	var step := maxf(dash, 2.0) * 2.0
	var t := 0.0
	while t <= len:
		var p := _ev(a + d * (t / len))
		draw_rect(Rect2(p - Vector2(w, w) * 0.5, Vector2(w, w)), col)
		t += step


func _ppoly(pts: PackedVector2Array, col: Color, width := -1.0, _aa := false) -> void:
	for i in range(1, pts.size()):
		_pline(pts[i - 1], pts[i], col, width)
