extends RefCounted
## Fixture: reaches randomness or evaluation indirectly.


func bytes() -> PackedByteArray:
	return Crypto.new().generate_random_bytes(1)
