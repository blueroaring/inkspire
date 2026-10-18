extends RefCounted
## AES-256-CBC + encrypt-then-HMAC-SHA256. Authenticate BEFORE decrypting.
## A client-held key deters file editing, not a reverse-engineered client.
const SCHEMA := "school-tower-sealed-v1"
const KEY_PATH := "res://data/tower_report_keys.json"

static func _config() -> Dictionary:
	if not FileAccess.file_exists(KEY_PATH): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KEY_PATH))
	return parsed if parsed is Dictionary else {}

static func _key(config: Dictionary, id: String, kind: String) -> PackedByteArray:
	var value := String(config.get("keys", {}).get(id, {}).get(kind, ""))
	if value.length() != 64 or not value.is_valid_hex_number(false): return PackedByteArray()
	return value.hex_decode()

static func ready() -> bool:
	var config := _config()
	var id := String(config.get("active", ""))
	return _key(config, id, "encryption").size() == 32 and _key(config, id, "authentication").size() == 32

static func _message(envelope: Dictionary) -> PackedByteArray:
	return ("%s\n%s\n%s\n%s\n%s" % [SCHEMA, envelope.purpose, envelope.key_id, envelope.iv, envelope.ciphertext]).to_utf8_buffer()

static func seal(payload: Dictionary, purpose: String) -> Dictionary:
	var config := _config()
	var id := String(config.get("active", ""))
	var enc := _key(config, id, "encryption")
	var auth := _key(config, id, "authentication")
	if enc.size() != 32 or auth.size() != 32: return {}
	var crypto := Crypto.new()
	var iv := crypto.generate_random_bytes(16)
	if iv.size() != 16: return {}
	var bytes := JSON.stringify(payload).to_utf8_buffer()
	var padding := 16 - bytes.size() % 16
	for i in padding: bytes.append(padding)
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_ENCRYPT, enc, iv) != OK: return {}
	var ciphertext := aes.update(bytes)
	aes.finish()
	if ciphertext.size() != bytes.size(): return {}
	var envelope := {"schema":SCHEMA, "purpose":purpose, "key_id":id, "iv":Marshalls.raw_to_base64(iv), "ciphertext":Marshalls.raw_to_base64(ciphertext)}
	envelope.tag = crypto.hmac_digest(HashingContext.HASH_SHA256, auth, _message(envelope)).hex_encode()
	return envelope

static func open(envelope: Dictionary, purpose: String) -> Dictionary:
	if envelope.size() != 6 or envelope.get("schema") != SCHEMA or envelope.get("purpose") != purpose: return {}
	for field in ["key_id", "iv", "ciphertext", "tag"]:
		if not envelope.get(field) is String: return {}
	var config := _config()
	var enc := _key(config, envelope.key_id, "encryption")
	var auth := _key(config, envelope.key_id, "authentication")
	if enc.size() != 32 or auth.size() != 32: return {}
	var tag: String = envelope.tag
	if tag.length() != 64 or not tag.is_valid_hex_number(false): return {}
	var crypto := Crypto.new()
	var expected := crypto.hmac_digest(HashingContext.HASH_SHA256, auth, _message(envelope))
	if not crypto.constant_time_compare(expected, tag.hex_decode()): return {}
	var iv := Marshalls.base64_to_raw(envelope.iv)
	var ciphertext := Marshalls.base64_to_raw(envelope.ciphertext)
	if iv.size() != 16 or ciphertext.is_empty() or ciphertext.size() % 16 != 0: return {}
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_DECRYPT, enc, iv) != OK: return {}
	var bytes := aes.update(ciphertext)
	aes.finish()
	if bytes.is_empty(): return {}
	var padding := int(bytes[-1])
	if padding < 1 or padding > 16 or padding > bytes.size(): return {}
	for i in range(bytes.size() - padding, bytes.size()):
		if bytes[i] != padding: return {}
	bytes.resize(bytes.size() - padding)
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}
