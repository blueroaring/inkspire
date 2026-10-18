extends Control
## Painted, non-interactive skill lettering. Timing belongs to the attack director.
const FONT := preload("res://assets/fonts/noto_serif_sc/title.tres")
var skill := ""
var caption := ""
var rank := 0
var tint := Color("e7b8d8")
var age := 0.0

func _ready() -> void:
	name = "EnemyActionTitle"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	age += delta
	queue_redraw()

func _draw() -> void:
	var enter := clampf(age/0.28,0,1)
	var ease := 1.0-pow(1.0-enter,3)
	var middle := size*Vector2(0.5,0.46)
	var font_size := 68 if rank == 2 else 51 if rank == 1 else 34
	# Long skill names fit their frame, including the authored final-phase suffix.
	while FONT.get_string_size(skill,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > size.x*0.80 and font_size > 24: font_size -= 1
	var text_size := FONT.get_string_size(skill,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var width := maxf(text_size.x+140,size.x*0.64)
	draw_set_transform(middle+Vector2((1-ease)*64,0),-0.025 if rank>0 else 0.0,Vector2(1+(1-ease)*0.17,1))
	# Irregular dry-brush silhouette: several torn strokes, rather than a label box.
	for row in 7:
		var y := (row-3)*10.0
		var extent := width*(0.43+0.045*sin(row*7.1))
		var polygon := PackedVector2Array([Vector2(-extent-30,y-8),Vector2(extent+22,y-13),Vector2(extent-15,y+1),Vector2(extent+43,y+5),Vector2(-extent+25,y+13),Vector2(-extent-48,y+6)])
		draw_colored_polygon(polygon,Color("080510",0.68*ease))
	for i in 23:
		var p := Vector2(sin(i*17.3)*width*0.55,cos(i*8.9)*49)
		draw_line(p,p+Vector2(13+float(i%5)*4,-2),Color(tint,0.14*ease),1,true)
	var base := Vector2(-text_size.x/2,FONT.get_ascent(font_size)-text_size.y/2-3)
	# Offset lacquer-red impression, fine gold bevel, warm lit face.
	draw_string_outline(FONT,base+Vector2(4,5),skill,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,10,Color("3a071c",ease))
	draw_string_outline(FONT,base,skill,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color("1c0a1b",ease))
	draw_string(FONT,base+Vector2(0,1),skill,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("c99364",ease))
	draw_string(FONT,base-Vector2(0,1),skill,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("ffe8cc" if rank<2 else "ffbdc5",ease))
	if enter < 1:
		draw_string(FONT,base+Vector2((1-ease)*-55,0),skill,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(tint,(1-ease)*0.45))
	var line_y := text_size.y*0.47+10
	for side in [-1,1]:
		var start := Vector2(side*24,line_y)
		var end := Vector2(side*width*0.47,line_y-3)
		draw_line(start,end,Color(tint,ease*.7),1,true)
		var tip := Vector2(side*(width*.47+12),line_y-3)
		draw_colored_polygon(PackedVector2Array([tip+Vector2(-7,0),tip+Vector2(0,-4),tip+Vector2(7,0),tip+Vector2(0,4)]),Color(tint,ease))
	draw_line(Vector2(-5,line_y-5),Vector2(5,line_y+5),Color(tint,ease),2,true)
	draw_line(Vector2(5,line_y-5),Vector2(-5,line_y+5),Color(tint,ease),2,true)
	if caption != "":
		var small := 18 if rank>0 else 15
		var cs := FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,small)
		draw_string(FONT,Vector2(-cs.x/2,line_y+34),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,small,Color("d9b9b2",ease*.85))
	draw_set_transform(Vector2.ZERO)
