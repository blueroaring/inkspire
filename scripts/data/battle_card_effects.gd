extends RefCounted
## Card badges and the mechanics guide share one vocabulary.
const DEFINITIONS := {
	"darkness": ["黑暗遮蔽", "此手牌位置暂时无法直接出牌；可交换、弃置和消耗。", Color("c6a0ea")],
	"curse": ["敌方干扰", "敌方塞入的干扰牌，详见卡牌说明。", Color("ed9dba")],
	"trojan": ["木马感染", "必须优先打出此牌，打出时消耗能量，但原技能效果失效。", Color("ff8992")],
	"retain": ["保留", "回合结束留在手牌，仍占用手牌上限。", Color("8fd4f0")],
	"enchant": ["附魔", "首位追加真实伤害；中位支援抽牌；末位累计魔术计数。打出后移除。", Color("c9a8ff")],
	"curtain": ["谢幕", "拥有附魔时耗能变为0。", Color("efb4e6")],
	"sealed": ["本回合封存", "本回合不能打出，下回合解封。", Color("a1b8cf")],
	"exhaust": ["消耗", "释放后进入消耗区，本场战斗不再抽取。", Color("f5a68d")],
	"innate": ["固有", "战斗开始时进入手牌。", Color("ffe2a0")],
	"counterfeit": ["伪证", "作为演算弹药追击后，额外释放本牌的效果。", Color("9ce4d5")],
}
