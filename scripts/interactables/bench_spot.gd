class_name BenchSpot
extends SitSpot
## 校园长椅：**坐 / 站起来**（08 定稿："全时段给长椅加上坐和站起来的交互"）。
##
## 逻辑全在基类 `SitSpot` 里（那套"座位状态"与"长椅"无关，2026-09-20 抽出去了）。
## 本文件只负责长椅自己的默认口径：提示词、物件名、座位键前缀。
##
## ⚠️ 为什么当初单独一个脚本（现在仍然成立，只是搬到了基类）：
##    它需要一个**跨交互点共享**的状态（"我现在坐在这张椅子上"），
##    而且这个状态要：① 决定同一个交互点的提示词；② 让别的长椅也能把人叫起来；
##    ③ 在存档里活下来（离开场景再回来，人还坐在椅子上）。
##
## ⚠️ 座位键 = `bench.<区>.<序号>`（由 `campus.gd` 给），跟着存档走。

## 交互区在长椅占地后方留出的可达区域里，中心点仍比椅子落地线靠北；
## 站起来要落在椅子南侧，不能留在椅背后。
const STAND_FRONT_OFFSET := Vector2(0.0, 40.0)

func _ready() -> void:
	if sit_prompt == "坐下":
		sit_prompt = "在长椅上坐下"
	if seat_kind == "座位":
		seat_kind = "长椅"
	if stand_offset == Vector2.ZERO:
		stand_offset = STAND_FRONT_OFFSET
	super._ready()
