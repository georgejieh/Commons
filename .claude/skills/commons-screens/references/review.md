# Reading a frame

You cannot judge a screen you have not seen. After a build, get frames from the cloud playtest (`CLAUDE.md` has the command) and read them as images. Read the plain walk, the access walk (grayscale, largest text, reduced motion) and, where the screen changes with corruption, an early and a late stage.

## Fails at once

Any one of these fails the screen, whatever else is good:

- A script error, a misclick in the walk, or a missing frame.
- Text outside its frame, cut off, or lying on another piece.
- Text that cannot be read: over a busy part of the art, or grey on grey. Judge it on the worst patch it crosses, at the latest corruption stage, not on the cleanest.
- A face in the art covered by a button or a line of type.
- A tooltip or slip covering the thing it explains, or lying over a modal. Order from the top: modal, tooltip, HUD, table.
- A number with no label, or a label that is a placeholder.
- A piece that ends an animation off its resting place.
- Anything that needs colour alone, or motion alone, to be understood.

## Mark each from 1 to 10

1. **First glance.** In three seconds: one place to look, and you know what the screen is for.
2. **The moment.** One thing here arrives or answers in its own way, and it is the thing that matters. A routine result and a great one do not look alike.
3. **Type.** Poster face for names and totals, typewriter for the ledger, nothing else. No more than six sizes on a screen, none one or two pixels apart. A number that counts does not change width as it rolls.
4. **Order and space.** Edges line up. One padding inside each kind of sheet. Label and value on one baseline. Sheets in a row stand level. Room is left on purpose, not left over.
5. **Colour.** Paper, ink, and a little vermilion and gold. The accents cover a small part of the frame and each means one thing.
6. **Art and paper together.** The picture is cropped and placed for this screen. Text and the picture's subject never meet.
7. **Motion.** Read from frames at held points. Pieces arrive in order and are whole in about a second. Each ends exactly at rest. Nothing moves to fill a quiet page. See [motion.md](motion.md).
8. **Under stress.** The largest text, the smaller window, the longest name, the biggest number, the empty list: still whole, still readable.
9. **Words.** Short, in the game's own terms, true to the state. (`commons-prose` owns the wording.)
10. **This game only.** Take the title off. Could the screen be reskinned for another game by changing a logo? If so it has no world yet. Paper has edges, stamps, wear. Not every stat sits in a box.

**The bar is an average of 8 with nothing under 7.** A first build usually lands at 6 or 7.

## Fixing

1. Write the three weakest marks and one change for each, in values: "the total from 28 to 40 px and gold", "0.12 s wind-up before a villager's cards leave", "padding 16 on all four sides of the stall".
2. Make them, shoot again, read again.
3. Three rounds at most. Past that, change the idea.

Common fixes:

- **It reads flat.** Make the hero larger and everything else smaller or fainter. Cut a piece. Give the result a size that fits what happened.
- **It reads busy.** Take boxes off. Merge two things that say the same. Hide what is only needed sometimes.
- **It reads like an app.** Replace a panel with paper that has an edge. Hang a stat on the thing it describes. Weight the layout to one side.
- **The text fights the art.** Move the text to the calm part, or move the crop.

## A second reader

Marks drift upward when the builder gives them, and a reviewer who has read three rounds starts to forgive. For a finished screen, hand the frames and this file to a subagent that has seen none of the work. Ask for a mark and one sentence of evidence on each point, and fixes written as "done when" something can be seen. Then check its lowest marks yourself against the frames.

## Measure before calling it a fault

An eye reading a shrunken frame is wrong about brightness and about small gaps. A piece on a dark ground looks lit; two edges a few pixels apart look as if they touch.

- **Brightness and dimming.** Sample the pixels of the same piece in two frames (with and without the sheet, the dim or the stage) and compare the numbers. A piece that fell by the same share as its neighbours is dimmed, however it looks.
- **Overlap, clipping and gaps.** Read the playtest's `LAYOUT` lines (`tools/layout_audit.gd`) for the frame, or assert the rectangles in a test. A reader's "touches" or "covers" is a place to measure, not a finding.
- **A checker that finds nothing** is tested before it is believed.
