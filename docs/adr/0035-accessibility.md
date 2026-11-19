# ADR 0035: Keys the player can change, and nothing told by colour alone

- Status: Accepted, 2026-11-17, by the agent. The owner judges by playtest.
- Scope: P5.2. Text size is [ADR 0034](0034-text-size.md). The reduced-motion setting was built in P3B and stays as it is; one fix below changes what the tutorial shows under it.

## Why this needs a decision

P5.2 asks for remappable keys and for suits and markers that can be told apart by shape, and is done when a full run is playable in grayscale with reduced motion and the largest text size. The checklist does not say which keys can change, what happens when two actions want one key, whether the gamepad is included, what "by shape" covers beyond the cards, or how a grayscale run is played and judged.

## What is there today

Nine actions in `project.godot` have one key and one gamepad button each: Play (Enter), Pass (Space), Hint (H), Sort (S), Rules (R), cursor left and right (the arrow keys), pick a card (Up) and Campaigns (C). The keys are bound by position, so those letters are where they sit on a US keyboard. The game never shows the player these keys.

Two checks were made on 2026-11-17 at commit `6c4fc3e`:

- A read of `ui/` for every colour chosen from state. It covered the cards, the theme, the tutorial and every table and screen file where a search found a colour next to a condition. It did not open about ten screen files whose only hits were fades and fixed colours, or the shaders, so it is thorough and not proven complete.
- Seven frames of cloud playtest run 44199644631 (`playtest/p5-0`), converted to grayscale with Pillow's `convert("L")`: all card faces, the table at the bid and mid-round, the state store, the black market, the Commons split and the board with both meters high.

Most state already has words or a shape: the suits have four shapes, the jokers are labelled Small and Big, the landlord has a tag, audit verdicts are written out, and a confiscated Cadre is crossed through. Three states are marked by colour alone:

| Where | What only the colour says |
| --- | --- |
| The card count on a seat (`seat_panel.gd`) | The count is printed either way; red ink is the only warning that a player is down to two cards or fewer |
| A hinted card (`card_view.gd`) | A gold edge, where a selected card has a red one and a lift |
| The tutorial's slip refusing a click, under reduced motion (`tutorial_slip.gd`) | A red border drawn for 0.6 s; without reduced motion the slip pulses |

Two more are told by fading: a button that cannot be pressed, and older plays on the trick pile, which also lie under the newest.

## Decision

### Keys

**The nine actions' keys can be changed. Menu keys cannot.** `ui_accept` and `ui_cancel` keep Enter and Escape. The Controls page itself backs out on Escape and presses the focused button on Enter, so no set of bindings can lock a player out of it. A test holds this.

**One bare key per action, by position.** A binding is a physical key with no modifier, so it sits in the same place on any keyboard layout. The Controls page shows the label printed on that key in the player's layout, from `DisplayServer.keyboard_get_label_from_physical` and `OS.get_keycode_string`.

**A key already in use swaps.** Binding Hint to S when Sort has S gives Sort the key Hint had. No action is ever left without a key and no key ever does two of the nine things.

**Any key but Escape, and no modifier keys.** Escape cancels the capture. Shift, Ctrl, Alt and Meta pressed alone are refused. A key pressed while a modifier is held binds the key. Keys the menus also use, such as Enter and the arrows, are allowed, as the defaults already use them.

**The Controls page.** Nine more rows do not belong on the settings sheet, so Controls is a page of its own, opened from a button on the settings sheet both at the title and in the pause menu. It lists each action with its key on a ticket and its gamepad button beside it. Pressing the ticket asks for a key, and the next key pressed after that is bound, so the Enter that pressed the ticket is not taken as the answer. A button restores the defaults. Changes apply at once and are saved with the settings.

**The file.** Bindings live in `settings.cfg` under a `keys` section, one physical keycode per action. A value that is missing, not a key, Escape or a modifier falls back to that action's default. If the file then has two actions on one key, every binding returns to its default.

**The gamepad is listed, not remapped.** The checklist asks for keys. The page names each button as the Steam Deck prints it (A, B, X, Y, L1, R1, View, the D-pad), because the Deck is the one pad this project names as a target.

### Colour

**Hue alone never tells the player anything they need.** Each state has words, a shape, a position or a size as well.

The three fixes:

- **Few cards.** At two cards the seat reads "Only 2 cards", and at one "Last card". The red ink stays. A seat with no cards reads as it does today.
- **Hint.** A hinted card gets a pencilled tick above it as well as its gold edge. The tick stays when the card is also selected, armed or under the cursor, and it sits in the strip of the card that the fan leaves showing. It is drawn rough at corruption stage 0 and rougher later, as the owner asks of everything drawn in code.
- **Tutorial refusal under reduced motion.** With the border the slip gets a cross drawn in its corner, two strokes, for the same 0.6 s.

**Fading stays.** A button that cannot be pressed looks the same faded in grayscale as in colour, and pressing it does nothing. An older play is under the newer one as well as dimmer. Neither gets a second mark.

### How a grayscale run is played and judged

`tools/playtest.gd` and `tools/demo_screenshots.gd` will take `--grayscale`, which lays a full-screen grayscale pass over everything they show, and `--reduced-motion`, beside the `--text-size` flag P5.1 adds. Grayscale is a test fixture and not a setting.

The cloud playtest gains a second walk with all three on. It passes on the same terms as the first: no misclick, no hand mismatch, no missing button, no script error. Its frames are then read by the agent for anything a player could not tell apart.

Tests hold what a walk cannot see: each of the three fixes; that a key changed on the Controls page moves the action at the table and in the Campaign tray, opens the reading picker and reaches nothing behind it while it is open (the picker itself answers only to the menu keys), survives a restart, and swaps on a clash; and that every action has a row.

## Alternatives rejected

- **Remapping the gamepad too.** It is the better answer for a player who can only use a pad, and it is left out only because the item asks for keys. See the first consequence.
- **Leaving a clashing action unbound.** The player then has an action with no key and has to notice.
- **Binding by the letter, not the position.** H, S, R and C would move around on a layout that puts those letters elsewhere.
- **A grayscale or high-contrast setting for players.** The item asks that the game be playable without colour, not that it offer a second look. High contrast is a different need, about how visible things are, and is not taken up here.
- **A contrast floor for faded buttons.** W3C's guidance leaves inactive controls out of its contrast requirement ([Understanding Non-text Contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html), read 2026-11-17), and a floor between a button and its faded self would mean redrawing every ticket for a state grayscale does not change.

## Consequences

- **A player who uses only a gamepad cannot change its buttons in v1.** The first release is on itch.io, where Steam Input is not there to do it. Every action is also a button that can be clicked, and the keyboard can be remapped. Pad remapping would take a second section in the file beside `keys` and the same capture. This is the open point most worth the owner's look.
- The Controls page is the first place the game shows its keys.
- Key names come from the engine and the keyboard layout, not from the string table. P5.1's string scan looks for literals, so it never sees them and needs no exception.
- Xbox, PlayStation and Switch pads see the Deck's button names.
- Why a shop button is faded is not always the price: a full Cadre shelf or Campaign tray refuses a purchase too, and the button does not say which. That is the same in colour and is left to the owner's playtest.
- The walk in grayscale is the demo's rounds, the shops and the staged screens, not eight Years. A person playing a whole run in grayscale is not covered by any checklist item; it is left to the owner's playtest, and P5.2's tick will say which of the two was done.
- A new action added later needs a default key, a row on the page and a string, or the page's test fails.
