class_name FamilyDef
extends Resource
## One household of the village (P4.5): a surname, an inherited personality, a voice, a
## portrait, its own speech lines and when it joins the village. Sent-down youth
## templates are FamilyDefs too, given a new surname when they arrive.

enum Unlock { START, RUNS, LANDLORD_ENDING }

@export var id: String
## The surname shown at the table.
@export var name_key: String
## Decorative only, for stamps and posters.
@export var hanzi: String
@export var personality: Personality
@export var voice: VoiceProfile
@export var portrait: Texture2D
## Where the head is, as fractions of the portrait, so every box crops around the face.
@export var portrait_face: Rect2
## Lines only this family says. An event with none here falls back to the shared book.
@export var speech: SpeechBook
@export var unlock: Unlock = Unlock.START
## Finished runs before a RUNS family joins (P4.14 tracks them).
@export var unlock_runs: int = 0
## Starts at the personality's tier and gains one every VillageBook.rise_sets Sets seated.
@export var rising: bool = false
## Copies the player's habits instead of its own (P4.7 fills these in).
@export var mirrors_player: bool = false
