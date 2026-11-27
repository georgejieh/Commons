# ADR 0024: Endings and epilogues (P4.13)

- Status: Accepted, 2026-11-15, by the agent under the design authority ADR 0021 records. The owner judges by playtest.
- Scope: which ending a finished run gets, the collective variant, what a run that dies shows, the epilogue line each surviving villager gets, and the text.

## Why this needs a decision

The Plan gives the grid of six endings and says a "mostly collective" run earns a rare variant of The Secret Contract. It does not say what counts as high, what breaks a tie, what "mostly collective" measures, what a dead run shows, or how a villager's memory becomes a line.

## The rule

An ending is for a run that survives its last Year. It is chosen from three facts, by a pure function in `core/`:

1. **Class.** Landlord if the player was the landlord in at least half of the rounds played in the final Year, peasant otherwise. The landlord seat itself cannot be read at the end, because it is cleared when each Quota ends, and one last round should not decide a class. Two counters in `RunState`, reset at each Year's start, keep the rounds played and the rounds the player was landlord, so the run save moves up a schema.
2. **The meter in its high band.** A meter is high at or above its `high` threshold (75 today). If both are high, the larger value decides, and Denunciation decides a tie.
3. **Resentment**, for the variant only.

| Ending | ID | Class | Meters |
| --- | --- | --- | --- |
| The Secret Contract | `secret_contract` | Peasant | Neither high |
| The Commons | `the_commons` | Peasant | Neither high, and the collective condition |
| Lean Years | `lean_years` | Peasant | Famine high |
| Labeled | `labeled` | Peasant | Denunciation high |
| The Benevolent Landlord | `benevolent_landlord` | Landlord | Neither high |
| Full Granary, Empty Village | `full_granary` | Landlord | Famine high |
| Struggled | `struggled` | Landlord | Denunciation high |

**The collective condition.** The Commons replaces The Secret Contract when the run also ends with Resentment at or below `collective_resentment` (data, 10 to start) and with both meters below their `mid` threshold. Nothing in the game lowers Resentment today. Black-market purchases, private Cadres held, stamped cards scored, grabbing a held landlord seat, overfulfilling a Quota and a few Campaigns and Cadres raise it. A low final Resentment is therefore the game's own measure of a run played through the collective and without standing out. Ten is two black-market purchases and nothing else. It is a starting value for P4.16.

**A run that dies** gets no ending. It shows a short record of the death, by meter: `death_famine` or `death_denunciation`. The meter is read from the saved meters, Denunciation first if both are at their death threshold, as the loop already rules. No epilogue follows.

## Epilogues

Every family in the roster that is not dead is named in exactly one line. Families that would get the same line share it, their surnames joined in roster order ("Sun, Gao and Ma signed last."), and the lines run in the roster order of each one's first family. A village of fourteen then reads as a short record, not the same sentence four times.

- A family in reeducation, or deposed, gets the line for that state.
- Every other family gets a line chosen by the ending and by its **disposition**, read from the family's memory of the player (`VillageMemory`, with `MemoryParams`), which carries over from earlier runs at a reduced weight:
  - **warm**: its weighted grudge is below zero (feeding outweighs harm, by the memory weights);
  - **bitter**: its `pull` is at or above `bitter_pull` (data, 0.5 to start);
  - **wary**: everything else, including a family with no history.
- Lean Years and Full Granary, Empty Village add one line naming the dead families, if there are any.

