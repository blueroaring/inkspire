extends Node
## Browser-owned file selection/download, isolated from the desktop and Android paths.
var _file_callback: JavaScriptObject
var _visibility_callback: JavaScriptObject
var _text_callback: JavaScriptObject
var _text_control: LineEdit
var _pending: Callable
var _serial := 0

func _ready() -> void:
	if not OS.has_feature("web"): return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_file_callback = JavaScriptBridge.create_callback(_receive)
	_visibility_callback = JavaScriptBridge.create_callback(_visibility)
	_text_callback = JavaScriptBridge.create_callback(_text_done)
	JavaScriptBridge.eval("""
	window.inkspireFiles = {
	  pick(callback, accept) {
	    const input = document.createElement('input');
	    input.type = 'file'; input.accept = accept;
	    input.style.display = 'none'; document.body.append(input);
	    input.addEventListener('cancel', () => { input.remove(); callback('', null, ''); }, {once:true});
	    input.addEventListener('change', async () => {
	      const file = input.files[0]; input.remove();
	      if (!file) { callback('', null, ''); return; }
	      if (file.size > 134217728) { callback('', null, '文件超过128MB，无法导入。'); return; }
	      try { callback(file.name, await file.arrayBuffer(), ''); }
	      catch (_) { callback('', null, '浏览器无法读取此文件，请重新选择。'); }
	    }, {once:true});
	    input.click();
	  },
	  watch(callback) { document.addEventListener('visibilitychange', () => callback(document.hidden)); },
	  edit(callback, value, placeholder, maxLength) {
	    const dialog = document.createElement('dialog');
	    dialog.style.cssText='max-width:600px;width:80%;box-sizing:border-box;background:#172b34;color:#f2ead7;border:1px solid #cbb485;border-radius:12px;padding:24px;font:20px system-ui';
	    const label=document.createElement('label'); label.textContent=placeholder || '输入文字';
	    const input=document.createElement('input'); input.type='text'; input.value=value;
	    if(maxLength>0) input.maxLength=maxLength;
	    input.enterKeyHint='done'; input.autocomplete='off';
	    input.style.cssText='box-sizing:border-box;width:100%;min-height:56px;font:24px system-ui;margin:20px 0';
	    label.append(input); dialog.append(label);
	    let composing=false, closed=false;
	    input.addEventListener('compositionstart',()=>composing=true);
	    input.addEventListener('compositionend',()=>composing=false);
	    function finish(accept) {
	      if(closed || composing) return;
	      closed=true; const result=input.value; dialog.close(); dialog.remove();
	      document.getElementById('canvas').focus(); callback(accept,result);
	    }
	    input.addEventListener('keydown',e=>{if(e.key==='Enter' && !e.isComposing && !composing){e.preventDefault();finish(true);}});
	    for(const [text,accept] of [['完成',true],['取消',false]]) {
	      const button=document.createElement('button');button.type='button';button.textContent=text;
	      button.style.cssText='min-height:52px;min-width:120px;margin:8px;font:20px system-ui';
	      button.onclick=()=>finish(accept);dialog.append(button);
	    }
	    dialog.addEventListener('cancel',e=>{e.preventDefault();finish(false);});
	    document.body.append(dialog);dialog.showModal();input.focus();input.select();
	  }
	};
	""", true)
	JavaScriptBridge.get_interface("inkspireFiles").watch(_visibility_callback)

func pick(accept: String, selected: Callable) -> void:
	_pending = selected
	JavaScriptBridge.get_interface("inkspireFiles").pick(_file_callback, accept)

func _receive(arguments: Array) -> void:
	if not _pending.is_valid(): return
	var selected := _pending
	_pending = Callable()
	var error := String(arguments[2])
	if not error.is_empty():
		preload("res://scripts/ui/tower_mobile.gd").instance().show_help("文件导入失败", error)
		return
	if String(arguments[0]).is_empty(): return
	_serial += 1
	var folder := "user://web-import-%d" % _serial
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return
	var path := folder.path_join(String(arguments[0]).get_file().validate_filename())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return
	file.store_buffer(JavaScriptBridge.js_buffer_to_packed_byte_array(arguments[1]))
	file.close()
	selected.call(path)

func download(path: String, filename: String, mime: String) -> void:
	JavaScriptBridge.download_buffer(FileAccess.get_file_as_bytes(path), filename, mime)
	DirAccess.remove_absolute(path)

func edit(control: LineEdit) -> void:
	if is_instance_valid(_text_control): return
	_text_control = control
	JavaScriptBridge.get_interface("inkspireFiles").edit(_text_callback, control.text, control.placeholder_text, control.max_length)

func _text_done(arguments: Array) -> void:
	if is_instance_valid(_text_control):
		var control := _text_control
		_text_control = null
		control.release_focus()
		if bool(arguments[0]):
			control.text = String(arguments[1])
			control.text_changed.emit(control.text)

func _visibility(arguments: Array) -> void:
	var router := preload("res://scripts/ui/tower_mobile.gd").instance()
	if router != null:
		router.suspend_application(bool(arguments[0]))
