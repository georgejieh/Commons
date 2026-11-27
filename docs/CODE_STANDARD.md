# Code standard

One page: what every script in Commons is held to. It is Godot's [GDScript style guide](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_styleguide.html) and [best practices](https://docs.godotengine.org/en/4.7/tutorials/best_practices/index.html), plus the project's own rules. [CLAUDE.md](../CLAUDE.md) has the layers and the commands; [ARCHITECTURE.md](ARCHITECTURE.md) has the design.

These are rules, not a description. Code that does not meet one is at fault, whatever its age. The tools hold the first section; a reviewer holds the rest.

## What the tools hold

Do not review for these by eye; make the tool pass.

- `tools/lint.sh` runs `gdformat --check` (tabs, wrapping at 100 columns, blank lines) and `gdlint` with `gdlintrc`: the pattern each kind of identifier must match, the order of a class's parts down to its variables, 400 lines a file, 20 public methods a class, 6 returns and 10 parameters a function, no argument left unused unless its name starts with an underscore, no `else` after `return`.
- `project.godot` turns these engine warnings into errors, so a script that trips one does not load. Typing: `untyped_declaration`, `unsafe_property_access`, `unsafe_method_access`, `unsafe_cast`. Code that goes nowhere: `unused_variable`, `unused_local_constant`, `unused_private_class_variable`, `unused_parameter`, `unused_signal`, `unreachable_code`, `unreachable_pattern`, `standalone_expression`, `standalone_ternary`, `redundant_await`, `assert_always_true`, `assert_always_false`. Code that misleads: `shadowed_variable`, `shadowed_variable_base_class`, `shadowed_global_identifier`, `integer_division`, `narrowing_conversion`, `incompatible_ternary`, `static_called_on_instance`, `unassigned_variable`, `int_as_enum_without_cast`, `int_as_enum_without_match`, `enum_variable_without_default`, `confusable_local_declaration`, `confusable_local_usage`, `confusable_capture_reassignment`. Tests and tools are held to the same; only `addons/` is spared, by the engine's default directory rule. `tests/unit/test_project_scripts.gd` holds the list. A name that shadows a member or a built-in is renamed for what it holds.
- `@warning_ignore` is for code that is right where the engine cannot know it, with a comment on the line above that says why. A division meant to drop its remainder carries `@warning_ignore("integer_division")` alone.
- A full `tools/test.sh` compiles every script of the project's own (add-ons and test fixtures apart), and runs the layer check (`core/` names nothing in `game/` or `ui/`) and the UI boundary check (`ui/` names none of the listed classes that change run state).
- `tests/unit/test_test_scan.gd` fails a test or a tool that reaches a private member by its name in a string, a test that touches another object's private member, and a test that waits a fixed time. The two exceptions are marked on the line above: `# Stepped:` where a test calls `_process` or `_physics_process` to step time by hand, `# Timed:` where the time is what the test is about.
- The linter does not compile. Run a new script, or its test, before committing it.

The tools do not see what a name means, whether a comment is true, how long a function is, the order of functions, or whether code is reached. Those are below.

## Names and shape

- Files `snake_case.gd`, one class a file, `class_name` in `PascalCase`. Functions and variables `snake_case`, private ones with a leading underscore. Constants `CONSTANT_CASE`, but a constant that holds a loaded class is `PascalCase`. Enums `PascalCase` and singular, members `CONSTANT_CASE`.
- A function is named for what it does (`deal`, `apply`), an accessor for what it returns (`path()`, `notice()`), a question as one (`is_open`, `has_card`, `shows_notice`). Signals are in the past tense (`changed`, `opened`, `dismissed`).
- Order in a script, as the style guide has it: `@tool` and other script annotations, `class_name`, `extends`, the `##` doc comment, signals, enums, constants, static variables, exported variables, other variables, `@onready` variables, `_static_init` and the static functions, the engine's virtual functions (`_init`, `_enter_tree`, `_ready`, then the rest), overridden functions of the project's own, the remaining functions, inner classes. Public comes before private.
- A file stays under about 400 lines and a function under about 50. One that must be longer says why in one line at its top, and the reason has to be true of the whole file, not of the part that was there first.
- A helper with no state is `class_name X extends RefCounted` with static functions. A data class is `RefCounted`; it is a `Resource` when it is edited or saved as one; a `Node` only when it needs the tree. Autoloads are few: one is for state or a service the whole game needs for as long as it runs.
- No abstraction until a second concrete use exists: no class, parameter object, base class or callback with one user, no parameter every caller passes the same value for, no wrapper that only forwards. When an approach is replaced, the old path goes in the same change, with its strings, data fields, tests and document lines.

