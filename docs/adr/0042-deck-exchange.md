# ADR 0042: Deck exchange

- Status: Accepted, 2026-11-25. The owner's direction from their playtest of 2026-11-24; the design is the lead's, the data model the owner's, the names and details below the agent's.
- Scope: buying a card for the communal deck at the state store, the card it replaces, how the run holds the deck, how every seat counts cards against it, and the save.

## Why this needs a decision

The owner, after playing: "there needs to be a shop mechanic that is similar to private plots and private plot envelopes, but instead of it going to private plots it goes into communal deck and you need to also remove an equal amount of cards you put into the communal deck from the communal deck". Earlier the same day: "effects that directly modify cards in the deck stays persistent in the deck until end of run". The Plan already names public deck edits ("add, remove or alter ranks in the shared deck; everyone's odds change"); they were never built.

Before this, a deck card's rank and suit followed from its slot ID by arithmetic (`id / 4`, `id % 4`) wherever a card was made, and every bot counted unseen cards against a constant four of each rank and one of each joker. Neither survives a deck whose make-up changes.

On the model the owner asked: "cant the deck be stored in a hash map and for bots to count cards, every time the communal deck is updated, a snap shot of the hash map is given to the bots so they know what is in the deck for them to do the card counting?"

## Options

1. **A list of edits applied over the plain deck wherever a card is made.** Rejected: every place that makes a card would need the list, and the arithmetic would stay in each.
2. **The deck as one keyed structure, slot to card, and a count of it handed to every seat when a round is dealt.** Chosen; it is the owner's.

## Decision

**The deck.** `Deck` (`core/model/deck.gd`) is the 54 slots, each to the rank and suit of the card in it. A new `Deck` is the plain deck, and its constructor is the only place a slot's card follows from its ID. The run holds one, `RunState.deck`, and everything that turns a slot into a card reads it: the deal (`Deck.cards()`), Unplanned Economy's gathered deal (`DeckOrder.deal`), the arrival's authored deals, the desks, the deck sheet (`RunController.deck_cards()`), and the table's views of a card it knows only by ID, the kitty among them (`RunController.deck_card()`). `CardInstance.from_deck_id` and the static `Deck.rank_of` and `Deck.suit_of` are gone. Marks stay in `CardMarks` by slot ID. Slot IDs stay 0 to 53 and plot IDs 1000 and up, so an ID still names one card for the run (ADR 0014, ADR 0038).

**In memory and in the save.** In memory the deck holds all 54 slots, so a lookup is an index. The save holds only the slots whose card is not the plain deck's, each to its rank and suit: a deck nobody changed saves as nothing, a save before this one migrates by adding nothing, and the saved field reads as the run's exchanges, which is what the deck sheet shows. The jokers' slots are never saved, since no exchange touches them.

**The count every seat is given.** The dealer counts the cards it deals, rank by rank, once, into `DealResult.deck_counts`. `RoundState` hands that count to every `SeatView` as `deck_counts`, and `UnseenCards` counts unseen cards as it less the seat's own hand and every card played. It replaces `UnseenCards.PER_RANK` and `PER_JOKER`. A bot never reads the run's deck, so it knows the deck the table was dealt and nothing the run changes after. The Expert's sampled worlds, its rollouts (`Rollout`, which is handed the searching seat's count), Hard's controls and threat reading, and the hint all count from it. A view made by hand from a stacked test deal is given the plain deck's count.

**A plot swap.** The card a swap sets aside is out of the round (ADR 0038). Only the player knows which card that was and which plot card came in, so only the player's count changes: `RoundState.exchange` takes the set-aside cards off the seat's own count and adds the cards brought in, and every other seat keeps the dealt count. The rule is one for every seat: a seat counts unseen cards against what it knows the round holds. A villager counts the set-aside card as unseen and cannot know of the plot card; when the player plays a rank past what the villager counted, its unseen count of that rank stays at none, as it did for a fifth copy from the plot before.

**Marks made during a round.** A Campaign that marks a card in hand changes its marks, not its rank, so no count changes; `CardMarks` saves the mark by slot, and the next deal builds the slot's card from the deck and puts the mark back on it, whoever is dealt it.

**Limits, in data.** `RunParams.deck_rank_most` (8 in `data/run/default_run.tres`) is the most cards of one rank the deck may hold. A rank at it is not offered, and a card of it is refused. With the private plot's most (its capacity and every upgrade, 6), a hand holds at most 14 of one rank, which `CountKey` (four bits a rank, 15 at most) holds; `tests/integration/test_deck_exchange.gd` fails if a change to either breaks that. `HandDecomposer` gives its wild-card budget five bits, since two wild ranks at eight copies can put sixteen wild cards in one hand. No joker is offered, and no joker may leave, so the Rocket stays possible and the deck never holds a third joker. A rank may be emptied: with no 3s no Straight can start at 3, every seat counts none unseen, and Mass Line never makes a rank wild that the deck holds no card of (`RunWild.add`).

**What five to eight copies may form.** Exactly what a fifth copy from the plot already formed (ADR 0029): without Industrialization four of a rank are a Bomb, and five to eight of it are no single play, so eight are two Bombs of four; with it, all of them are one Bomb, and a larger one beats a smaller. `tests/unit/test_many_copies.gd` holds this for the classifier, the move generator and the hand decomposer.

**The stall.** The state store has a stall of cards for the deck, the counterpart of the black market's plot stall (`DeckStall`, beside `PlotStall`; both offer through `CardOffers` from a `CardStallParams` each, `data/run/deck_stall.tres` and `data/run/plot_stall.tres`). It offers 2 cards a visit, each of any rank from 3 to 2 the deck has room for and any suit, drawn on a stream of its own seeded from the run and the visit (`deck_stall:<visit>`), as the desk's offer is, so no other draw moves and a replay draws them again. One offer in four (25 percent) carries an enhancement, drawn evenly from the four; none carries the player's stamp. A card's price is by its rank, as a plot card's is, plus 2 coupons for an enhancement, under any raise the books made: 2 for a 3 to a 9, 3 for a 10 to a Queen, 4 for a King or an Ace, 5 for a 2. The arrival has no stall. A purchase is the shop command `deck_card` with the offer's slot and the deck slot it takes out, through `RunLoop.player_deck_card`; it is in the command record, so a save replays it. Refusals: closed, no such offer, sold, the rank at its most, too poor, no such deck card, and a joker.

**The envelope.** The state store sells a third envelope, the Requisition (`data/modifiers/envelopes/deck_envelope.tres`), which opens to 3 cards for the deck (`EnvelopeDef.Content.DECK_CARD`, weight 3, and `MARKED_DECK_CARD`, weight 1, carrying an enhancement drawn evenly), drawn from the 52 non-joker cards of the ranks the deck has room for, for 4 coupons. Keeping one is the envelope pick with the deck slot it takes out (`envelope_pick` with `out`); a pick of a deck card without one is refused and the envelope stays open, so backing out of the choice puts the player back at the envelope and never loses the purchase or leaves the deck at 53 or 55.

**Saves.** The run save's schema goes from 18 to 19: `migrate_from_18` gives an older checkpoint the empty deck, the plain one. The new stall's and envelope's numbers and both counters' envelopes join ADR 0033's content stamp, so a save from before this build resumes at its checkpoint.

## Consequences

- A villager dealt an incoming card plays it like any other; an enhancement on it scores for whoever scores it (ADR 0041).
- Every shop visit's envelope offer is drawn among three kinds at the state store, not two, so the balance harness's runs change from the first visit.
- Tests and tools that make a plain card write `Deck.new().card(slot)`.