Lines are templates with `{name}` (one surname, or several joined with commas and "and") and `{surname}` (the player's). Every line reads the same for one family or several, so none uses "was" or "has" of the families. They never assume a fact the game cannot guarantee.

## Text

Voice: a plain record in the past tense. Names and facts carry it. No moral. Each ending states its cost as a fact and stops. Chinese characters appear only as decoration: Struggled's title card reads 斗地主.

### Endings

**The Secret Contract.** That winter the households met after dark and divided the brigade's land between them. They marked the paper with thumbprints and seals. The next harvest was the largest the village had brought in, and the report to the commune did not say why. The paper also said who would raise the leaders' children if the leaders were taken away.

**The Commons.** Nobody divided the land. The households farmed it together for eight years, split what there was, and wrote down true figures. Some years that was enough. The {surname} family ended the eighth year owning what it had owned in the first.

**Lean Years.** The {surname} family gave to the Commons every year and took what was handed back. In the eighth winter the granary was swept to the boards before the solstice. The brigade cut the ration twice more before spring.

**Labeled.** In the eighth year the {surname} name went up on the wall outside the brigade office. The family kept its house and its place in the fields. The label went into the household register, under every name in the family.

**The Benevolent Landlord.** By the eighth year the {surname} family held the land and the village ate. Rent came due after harvest and was paid in grain. People took off their caps at the gate. They called the {surname} family landlord, which was what they had called the last family to hold the land.

**Full Granary, Empty Village.** The {surname} storehouse was full in the eighth winter. It had two locks and a man paid to sleep against the door. Nothing left it before spring.

**Struggled.** In the eighth year the village came to the {surname} gate together. They carried the ledgers out and read from them in the square. Every household still in the village was called on to speak. The land was divided again by autumn, and the {surname} family was given the share furthest from the well.

### Deaths

**Famine.** The village ran out of grain in Year {year}. The {surname} household was not on the next roll.

**Denunciation.** The work team came for the {surname} family in Year {year}. By spring the house had been given to another household.

### Epilogue lines

| Ending | Warm | Wary | Bitter |
| --- | --- | --- | --- |
| The Secret Contract | {name} signed below you. | {name} signed last. | {name} did not sign, and did not report it. |
| The Commons | {name} kept the granary key in the eighth year. | {name} checked the scales every autumn and found them true. | {name} took a full share every year and ate apart. |
| Lean Years | {name} shared a pot with your household through the winter. | {name} answered at roll call and went home. | {name} said the {surname} family had always given away what was not theirs to give. |
| Labeled | {name} still left the gate between your yards unlatched. | {name} crossed to the other side of the lane. | {name} told the work team what they had seen. |
| The Benevolent Landlord | {name} farmed your best field at the old rent. | {name} paid the rent in full every autumn. | {name} paid on time and never came past the gate. |
| Full Granary, Empty Village | {name} worked in your storehouse. | {name} came to the gate once and left by the back. | {name} stopped coming to the gate. |
| Struggled | {name}, asked to speak, said the weather had been bad. | {name} spoke for as long as the others had. | {name} spoke first, and had brought notes. |

- In reeducation: {name} had been sent away to study.
- Deposed: {name} had been put out of the seat and worked a plot like anyone.
- The dead, on Lean Years and Full Granary: Not at roll call: {names}.

### The historical note

The Secret Contract and The Commons end with one small line under the epilogues:

> In the winter of 1978, the heads of eighteen households in Xiaogang, a village in Fengyang County, Anhui, secretly agreed to farm their production team's land by household. In 1982 the central government endorsed the practice, and it spread across the country.

This is the game's one historical anchor. Two details in The Secret Contract's text come from the published text of that agreement: it was marked with fingerprints and seals, and it pledged that if the team's leaders were jailed or executed, the other members would raise their children to eighteen. Whether the sheet on display in the museum is the original has been disputed, so the note describes the agreement and not the artifact.

## Consequences

- `EndingParams` (data) holds `collective_resentment` and `bitter_pull`. The band thresholds stay in `MeterBands`.
- The ending and its epilogue lines are worked out from the final `RunState` alone (with the two class counters), so the ending screen can be rebuilt from a save, and P4.14 can store the ending's ID in the profile.
- The ending screen shows the ending's title and text, the two meters, the epilogue lines one after another, and the way back to the title. The six endings and The Commons need art (P3C pipeline); until then each shows its title set in type on aged paper.
- Tests reach all six endings, the variant and both deaths, and check every surviving villager gets exactly one line.
- Music and the profile's record of endings belong to P3C.9 and P4.14.