## Types

- Every variable, parameter, return value and loop variable is typed. `:=` only where the type is plain on the same line.
- Arrays and dictionaries carry their element types (`Array[int]`, `Dictionary[String, int]`) unless they hold parsed JSON. The compiler checks indexing, assignment by index and loops against them, but not what `append` and the other methods are given (the engine refuses a wrong value only when the line runs), and a nested element type cannot be written. Fill a typed array from an untyped one with `assign`.
- A closed set is an enum, not bare numbers. A member whose number is saved keeps that number.
- An `as` cast to an object type gives null on a mismatch, without an error. Check with `is` first, or check the result.
- A record passed between functions is a small class, not a `Dictionary` or an `Array` read by index.

## Comments

- A `##` doc comment heads every script and every public member: what it is for and what a caller must know, in plain sentences. Each member gets its own; a comment above a group documents only the first.
- A comment says why the code is so, for a reader a year from now. It cites the ADR that decided it. It does not cite a checklist item or a playtest, narrate a change ("now", "no longer", "as before"), restate the line under it, or run longer than its reason.
- An accessor that exists so a test can see a state says "for tests" and is named for what the player would see.

## Rules of the house

- **Layers.** `ui` → `game` → `core`. `core/` is pure logic and runs headless. Presentation never changes game state: it sends a command to the controller and renders the events that come back. What the UI reads from a run is a copy or a read-only view.
- **Data.** Every tunable number lives in a Resource in `data/`, with a doc comment that says what it does and its unit. A structural constant is a named constant, declared once and referenced. A data file is preloaded under one name in one place: every pool in `RunPools`, the numbers a run plays by in `RunDefaults`, and a definition is found by its id through `RunDefinitions`. A data Resource may name a core enum to type a field, and nothing else of `core/`.
- **Names that cross files.** A name more than one file writes is a constant on the class that owns it: a bus on `AudioMixer`, an input action on `KeyBindings`, a setting's key on the class that owns the setting. A literal at a reader is a fault, and where the linter cannot see it a test scans for it. A constant only a test reads lives in the test.
- **Settings.** A node connects to `Settings.changed` in `_ready`. Code that may run with no autoloads reads a setting through `SettingsStore.value_or`.
- **Content.** A definition is data; its behaviour is a small effect script registered by id. An effect names its parameters as string constants and lists the ones it requires. A hook takes one typed context. A registry is a table from id to script, not a chain of `match` blocks. An effect reads a number given in hundredths through `ModifierEffect.fraction`, and guards no seat of its own: which seats a Cadre reaches is `SeatScope`'s alone.
- **Rule facts.** What the rules define is declared once and referenced: the widths of a single, a pair, a trio and the smallest bomb, `is_bomb` and `effective_rank` on `Pattern`; the seats (`PLAYER`, `RIGHT`, `LEFT`, the teammate) on `Seats`; a card's name in `CardName`; a hand type's string key from `ReadingText.type_key`. Another class's constant costs the same as a local one, so speed is no reason to redeclare it.
- **Refusals and errors.** A command that is refused returns a reason from an enum and changes nothing. A run command is accepted in one set of phases and recorded only when it is accepted. A function that writes a file returns its `Error`, the failure is logged once through the game log, and no caller reports a success it did not get. `assert` is for what a caller has already checked: it does not run in a release build, so it never does the checking or the work.
- **Randomness.** Every draw takes a seeded stream as an argument. A side draw uses a stream derived from the run seed and a key, so it moves no other draw. No global random functions and no array shuffle in `core/`.
- **Saved data.** What is saved has `to_dict`, a static `from_dict` and a static `is_valid`, its own or its owner's. A change to the shape of what is saved raises the schema version and adds a migration; a change to content is met by the content stamp ([ADR 0033](adr/0033-saves-across-content-changes.md)). Every file the game saves is written whole to a temporary name and renamed into place, and a file from a newer version of the game is moved aside, never written over ([ADR 0037](adr/0037-stability.md)).
- **Text.** Every string the player reads is a row in `data/strings/strings.csv`, read by key: `tr(key)` on an instance, `TranslationServer.translate(key)` in static code. Licence texts and generated names are the exceptions.
- **Screens.** Built in code. A top-level screen opens through `open(app)`; a piece of one is wired through `setup(...)`. Every font size goes through `TextSize`; art that holds a letter keeps its size. A colour two files use is an ink with one value in the style data, read as `ScreenKit.<NAME>`; a colour one drawing uses stays with that drawing. Draw order is set only with `ScreenKit.LAYER_*`. A page that has a Back button goes back on Cancel through `ScreenKit.take_cancel`. A shop's pieces are stalls set up from one `StallContext`. A control that fills its parent and is built in code takes `set_anchors_and_offsets_preset`: `set_anchors_preset` alone moves the anchors and keeps the rect the control had, which for a new control is no size. A decorative node ignores the mouse. Anything drawn in code is aged through the grime helpers with a fixed-seed generator: nothing is drawn clean.
- **Motion.** A tween is made on the node it moves, held in a field, and the one before it on the same property is ended first with `UiMotion.end`. Reduced motion is read one way, through `UiMotion.reduced()`, and the motion presets through `UiMotion.PRESETS`.
- **Tools and tests.** A tool the engine runs with `--script` extends `SceneTree`, reads its options through `ToolOptions`, writes its reports and pictures through `ToolFiles`, and exits 0, 1 on a fault and 2 on bad options. A relative path it is given is under the project. A walk reaches a private member of the game only through the walk base, which fails the walk when the member is gone; it prints `MISS` for a failed step, `MISCLICK` for a click that did nothing and `FRAME` for a picture. The Python tools pass `ruff` (PEP 8 at 100 columns, with type hints). A tool or a test never reaches the player's saves or settings: its default save paths are under `user://tools/` ([ARCHITECTURE.md](ARCHITECTURE.md), "The player's files and the sandbox"). A test can fail and names what it proves; a test of the game proves something the player would meet. Give every Godot run a time limit and an output cap.

