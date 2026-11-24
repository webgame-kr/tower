class_name GData
extends RefCounted
## 첫 플레이 테스트 기준 수치. 규칙 코드는 여기 값만 읽는다.

const W := 27
const H := 18
const CASTLE := Rect2i(12, 7, 3, 3)
const LANDMARK := Rect2i(18, 2, 3, 3)   # 고정 비건설 구역 (테마가 바뀌어도 같은 자리)
const MAX_PATH := 30
const LAST_WAVE := 25         # 다섯 테마를 모두 지나는 구간
const THEME_LEN := 5          # 이 웨이브마다 테마 경계 (길 개조 기회 재지급)
const CASTLE_HP := 100
const START_GOLD := 320
const EDITS_PER_THEME := 2
const SELL_RATE := 0.8
const SLOW_CAP := 0.6
const ABILITY_RADIUS := 1.5
const ABILITY_TIME := 3.0
const ABILITY_SLOW := 0.4
const MAX_ALIVE := 60
const TICK := 0.05
const HP_GROWTH := 0.22
static var hp_mul := 2.0     # 적 체력 배율 (밸런스 조정용)

const BASE_PATHS := [
	[[0, 8], [1, 8], [2, 8], [3, 8], [4, 8], [4, 7], [4, 6], [4, 5], [5, 5], [6, 5], [7, 5], [8, 5], [8, 6], [8, 7], [8, 8], [9, 8], [10, 8], [11, 8]],
	[[26, 8], [25, 8], [24, 8], [23, 8], [22, 8], [21, 8], [21, 9], [21, 10], [21, 11], [21, 12], [20, 12], [19, 12], [18, 12], [17, 12], [17, 11], [17, 10], [17, 9], [17, 8], [16, 8], [15, 8]],
]

const PIECES := {
	"detour": {"name": "우회로", "span": 2, "depth": 2, "desc": "짧은 구간을 ㄷ자로 돌린다 (+4칸)"},
	"bend": {"name": "굽잇길", "span": 3, "depth": 1, "desc": "길을 옆으로 꺾어 붙인다 (+2칸)"},
}

const TOWERS := {
	"gun": {
		"name": "기관포탑", "cost": 100, "up": [80, 120],
		"lv": [{"dmg": 5.0, "cd": 0.3, "range": 3.0}, {"dmg": 8.0, "cd": 0.3, "range": 3.0}],
		"a": {"label": "회전 4연장", "dmg": 8.0, "cd": 0.15, "range": 3.0},
		"b": {"label": "관통 장포신", "dmg": 18.0, "cd": 0.45, "range": 3.6, "pierce": 6.0, "line": true},
	},
	"cannon": {
		"name": "대포탑", "cost": 150, "up": [120, 180],
		"lv": [{"dmg": 16.0, "cd": 1.6, "range": 2.5, "splash": 1.0}, {"dmg": 24.0, "cd": 1.6, "range": 2.5, "splash": 1.0}],
		"a": {"label": "폭발 범위 확대", "dmg": 24.0, "cd": 1.6, "range": 2.5, "splash": 1.6},
		"b": {"label": "좁은 범위 고피해", "dmg": 52.0, "cd": 1.6, "range": 2.5, "splash": 1.0},
	},
	"cold": {
		"name": "냉각탑", "cost": 120, "up": [100, 140],
		"lv": [{"dmg": 1.0, "cd": 1.0, "range": 2.0, "slow": 0.3, "aura": true}, {"dmg": 2.0, "cd": 0.8, "range": 2.0, "slow": 0.3, "aura": true}],
		"a": {"label": "냉기 장막", "dmg": 2.0, "cd": 0.8, "range": 3.0, "slow": 0.3, "aura": true},
		"b": {"label": "얼음 송곳", "dmg": 6.0, "cd": 0.8, "range": 2.0, "slow": 0.55},
	},
}

const ENEMIES := {
	"grunt": {"name": "일반병", "hp": 34.0, "armor": 0.0, "speed": 1.25, "hit": 1},
	"swarm": {"name": "떼거리", "hp": 13.0, "armor": 0.0, "speed": 1.6, "hit": 1},
	"heavy": {"name": "중장갑", "hp": 120.0, "armor": 4.0, "speed": 0.8, "hit": 1},
	"rusher": {"name": "돌격병", "hp": 42.0, "armor": 0.0, "speed": 2.4, "hit": 1},
	"boss": {"name": "초원 대장", "hp": 900.0, "armor": 3.0, "speed": 0.62, "hit": 15},
}

## 입구(e)별 묶음: [적, 수, 간격(초), 시작(초)]
const WAVES := [
	[[0, "grunt", 6, 1.1, 0.0], [1, "grunt", 6, 1.1, 0.0]],
	[[0, "grunt", 7, 0.9, 0.0], [1, "swarm", 10, 0.45, 1.0]],
	[[0, "swarm", 14, 0.4, 0.0], [1, "grunt", 9, 0.8, 0.0], [1, "swarm", 6, 0.4, 7.0]],
	[[0, "heavy", 3, 3.0, 0.0], [1, "heavy", 3, 3.0, 1.0], [0, "grunt", 6, 0.9, 4.0], [1, "grunt", 6, 0.9, 4.0]],
	[[0, "boss", 1, 0.0, 3.0], [1, "grunt", 10, 0.8, 0.0], [0, "swarm", 12, 0.45, 0.0], [1, "heavy", 2, 3.5, 5.0]],
	[[0, "rusher", 9, 0.7, 0.0], [1, "rusher", 9, 0.7, 2.0], [0, "heavy", 3, 2.6, 5.0], [1, "heavy", 3, 2.6, 5.0], [1, "swarm", 14, 0.35, 8.0]],
]

