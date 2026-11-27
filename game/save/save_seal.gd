class_name SaveSeal
extends RefCounted
## The keyed checksum on every save (ADR 0022): HMAC-SHA256 over one canonical form of
## what the file holds, read back as JSON. The key is in the source, so the seal stops
## hand edits and nothing more. The form is built from the parsed values, never from the
## text, so the writer and the reader seal exactly the same thing: keys in sorted order,
## every number as the bits of the double JSON reads it as, every string escaped. A file
## whose text changes but whose values do not, such as one reformatted by an editor,
## still verifies.

## The key the checksum is made with.
const KEY: String = "commons-the-brigade-books-v1"
## The length of a seal, in hex digits.
const HEX_LENGTH: int = 64


## The seal over a save's schema version, data and extras, as hex.
static func of(version: int, data: Variant, extras: Variant) -> String:
	var form: String = _canonical({"schema_version": version, "data": data, "extra": extras})
	var crypto: Crypto = Crypto.new()
	var digest: PackedByteArray = crypto.hmac_digest(
		HashingContext.HASH_SHA256, KEY.to_utf8_buffer(), form.to_utf8_buffer()
	)
	return digest.hex_encode()


## True when seal is a seal's shape: 64 hex digits.
static func is_shaped(seal: Variant) -> bool:
	if not seal is String:
		return false
	var text: String = seal
	return text.length() == HEX_LENGTH and text.is_valid_hex_number()


## One text for a value, the same however the value was built: a dictionary by its sorted
## keys, a number by its bits as a double, a string escaped as JSON escapes it.
static func _canonical(value: Variant) -> String:
	if value is Dictionary:
		var dictionary: Dictionary = value
		var keys: Array[String] = []
		for key: Variant in dictionary:
			keys.append(str(key))
		keys.sort()
		var parts: PackedStringArray = []
		for key: String in keys:
			parts.append(JSON.stringify(key) + ":" + _canonical(dictionary[key]))
		return "{" + ",".join(parts) + "}"
	if value is Array:
		var items: Array = value
		var parts: PackedStringArray = []
		for item: Variant in items:
			parts.append(_canonical(item))
		return "[" + ",".join(parts) + "]"
	if value is int or value is float:
		return "#" + RunState.float_text(float(value))
	if value is String:
		return JSON.stringify(value)
	if value is bool:
		return "true" if value else "false"
	return "null"