## Tests

- A test puts the game in a state the way the game gets there: by commands; by the public fields of the state; by a public constructor given data the test builds; or by a seam the class documents as for tests and tools, which the UI boundary check forbids in `ui/`. Never by a private member. A state none of these reach is not tested by forcing it: the test goes, with its reason in the commit.
- A view is staged through its own public methods, and read through the parts it shows: a screen's pieces that a test reads are typed public variables, each with its doc line.
- A suite writes only under `TestFolder.of(suite)` and makes the app through `AppKit`. Input goes through `TestInput`, so it reaches a screen as the player's does, not through a control's handler.
- A wait names what it waits for and fails saying what never came (`TestWait.until`, `TestWait.still`, the `play_to` loops in `ControllerScript` and `RunScript`). None ends quietly, and none waits a fixed time unless the time is the subject.
- A layout check takes its sizes, its slack and its clip assertion from `ClipCheck`. A fixture that stages a worst case stages one that can happen, and says in its doc line what it holds.
- A helper two suites need lives in `tests/support/`, once.

## Speed and memory

- Measure first. `tools/perf_limits.gd` holds the budgets, `tools/perf_budget.gd` measures against them and [perf.md](perf.md) keeps the results; a change is a gain only when a row moves.
- The paths that run many times a decision are the classifier, the move generator, the hand decomposer and the bots' rollouts. There, a hand is a 15-slot `PackedByteArray` of rank counts, nothing is allocated that can be kept, and nothing is built that is not read.
- Nothing is rebuilt every frame that changes only on an event. A list searched by id more than once is a dictionary built once.
- Do not make a path that runs once a round harder to read to make it faster.
- A change to the rules, the scorer or the bots that is meant to change nothing is proved by seeded tournament logs that are the same byte for byte and golden tests that pass untouched.

## Engine API

Godot 4.7.2. GDScript has no warning for calling a method the class reference marks deprecated, so that is found by reading: check the class reference page before using a method new to the project, and the "Upgrading" pages when the engine version moves. Since 4.4 the `FileAccess.store_*` methods return a `bool`; check it.
