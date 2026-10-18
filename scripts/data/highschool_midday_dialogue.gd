extends RefCounted
## 原文来自 request/08_DIALOG.md，由 tools/build_school_midday_dialogue.py 提取。
const LINES := {
	"chinese": [
		{
			"speaker": "旁白",
			"text": "这节课是语文课。"
		},
		{
			"speaker": "旁白",
			"text": "语文老师是一位中年女性，教学十分活泼。"
		},
		{
			"speaker": "旁白",
			"text": "不过到了高三，语文课也渐渐地不再那么有趣了。"
		},
		{
			"speaker": "旁白",
			"text": "语文课更多是做卷子，讲卷子，背古诗，念范文的日常流程了。"
		},
		{
			"speaker": "周明远",
			"text": "语文这东西，一轮二轮复习似乎没有什么用唉。"
		},
		{
			"speaker": "周明远",
			"text": "还是太吃悟性了。"
		},
		{
			"speaker": "周明远",
			"text": "或者说，选科偏理的班级很多同学对语文不是很有动力。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "有些极度偏科的同学甚至在语文课上写理科卷子。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "语文老师",
			"text": "记得把这部分题做了，明天我们讲。"
		},
		{
			"speaker": "周明远",
			"text": "那就是不用做，真叫到了随便编点就行。"
		},
		{
			"speaker": "周明远",
			"text": "好想把过去的我打一顿。",
			"portrait_form": "spirit"
		}
	],
	"math_intro": [
		{
			"speaker": "旁白",
			"text": "这节课是老班的课。"
		},
		{
			"speaker": "旁白",
			"text": "老班的数学课有两种情况，复习知识点或者讲卷子。"
		}
	],
	"math_conics": [
		{
			"speaker": "旁白",
			"text": "今天复习的是圆锥曲线相关的知识。"
		},
		{
			"speaker": "旁白",
			"text": "周明远听着复杂的二级结论感到十分头大。"
		},
		{
			"speaker": "周明远",
			"text": "往好了想，韦达定理还是会的。",
			"portrait_form": "spirit"
		}
	],
	"math_geometry": [
		{
			"speaker": "旁白",
			"text": "今天复习的是立体几何相关的知识。"
		},
		{
			"speaker": "旁白",
			"text": "周明远掌握了一套娴熟的大题建系求解的能力。"
		},
		{
			"speaker": "旁白",
			"text": "但是对于选择填空题中纷繁复杂的切面极值，内切球，外切球等问题，他还是束手无策。"
		},
		{
			"speaker": "周明远",
			"text": "高中立体几何学不明白，到了大学机械制图依然学不明白。",
			"portrait_form": "spirit"
		}
	],
	"math_probability": [
		{
			"speaker": "旁白",
			"text": "今天复习的是统计概率相关的知识。"
		},
		{
			"speaker": "周明远",
			"text": "最小二乘法的公式记不住啊……"
		},
		{
			"speaker": "周明远",
			"text": "没事，上了大学学概率论时感觉连贝叶斯公式都记不住了，不差这个公式了。",
			"portrait_form": "spirit"
		}
	],
	"math_trigonometry": [
		{
			"speaker": "旁白",
			"text": "今天复习的是三角函数相关的知识。"
		},
		{
			"speaker": "旁白",
			"text": "三角函数的变化千千万，最难的是和其他知识点的融合，比如奇偶性等。"
		},
		{
			"speaker": "周明远",
			"text": "这应该是我当时学的最好的部分了。",
			"portrait_form": "spirit"
		}
	],
	"math_derivative": [
		{
			"speaker": "旁白",
			"text": "今天复习的是导数相关的知识。"
		},
		{
			"speaker": "周明远",
			"text": "……导数太难了，不想听。"
		},
		{
			"speaker": "周明远",
			"text": "后面上大学还有更难的微积分呢。",
			"portrait_form": "spirit"
		}
	],
	"math_paper": [
		{
			"speaker": "旁白",
			"text": "这节课周明远并没有被班主任点到回答问题。"
		},
		{
			"speaker": "周明远",
			"text": "呼，还好没再叫到我。"
		},
		{
			"speaker": "周明远",
			"text": "数学课总是给人一种超乎想象的漫长的感觉。"
		},
		{
			"speaker": "周明远",
			"text": "因为只有会的人才能享受数学。",
			"portrait_form": "spirit"
		}
	],
	"english": [
		{
			"speaker": "旁白",
			"text": "这节课是英语课。"
		},
		{
			"speaker": "旁白",
			"text": "高三的英语课一般以讲解卷子和听听力为主。"
		},
		{
			"speaker": "旁白",
			"text": "与其他课不同的是，英语课的讨论和对话更多。"
		},
		{
			"speaker": "旁白",
			"text": "比如，经常能看到王嘉琪和英语老师质疑某道选择题的答案。"
		},
		{
			"speaker": "旁白",
			"text": "讲到续写作文的时候，大家更是天马行空，无奇不有。"
		},
		{
			"speaker": "旁白",
			"text": "每到英语课的时候，课堂都会充满快活的气氛。"
		}
	],
	"physics": [
		{
			"speaker": "旁白",
			"text": "这节课是物理课。"
		},
		{
			"speaker": "旁白",
			"text": "物理老师是一个古板的老先生，不苟言笑。"
		},
		{
			"speaker": "旁白",
			"text": "因此上物理课的气氛一般比较压抑。"
		},
		{
			"speaker": "周明远",
			"text": "每次上课都在讲电磁感应和力学运动学的压轴题。"
		},
		{
			"speaker": "周明远",
			"text": "天天只和那几位物理高手仙家对话，完全不考虑我们差生的感受。"
		},
		{
			"speaker": "旁白",
			"text": "周明远很快又进入了迷离的状态。"
		}
	],
	"chemistry": [
		{
			"speaker": "旁白",
			"text": "这节课是化学课。"
		},
		{
			"speaker": "旁白",
			"text": "每当化学老师讲题需要无实物讲解时，他总会讲这样一个故事。"
		},
		{
			"speaker": "周明远",
			"text": "曾经学校什么化学品和仪器都能拿到班级演示。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "后来有个同学偷了一大块钠，扔进了学校湖里。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "然后可想而知，警察叔叔没收了学校的所有危险化学品。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "从此\"浮溶游响红\"就再也看不到了。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "这个仪器叫什么名字？三颈烧瓶？"
		}
	],
	"biology": [
		{
			"speaker": "旁白",
			"text": "这节课是生物课。"
		},
		{
			"speaker": "周明远",
			"text": "生物应该归为文科课程。"
		},
		{
			"speaker": "周明远",
			"text": "我估计物化政和物化生感受都差不多。"
		},
		{
			"speaker": "周明远",
			"text": "此言差矣。政治可没有生物那样的遗传大题。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "根本就没有这样的家谱。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "旁白",
			"text": "周明远正在艰难地与减数分裂的知识点搏斗着。"
		}
	],
	"line_up": [
		{
			"speaker": "班主任",
			"text": "出去上操了啊，生病的就留在教室就行，其他人在走廊排好队。"
		},
		{
			"speaker": "旁白",
			"text": "经过了一段比较混乱的排队后，同学们成班地到达了操场。"
		}
	],
	"running": [
		{
			"speaker": "旁白",
			"text": "今天的集体活动内容是跑操。"
		},
		{
			"speaker": "周明远",
			"text": "跑操是一件效率极低的运动方式。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "每个人只能跟着大部队蠕动，快也快不起来，时走时停。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "更别提还要喊奇怪的号子了。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "齐声",
			"text": "一，二，三，四！"
		},
		{
			"speaker": "周明远",
			"text": "感觉完全不如放开让同学各自跑各自的。",
			"portrait_form": "spirit"
		}
	],
	"spot_alyina": [
		{
			"speaker": "周明远",
			"text": "唉，那边是不是艾莉娜？",
			"portrait_form": "spirit"
		},
		{
			"speaker": "旁白",
			"text": "你看见远处的观礼台好像有个模糊的飞行的物体。"
		}
	],
	"stand_alyina": [
		{
			"speaker": "艾莉娜",
			"text": "按照时刻表来到操场等跑操了……"
		},
		{
			"speaker": "艾莉娜",
			"text": "但是班级和同学这么多，粥粥在哪个方阵里呢……"
		}
	],
	"collapse_seen": [
		{
			"speaker": "旁白",
			"text": "艾莉娜突然发现有同学在队伍中倒了下来。"
		},
		{
			"speaker": "艾莉娜",
			"text": "那不是粥粥吗？他怎么体力不支倒下了？"
		},
		{
			"speaker": "旁白",
			"text": "艾莉娜准备很快地飞过去。"
		}
	],
	"collapse": [
		{
			"speaker": "旁白",
			"text": "周明远突然感觉眼前一黑，昏了过去。"
		},
		{
			"speaker": "旁白",
			"text": "身边的同学立马扶起了他。"
		},
		{
			"speaker": "周明远",
			"text": "呀嘞？这是早上没吃饭低血糖晕过去了？",
			"portrait_form": "spirit"
		},
		{
			"speaker": "艾莉娜",
			"text": "粥粥！！"
		},
		{
			"speaker": "身边的同学，班主任",
			"text": "快把他送到医务室去。"
		},
		{
			"speaker": "班主任",
			"text": "怎么回事，还能晕倒了呢。"
		},
		{
			"speaker": "周明远",
			"text": "艾莉娜，这具身体应该是早上没吃饭，低血糖了。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "艾莉娜",
			"text": "我跟你一起去医务室！"
		},
		{
			"speaker": "周明远",
			"text": "放心好了，到医务室吃块巧克力就好了。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "艾莉娜",
			"text": "低血糖可是很危险的！"
		}
	],
	"clinic_arrival": [
		{
			"speaker": "旁白",
			"text": "周明远很快被送到了医务室，躺在了床上。"
		},
		{
			"speaker": "医生",
			"text": "这孩子只是低血糖了，没有大碍。"
		},
		{
			"speaker": "医生",
			"text": "我已经给他补糖了，估计一会就会醒了。"
		},
		{
			"speaker": "班主任",
			"text": "好的好的，感谢医生了。"
		},
		{
			"speaker": "旁白",
			"text": "正如医生所料，周明远很快醒了。"
		},
		{
			"speaker": "班主任",
			"text": "周明远，没事吧，有没有哪里感觉受伤了或者怎么了？"
		},
		{
			"speaker": "周明远",
			"text": "我没事。应该是今早没吃饭，低血糖了。"
		},
		{
			"speaker": "班主任",
			"text": "你这孩子……以后在裤兜里带几块巧克力应急啊，吓死我们了。"
		},
		{
			"speaker": "医生",
			"text": "他还需要在医务室观察一段时间。"
		},
		{
			"speaker": "班主任",
			"text": "周明远，那你就先在这呆会吧，一会饭点如果你能去食堂吃饭的话就去吧，但是不要勉强自己。"
		},
		{
			"speaker": "周明远",
			"text": "好的，谢谢老师。"
		},
		{
			"speaker": "旁白",
			"text": "班主任离开了。"
		},
		{
			"speaker": "医生",
			"text": "你就在这里静养，一会我回来给你做些检查。"
		},
		{
			"speaker": "旁白",
			"text": "医生也离开了，医务室里只留下了周明远一个人，周明远闭上了眼睛，静躺起来。"
		}
	],
	"clinic_plan": [
		{
			"speaker": "艾莉娜",
			"text": "还有我呢！"
		},
		{
			"speaker": "周明远",
			"text": "你看，没什么大碍吧。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "趁着这个机会，我们在医务室调查一下吧。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "艾莉娜",
			"text": "如果我们能找到医务室的钥匙，就可以在夜晚也进入医务室调查了！"
		},
		{
			"speaker": "周明远",
			"text": "但是把钥匙拿走会被发现的吧。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "艾莉娜",
			"text": "不用担心欧！我可以打开时序回溯之桥，复制一个“过去的钥匙”，如假包换！"
		},
		{
			"speaker": "周明远",
			"text": "时序回溯之桥？就是你那个传送门？",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "这玩意还能这么用？",
			"portrait_form": "spirit"
		},
		{
			"speaker": "艾莉娜",
			"text": "嘿嘿，刚学的新招，厉害吧。"
		},
		{
			"speaker": "周明远",
			"text": "艾莉娜最厉害了。",
			"portrait_form": "spirit"
		}
	],
	"key_found": [
		{
			"speaker": "艾莉娜",
			"text": "粥粥！我找到医务室钥匙了！"
		},
		{
			"speaker": "周明远",
			"text": "艾莉娜真厉害！可惜我没法离开附身，没怎么帮到你。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "艾莉娜",
			"text": "没关系啦。现在就看我的吧！"
		}
	],
	"spell": [
		{
			"speaker": "艾莉娜",
			"text": "以晨昏为契，以故地为证——"
		},
		{
			"speaker": "艾莉娜",
			"text": "溯流光而上，循旧影而还。"
		},
		{
			"speaker": "艾莉娜",
			"text": "开——！"
		}
	],
	"key_return": [
		{
			"speaker": "周明远",
			"text": "真的拿到钥匙的复制品了唉。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "艾莉娜",
			"text": "我把它放到你的背包里了。"
		},
		{
			"speaker": "周明远",
			"text": "好。",
			"portrait_form": "spirit"
		}
	],
	"doctor_return": [
		{
			"speaker": "旁白",
			"text": "医生回到了医务室。"
		},
		{
			"speaker": "艾莉娜",
			"text": "我先走了，拜拜！"
		},
		{
			"speaker": "艾莉娜",
			"text": "这消毒水味道我实在受不了了。"
		},
		{
			"speaker": "周明远",
			"text": "拜拜，晚上见！",
			"portrait_form": "spirit"
		},
		{
			"speaker": "旁白",
			"text": "医生给周明远又进行了一些简单的检查后，便允许周明远离开了。"
		}
	],
	"not_found": [
		{
			"speaker": "旁白",
			"text": "艾莉娜最终也没有在操场找到周明远。"
		}
	],
	"ceremony": [
		{
			"speaker": "旁白",
			"text": "结束了跑操，接下来同学们前往中央广场进行开学典礼。"
		}
	],
	"gymnastics": [
		{
			"speaker": "旁白",
			"text": "熟悉的广播操音乐在操场上响起。"
		},
		{
			"speaker": "旁白",
			"text": "大家跟着领操员，以慢半拍或一拍的节奏跟着跳着。"
		},
		{
			"speaker": "旁白",
			"text": "当然也有偷懒的同学。"
		},
		{
			"speaker": "旁白",
			"text": "周明远漫不经心地跳着广播操。"
		},
		{
			"speaker": "周明远",
			"text": "再坚持一会，就到大课间了。"
		},
		{
			"speaker": "周明远",
			"text": "等一会大课间，和艾莉娜汇合一下吧。",
			"portrait_form": "spirit"
		}
	]
}