const THEMES := [
	{"id": "grass", "name": "초원", "desc": "특수 환경 없음", "landmark": "굴착기", "zone": "", "wipe": "#3F5B31", "road": [["#5A4A36", 0.9, 0, 1], ["#A8936C", 0.76, 0, 1], ["#8C7A58", 0.5, 0, 0.9], ["#A8936C", 0.36, 0, 1]]},
	{"id": "snow", "name": "설원", "desc": "빙판 구간에서 적 이동 속도 증가", "landmark": "얼어붙은 시추기", "zone": "ice", "wipe": "#DCE8EE", "road": [["#FFFFFF", 1.08, 0, 0.95], ["#C9D6DC", 0.98, 1, 1], ["#68747B", 0.9, 0, 1], ["#8B979E", 0.76, 0, 1], ["#7A868D", 0.5, 0, 0.9], ["#8B979E", 0.36, 0, 1]]},
	{"id": "sand", "name": "사막", "desc": "모래바람 구역에서 포탑 사거리 감소", "landmark": "모래에 잠긴 수송차", "zone": "sand", "wipe": "#C9A566", "road": [["#CDAE74", 1, 1, 0.9], ["#4C4844", 0.9, 0, 1], ["#9A958C", 0.76, 0, 1], ["#D9C9A6", 0.05, 1, 0.6]]},
	{"id": "lava", "name": "화산", "desc": "용암 길에서 적이 지속 피해", "landmark": "파손된 용광로", "zone": "lava", "wipe": "#7A2412", "road": [["#211D1B", 0.9, 0, 1], ["#8A827B", 0.76, 0, 1], ["#6E6862", 0.76, 1, 1], ["#000000", 0.3, 0, 0.18]]},
	{"id": "ghost", "name": "유령 숲", "desc": "일부 적이 주기적으로 조준 불가", "landmark": "거목 급수탑", "zone": "ghost", "wipe": "#2B3F36", "road": [["#4E7A55", 1.02, 1, 0.9], ["#2C312C", 0.9, 0, 1], ["#8E948C", 0.76, 0, 1], ["#7C827A", 0.76, 1, 1]]},
]

## 실제 효과 구역. 그림과 별개로 모든 플레이어가 같은 값을 쓴다.
const ICE_ZONES := [Rect2i(4, 5, 5, 1), Rect2i(21, 9, 1, 4)]
const LAVA_ZONES := [Rect2i(8, 5, 1, 4), Rect2i(17, 9, 1, 4)]
const SAND_CENTER := Vector2(19.5, 10.5)
const SAND_RADIUS := 3.2
const ICE_SPEED := 1.3
const SAND_RANGE := 0.75
const LAVA_RATE := 0.05       # 초당 최대 체력 비율
const GHOST_CYCLE := 5.0
const GHOST_TIME := 2.0

const PING_KINDS := {
	"look": "주목", "danger": "위험!", "build": "건설 요청", "road": "길 변경 제안", "mine": "여긴 내가 맡을게",
}


static func wave_gold(wave: int) -> int:
	return 120 + wave * 20


static func theme_of(wave: int) -> int:
	return clampi((wave - 1) / THEME_LEN, 0, THEMES.size() - 1)


## 웨이브 구성. 시안 구간 뒤로는 같은 패턴을 더 많이 내보낸다.
static func wave_groups(wave: int) -> Array:
	if wave <= WAVES.size():
		return WAVES[wave - 1]
	var out := []
	for g in WAVES[(wave - 1) % THEME_LEN]:
		var n: int = int(g[2]) if g[1] == "boss" else ceili(int(g[2]) * (1.0 + (wave - WAVES.size()) * 0.05))
		out.append([g[0], g[1], n, g[3], g[4]])
	return out


static func wave_hp(wave: int) -> float:
	return 1.0 + maxi(wave - WAVES.size(), 0) * HP_GROWTH


## 지금 단계의 포탑 능력치
static func tower_stats(type: String, level: int, branch: String) -> Dictionary:
	var d: Dictionary = TOWERS[type]
	var s: Dictionary
	if level >= 3 and branch != "":
		s = d[branch]
	else:
		s = d["lv"][clampi(level - 1, 0, 1)]
	return {
		"dmg": float(s.get("dmg", 0.0)), "cd": float(s.get("cd", 1.0)), "range": float(s.get("range", 3.0)),
		"splash": float(s.get("splash", 0.0)), "slow": float(s.get("slow", 0.0)), "pierce": float(s.get("pierce", 0.0)),
		"aura": bool(s.get("aura", false)), "line": bool(s.get("line", false)),
	}
