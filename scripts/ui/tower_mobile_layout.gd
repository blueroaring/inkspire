extends RefCounted

static func readable_tree(root: Node, minimum: int = 28) -> void:
	for child in root.get_children():
		if child is Label or child is RichTextLabel:
			child.add_theme_font_size_override("font_size" if child is Label else "normal_font_size", maxi(minimum, child.get_theme_font_size("font_size" if child is Label else "normal_font_size")))
		if child is BaseButton and child.get_parent() is Container:
			child.custom_minimum_size.y = maxf(child.custom_minimum_size.y, 92)
		readable_tree(child, minimum)
