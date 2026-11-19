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

## Alternatives rejected

- **Scaling the whole canvas.** `content_scale_factor` enlarges art and layout with the text, so a larger size shows less of a table that is already full.
- **A slider.** Every value would need the same proof. Three sizes can each be tested on every screen.
- **Leaving fixed boxes at Standard.** Simpler, and most of the table's text would not change.

## Consequences

- `SettingsParams` gains `text_size`, `text_scales` and `least_text_px`. Settings files without the key load at Standard.
- `tests/integration/test_steam_deck_layout.gd`'s check runs at every size and at both screens.
- The cloud playtest renders the demo screens once more at Largest.
- P5.2's text scaling is done by this; the rest of P5.2 is unchanged.
