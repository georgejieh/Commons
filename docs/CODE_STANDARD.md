# Code standard

One page: what every script in Commons is held to. It is Godot's [GDScript style guide](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_styleguide.html) and [best practices](https://docs.godotengine.org/en/4.7/tutorials/best_practices/index.html), plus the project's own rules. [CLAUDE.md](../CLAUDE.md) has the layers and the commands; [ARCHITECTURE.md](ARCHITECTURE.md) has the design.

These are rules, not a description. Code that does not meet one is at fault, whatever its age. The tools hold the first section; a reviewer holds the rest.

## What the tools hold

Do not review for these by eye; make the tool pass.

- `tools/lint.sh` runs `gdformat --check` (tabs, wrapping at 100 columns, blank lines) and `gdlint` with `gdlintrc`: the pattern each kind of identifier must match, the order of a class's parts down to its variables, 400 lines a file, 20 public methods a class, 6 returns and 10 parameters a function, no argument left unused unless its name starts with an underscore, no `else` after `return`.
- `project.godot` turns these engine warnings into errors, so a script that trips one does not load: `untyped_declaration`, `unsafe_property_access`, `unsafe_method_access`, `unsafe_cast`.
- A full `tools/test.sh` compiles every script of the project's own (add-ons and test fixtures apart), and runs the layer check (`core/` names nothing in `game/` or `ui/`) and the UI boundary check (`ui/` names none of the listed classes that change run state).
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
- Pairs and tuples are not passed about as `Array`. Use two typed arrays or a small class.

## Comments

- A `##` doc comment heads every script and every public member: what it is for and what a caller must know, in plain sentences. Each member gets its own; a comment above a group documents only the first.
- A comment says why the code is so, for a reader a year from now. It cites the ADR that decided it. It does not cite a checklist item or a playtest, narrate a change ("now", "no longer", "as before"), restate the line under it, or run longer than its reason.
- An accessor that exists so a test can see a state says "for tests" and is named for what the player would see.

## Rules of the house

- **Layers.** `ui` → `game` → `core`. `core/` is pure logic and runs headless. Presentation never changes game state: it sends a command to the controller and renders the events that come back. What the UI reads from a run is a copy or a read-only view.
- **Data.** Every tunable number lives in a Resource in `data/`, with a doc comment that says what it does and its unit. A structural constant is a named constant, declared once and referenced. A data file is preloaded under one name in one place: every pool in `RunPools`, the numbers a run plays by in `RunDefaults`, and a definition is found by its id through `RunDefinitions`.
- **Settings.** A setting's key is a constant on the class that owns the setting, never a literal at the reader. A node connects to `Settings.changed` in `_ready`. Code that may run with no autoloads reads a setting through `SettingsStore.value_or`.
- **Content.** A definition is data; its behaviour is a small effect script registered by id. An effect names its parameters as string constants and lists the ones it requires. A hook takes one typed context.
- **Refusals and errors.** A command that is refused returns a reason from an enum and changes nothing. A run command is accepted in one set of phases and recorded only when it is accepted. A function that writes a file returns its `Error`, the failure is logged once through the game log, and no caller reports a success it did not get. `assert` is for what a caller has already checked: it does not run in a release build, so it never does the checking or the work.
- **Randomness.** Every draw takes a seeded stream as an argument. A side draw uses a stream derived from the run seed and a key, so it moves no other draw. No global random functions and no array shuffle in `core/`.
- **Saved data.** What is saved has `to_dict`, a static `from_dict` and a static `is_valid`, its own or its owner's. A change to the shape of what is saved raises the schema version and adds a migration; a change to content is met by the content stamp ([ADR 0033](adr/0033-saves-across-content-changes.md)). Every file the game saves is written whole to a temporary name and renamed into place, and a file from a newer version of the game is moved aside, never written over ([ADR 0037](adr/0037-stability.md)).
- **Text.** Every string the player reads is a row in `data/strings/strings.csv`, read by key: `tr(key)` on an instance, `TranslationServer.translate(key)` in static code. Licence texts and generated names are the exceptions.
- **Screens.** Built in code. A top-level screen opens through `open(app)`; a piece of one is wired through `setup(...)`. Every font size goes through `TextSize`; art that holds a letter keeps its size. Colours come from the shared kit, not from a constant in each file. A control that fills its parent and is built in code takes `set_anchors_and_offsets_preset`, since anchors alone leave it at no size. A decorative node ignores the mouse. Anything drawn in code is aged through the grime helpers with a fixed-seed generator: nothing is drawn clean.
- **Motion.** A tween is made on the node it moves, and the one before it on the same property is ended first. Reduced motion is read one way, through `UiMotion`.
- **Tools and tests.** A tool the engine runs with `--script` extends `SceneTree`, reads its options through `ToolOptions`, writes its reports and pictures through `ToolFiles`, and exits 0, 1 on a fault and 2 on bad options. A relative path it is given is under the project. A walk reaches a private member of the game only through the walk base, which fails the walk when the member is gone; it prints `MISS` for a failed step, `MISCLICK` for a click that did nothing and `FRAME` for a picture. The Python tools pass `ruff` (PEP 8 at 100 columns, with type hints). A tool or a test never reaches the player's saves or settings: its default save paths are under `user://tools/` ([ARCHITECTURE.md](ARCHITECTURE.md), "The player's files and the sandbox"). A test can fail and names what it proves; a test of the game proves something the player would meet. Give every Godot run a time limit and an output cap.

## Speed and memory

- Measure first. `tools/perf_limits.gd` holds the budgets, `tools/perf_budget.gd` measures against them and [perf.md](perf.md) keeps the results; a change is a gain only when a row moves.
- The paths that run many times a decision are the classifier, the move generator, the hand decomposer and the bots' rollouts. There, a hand is a 15-slot `PackedByteArray` of rank counts, nothing is allocated that can be kept, and nothing is built that is not read.
- Nothing is rebuilt every frame that changes only on an event. A list searched by id more than once is a dictionary built once.
- Do not make a path that runs once a round harder to read to make it faster.

## Engine API

Godot 4.7.2. GDScript has no warning for calling a method the class reference marks deprecated, so that is found by reading: check the class reference page before using a method new to the project, and the "Upgrading" pages when the engine version moves. Since 4.4 the `FileAccess.store_*` methods return a `bool`; check it.
