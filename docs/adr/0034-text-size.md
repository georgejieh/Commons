# ADR 0034: Text size

- Status: Accepted, 2026-11-17, by the agent. The owner judges by playtest.
- Scope: the "largest text size" that P5.1 tests against, and the text scaling P5.2 asks for.

## Why this needs a decision

P5.1 is done when every screen shows its longest strings without clipping at the largest text size. The game has one text size. The checklist names text scaling under P5.2 and says nothing about how many sizes there are, how large the largest is, or what happens to text printed inside a fixed piece of art.

The interface is laid out on a 1920x1080 canvas that stretches to the window. Font sizes are set in three places: the type scale in `data/ui/ui_style.tres`, the theme built from it, and about a hundred sizes set by the pieces themselves.

## Decision

**Three sizes: Standard, Large and Largest.** They multiply every font size by 1.0, 1.15 and 1.3. The factors are data, in `SettingsParams`. The setting is `text_size`, it starts at Standard, and it sits under Display on the settings sheet.

**One function sets every size.** `TextSize.px(base)` returns the size to draw at. The theme and every piece ask it, and a test fails on a font size set any other way. The base sizes stay where they are, so Standard looks as it does today, with the exception below.

**Nothing the player reads is under 14 px on the canvas, at any size.** `TextSize.px` never returns less. A few small labels are below that today and rise to it.

**Paper grows; print fits.** Text on paper that takes its size from its words grows by the whole factor: tooltips, keyword slips, the cheat sheet, the tutorial's slips, notices, speech, the ending and every menu. Text printed inside art of a fixed size, such as a name plate, a badge or a shop card's rules box, grows as far as its box allows. It is never smaller than at Standard and it never clips.

**Art is not text.** Rank glyphs, suit pips, seals and stamps keep their size.

**It applies without a restart.** The settings sheet shows the new size at once. The screen under it is rebuilt when the sheet closes.

## Why these numbers

Valve's Steam Deck review asks that the smallest character on screen be no less than 9 px tall at 1280x800, and recommends 12 px ([Steam Deck and Steam Machine compatibility review](https://partner.steamgames.com/doc/steamhardware/compat), read 2026-11-17). The Deck's screen shows this game's canvas at two thirds of its size.

| Font size on the canvas | Standard | Large | Largest |
| --- | ---: | ---: | ---: |
| 14 px, the least | 9.3 px | 10.7 px | 12.1 px |
| 16 px, the least for names and rules | 10.7 px | 12.3 px | 13.9 px |
| 22 px, body text | 14.7 px | 16.9 px | 19.1 px |

The table gives font sizes on the Deck, before the game rounds a size to whole pixels. Valve counts the height of a character on screen, which is not the same thing as its font size, so these figures show the sizes were chosen with the rule in view and do not show the rule is met. P5.6 measures the Deck build itself.

`tests/integration/test_readability.gd` already holds shop rules and names, Campaign names and the Reforms strip to 16 px, and lets a name fitted to the board shrink to 13 px. The floor raises that 13 to 14. As font sizes, Large brings the 16 px text to 12 px on the Deck, and Largest brings the 14 px floor there.

A factor above 1.3 does not fit the table: the seats, the action bar and the ledger share one screen with the hand.

## What "without clipping" means in the test

At each of the three sizes, at 1920x1080 and at 1280x800:

