# Commons style bible

The rules every image in `art/` follows (P3C.1). The direction is [ADR 0015](../docs/adr/0015-art-direction.md): Mao-era propaganda posters, distorted by cosmic horror until no real nation can be named. The look changes over a profile through ten hidden corruption stages ([ADR 0018](../docs/adr/0018-escalating-corruption.md)), so most key assets exist in several stage versions. The interface itself stays plain ink and paper (`design/UI_LANGUAGE.md`).

## Palette

[`palette.json`](palette.json) lists 27 colors as hex values. Eight have named UI roles, and nineteen are poster print inks sampled from the approved art. The cleanup script (P3C.3) quantizes every finished image to this palette, so assets from different generations still read as one print run. A color with a UI role keeps that one meaning everywhere:

| Name | Hex | Meaning |
| --- | --- | --- |
| ink | `#1e1a16` | Text, outlines, line work |
| paper | `#efe3c8` | UI paper ground |
| paper_light | `#f6edd9` | Pinned cards and notices |
| stamp_red | `#b02a17` | Zeal, the landlord, stamps |
| gold | `#e0b84a` | Landlord trim, gilt |
| coupon_green | `#3f6338` | Ration coupons, and nothing else |
| hill_blue | `#6f8a9a` | Distant hills and shade, early stages only |
| field_green | `#8a9a4a` | Fields and leaves, early stages only |

Blue and green leave the art as corruption rises. By stage 6 the art is printed in red, ochre, cream and ink alone.

## Print

- **Line.** One ink weight per asset: about 3 px at 1080p for the main contours, and about half that for hatching. No soft airbrush outlines.
- **Fill.** Flat silkscreen blocks with two or three tones per color. Gradients appear only in sun rays and halos.
- **Texture.** Aged poster paper: fold lines, foxing, tea rings and torn edges. Print misregistration of 1 to 3 px on large red blocks. The paper ages with each stage, but the play area always stays calm and low in contrast, so the cards read clearly.
- **Light.** One warm source, top center, where the sun or eye sits in each poster. On the table, the lamp sits in the same place.
- **Composition.** Heroic upward poses, crowds in rows, banners on the diagonal, the sun at the top. Key detail goes at the edges, never under where cards lie.

## Fixed prompt prefix

Every generation prompt starts with this prefix, then describes the subject and gives its corruption stage from the table below:

> Aged 1960s village silkscreen propaganda poster, flat ink-outlined print with slight misregistration, red, gold and cream inks on worn paper, no text, no lettering, no flags with emblems, no stars, no real people.

Edits of an existing asset attach it as the edit target and say what must stay unchanged. Every result is logged in `art/sources/manifest.csv` (P3C.2).

## The ten corruption stages

The player never sees which stage they are in. Each stage keeps the one before it and adds a little more. An asset doesn't need every stage: a missing stage uses the nearest earlier one (`ArtStages`). Most assets carry stages 0, 2, 4, 6 and 9.

| Stage | What the art shows | Example in the game |
| --- | --- | --- |
| 0 | Sincere, cheerful propaganda with nothing wrong in it. A plain red sun, normal eyes, wheat and tools, blue hills, clean paper | `art/backdrops/stages/table_surface_s0.png` |
| 1 | One wrong detail, easy to miss: one face in a crowd not quite smiling, or a shadow pointing the wrong way | |
| 2 | Smiles a little too wide and too alike. The sun's rays are slightly uneven | |
| 3 | A faint ring inside the sun. One raised hand too many in the crowd | |
| 4 | The ring reads as an iris. A few rays taper into thin fingers. All the smiles are identical | `art/backdrops/stages/table_surface_s4.png` |
| 5 | Pale outlines of hands in the rays. Eyes in the background clouds. Blue and green are nearly gone | |
| 6 | The sun is an eye with eyelids. Faces turn blank or show only their whites. The paper is torn and stained | |
| 7 | The eye stares outward. Its rays are reaching arms, and the crowd raise their arms toward it | `art/backdrops/table_surface.png` (current art) |
| 8 | Shapes too large to see whole in the clouds, and limbs among the banners. The crowd shares one face | |
| 9 | Full cosmic horror. The eye fills the sky, and hands come out of everything. Still printed as a poster, still with no gore | `art/cards/card_back.png` (current art) |

**Horror rules.** Absence over spectacle: no blood, wounds or bodies, ever. The horror is in the eye, the hands, and smiles held too long. Each stage stays readable as the same poster, so the player notices the change rather than watching it happen.

## Reference images

These are approved assets in the repository. Use them as `--ref` attachments when generating:

- Style: `art/backdrops/title.png`.
- Portrait framing: `art/portraits/portrait_wang_face.png`. The whole head sits inside the frame, centered, in 4:5.
- Stage 0, the innocent end: `art/backdrops/stages/table_surface_s0.png`.
- Stage 9, the horror end: `art/cards/card_back.png`.

The private board in `design/reference/` is never used as image input.

## Do and don't

| Do | Don't |
| --- | --- |
| Use upturned faces, banners, wheat, rays and crowds | Use real flags, the star, the hammer and sickle, or any national emblem |
| Use invented, unreadable stamp shapes | Use Chinese characters or any lettering in the art |
| Keep the corruption in the eye, the hands and the smiles | Use gore, bodies, or suffering played for shock |
| Keep the play area calm and low in contrast | Put detail where cards lie |
| Keep each villager's whole head inside the frame, centered in 4:5 | Crop a face at the frame edge |
| Treat red as the poster's ink | Use red to mean anything but Zeal or the landlord in the UI |
| Make stage variants by editing the existing asset | Regenerate a stage from scratch, which breaks the continuity between stages |
