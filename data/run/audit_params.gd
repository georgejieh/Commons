class_name AuditParams
extends Resource
## How declared needs are checked before a Commons split (P4.3). Each declaring seat
## rolls one die; a face at or below the audit faces means its claim is checked. The
## audit hook can add faces, as the Work-Point Audit debuff does.

## Sides on the audit die.
@export var die_sides: int = 6
## Faces that mean an audit, before the informer and the hook.
@export var base_faces: int = 1
## Added while a family in informer_families is in the village.
@export var informer_faces: int = 1
## The most faces an audit can have, below die_sides, so an audit is never certain.
@export var max_faces: int = 5
@export var informer_families: Array[String] = ["zhou"]
## The face each declaring seat's die shows, in seat order, in place of its roll; empty
## rolls them all. Only the arrival's own copy sets it, round by round (ADR 0026).
@export var shown_faces: PackedInt32Array = PackedInt32Array()