- every visible control sits inside the visible area;
- no line of text is wider than its box, and no wrapped text has more lines than its box shows;
- text inside a scroll area is checked for width only, since it scrolls;
- each paper that prints one item of a family (a Cadre, a Campaign, a Directive, a Reform, a debuff, an envelope, an ending, a notice, a tutorial step, a villager's line) is checked with every item of that family, so the longest is always among them.

## Amendment, 2026-11-18: screens that are already full

The first build found four screens with no room left at Standard: the state store, the black market, the ending and the cheat sheet. At Largest the store came to 1,162 px of a 1,080 px canvas and the ending to 1,234 px. The rules above do not say what gives. These do, in this order:

1. **Display type holds.** A base size of 40 px or more, which is the title and headline steps and the ending's title, does not grow. At Standard it is already larger than body text is at Largest (22 px by 1.3 is under 29 px).
2. **Margins give way.** On a page that would overflow, the outer margin and the gaps between rows shrink before anything else does, to no less than 24 px of margin and half of each gap.
3. **Print fits,** as above: text in a fixed box fits down, never below its Standard size.
4. **Prose scrolls on its own paper.** The ending's story, the cheat sheet and the settings sheets scroll inside their paper when they are too long. Their buttons stay on screen, the scroll follows the focus, and the arrow keys and the stick move it.
5. **A shop never scrolls.** Everything for sale is on screen at once. If rules 1 to 3 do not make room, the shop's rules boxes and Directive documents count as fixed boxes and fit down.

Never: a clipped line, text below its Standard size, or art made smaller.

**The table mid-round.** "The screen under it is rebuilt when the sheet closes" holds for every screen but the table in a round. Rebuilding it there would lose a need being set, an open reading picker and plays not yet acted out. The table's themed text changes at once, and its own pieces take the new size at the next deal, with the hand's sort kept. While a round is in play the settings sheet says so in one line. The mixed state in between must not clip, and a test holds that.

## Amendment, 2026-11-19: the table's pieces against one another

The cloud frames at Largest showed pieces of the table running into each other, which the clipping test could not see because it compares a control with its own box. A test now puts the longest of everything on the table and checks every pair of pieces. It found three places where the rules above do not say what gives:

- The rules strip under the Cadre board cannot hold three debuffs above the trick, even at Standard: 314 px of text in 96 px of room, and 484 px at Largest. Moving the trick down as far as the status line allows gives the strip 154 px, which holds neither three debuffs in full nor, at the worst, their names (254 px).
- The left column at Largest is 29 px short for the seat, the Campaign tray and the brigade notice.
- A seat that shows what an information Cadre reveals grows by 76 px or more at Standard and covers what is under it at every size.

These settle them:

6. **The rules in force are on a slip under the right seat,** as the Campaign tray is under the left one. The strip under the Cadre board is gone and the trick stays where it is. The slip's room runs from the right seat's foot to the top of the action column at its tallest. That wall held dressing: the poster about the player's household moves to the strip's old place under the Cadre board, as a wide notice whose type fits its box, and the empty chair stays, with the slip in front of it when the slip is tall.
7. **A slip that does not fit its room steps down, one form at a time.** In full: every rule with its text, as before. By name: the wild ranks' line, the debuffs by name, the table's rules by name, a struck name for a lifted debuff, and one line that points to the Rules sheet. Table-wide Cadres are not named, because their cards are on the board. By name with the type fitted down, never below Standard. Counted: the wild ranks' line, how many rules are in force, and the pointer. The slip never shows some rules in full and others by name. The Rules sheet always has every rule in force in full.
8. **In the left column, dressing gives way before information.** When the seat, the tray and the brigade notice do not all fit, the tray drops its heading, since each leaflet already says what it is. If that is not enough, or an armed Campaign's Use and Cancel need the room, the brigade notice is taken down until there is room again. If an armed Campaign still does not fit after rule 9, what a Cadre reveals about the left seat is put away until the Campaign is used or cancelled.
9. **What a Cadre reveals about a seat is print across the sheet's whole width,** under the portrait, not in the column beside it. When its column is still short after the steps above, with the slip by name on the right, its type fits down, never below Standard. Only then is the slip counted.

A rule's full text is one key away at every moment, and the slip always shows that rules are in force. What is lost at the worst is reading a rule's text, or its name, without opening the sheet.

## Alternatives rejected

- **A strip that always shows every rule in full.** No place on the table holds three debuffs, the table's rules and the wild ranks at once, at any size.
- **Moving the trick down to make room under the Cadre board.** Built and measured: 154 px at every size, 100 px short of the names alone at the worst.
- **Names only, always.** Simpler, and early in a Set, when one new rule is in force and there is room for it, the player would have to open a sheet to read it.
- **Scaling the whole canvas.** `content_scale_factor` enlarges art and layout with the text, so a larger size shows less of a table that is already full.
- **A slider.** Every value would need the same proof. Three sizes can each be tested on every screen.
- **Leaving fixed boxes at Standard.** Simpler, and most of the table's text would not change.

## Consequences

- `SettingsParams` gains `text_size`, `text_scales` and `least_text_px`. Settings files without the key load at Standard.
- `tests/integration/test_steam_deck_layout.gd`'s check runs at every size and at both screens.
- The cloud playtest renders the demo screens once more at Largest.
- P5.2's text scaling is done by this; the rest of P5.2 is unchanged.
