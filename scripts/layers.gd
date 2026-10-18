class_name Layers
extends RefCounted
## 碰撞层约定（全项目唯一来源）。
##
## Godot 的 collision_layer / collision_mask 是**位掩码**，不是"层号"：
##   值 1 = 第 1 层，值 2 = 第 2 层，值 4 = 第 3 层，值 8 = 第 4 层 ……（值是 2 的幂）
## 这里不用引擎的"层名"配置，而是把掩码直接写成常量，避免"层号 / 掩码"混淆。
## 踩过的坑：交互探测器最初写 mask = 4（本意"第 4 层"），实际只匹配第 3 层，
## 结果只能探到 Area2D 交互物，探不到 NPC（CharacterBody2D），按 E 没反应。

const BIT_1 := 1
const BIT_2 := 2
const BIT_3 := 4
const BIT_4 := 8

## 第 1 层：地图与墙（StaticBody2D）
const ENVIRONMENT := BIT_1
## 第 2 层：角色（玩家、NPC）的实体碰撞
const ACTORS := BIT_2
## 第 3 层：可交互物区域（Area2D）
const INTERACTABLE := BIT_3
## 第 4 层：触发区（进入即触发的事件区域）
const TRIGGER := BIT_4

## 角色实体（玩家 / NPC）：站在 ACTORS 层，**既被环境挡、也被其他角色挡**。
##
## ⚠️ 2026-09-20 修用户实报"人物和人物之间没有碰撞，会重叠在一起"：
##    以前这里只有 `ENVIRONMENT`，而 `npc.tscn` 单独写了 `NPC_BODY_MASK`
##    （环境|角色）—— 于是**碰撞是单向的**：NPC 挡玩家，玩家却能从 NPC 身上穿过去
##    （Godot 里"谁被谁挡住"看的是**自己的 mask**，不是对方的 layer）。
##    现在两边都用同一个掩码，互相都挡。
const ACTOR_BODY_LAYER := ACTORS
const ACTOR_BODY_MASK := ENVIRONMENT | ACTORS

## 兼容别名：NPC 与玩家现在用同一个掩码（保留旧名免得别处引用要改）。
const NPC_BODY_MASK := ACTOR_BODY_MASK

## 玩家身上的交互探测器：不占层，只去探 ACTORS + INTERACTABLE
const PROBE_LAYER := 0
const PROBE_MASK := ACTORS | INTERACTABLE
