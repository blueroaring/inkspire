extends RefCounted
## Player-facing notices and build-time engine notices share the same source.
const ROOT := "res://data/tower_legal/"

static func read_notice(file: String) -> String:
	var path := ROOT + file
	if not FileAccess.file_exists(path):
		push_error("Missing tower notice: " + path)
		return "许可文件未能读取，请使用完整的游戏发布包。"
	return FileAccess.get_file_as_string(path)

static func engine_license() -> String:
	return "Godot Engine " + String(Engine.get_version_info().string) + "\nhttps://godotengine.org/\nhttps://godotengine.org/license/\n\n" + Engine.get_license_text()

static func engine_components() -> String:
	var lines := PackedStringArray(["Godot Engine — Third-party notices", "Engine version: " + String(Engine.get_version_info().string), "https://godotengine.org/license/", "", "Component copyright and license mappings", ""])
	for component in Engine.get_copyright_info():
		lines.append(String(component.name))
		for part in component.parts:
			lines.append("  License: " + String(part.license))
			for copyright in part.copyright:
				lines.append("  " + String(copyright))
			lines.append("  Files: " + ", ".join(part.files))
		lines.append("")
	lines.append("Full license texts\n")
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for key in names:
		lines.append("===== " + String(key) + " =====\n" + String(licenses[key]) + "\n")
	return "\n".join(lines)

static func sections() -> Array[Dictionary]:
	return [
		{"id":"credits", "title":"制作名单", "file":"CREDITS.txt"},
		{"id":"music", "title":"音乐与作者", "file":"MUSIC.txt"},
		{"id":"art", "title":"美术与音效", "file":"ART.txt"},
		{"id":"rights", "title":"使用与权利声明", "file":"LICENSE.txt"},
		{"id":"fonts", "title":"字体许可 · OFL", "file":"FONTS.txt"},
		{"id":"engine", "title":"Godot 引擎 · MIT", "file":""},
		{"id":"components", "title":"引擎第三方组件", "file":""},
		{"id":"cc0", "title":"CC0 许可原文", "file":"CC0-1.0.txt"},
	]

static func section_text(section: Dictionary) -> String:
	match String(section.id):
		"engine": return engine_license()
		"components": return engine_components()
	return read_notice(String(section.file))
