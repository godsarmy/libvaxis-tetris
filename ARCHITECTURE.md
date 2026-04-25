# ARCHITECTURE

## Overview

`libvaxis-tetris` is a terminal Tetris game in Zig, built with `libvaxis` (`vxfw`).

The codebase is intentionally split into:

- **Pure gameplay logic** (`src/game/*`) for deterministic behavior and testability.
- **Runtime/app orchestration** (`src/app.zig`) for input, timers, and state transitions.
- **Rendering** (`src/ui.zig`) for terminal output/styling.

This separation keeps game rules testable without terminal I/O and keeps UI concerns out of the rules engine.

---

## Module map

- `src/main.zig`
  - Thin process entrypoint.
  - Delegates to `app.run(init)`.

- `src/app.zig`
  - Owns the runtime `Model` and app-level mode state:
    - `start_screen`, `playing`, `paused`, `game_over`
  - Handles key input mapping, tick scheduling, gravity/lock timing, focus, redraw.
  - Calls pure rules from `src/game/rules.zig`.
  - Calls UI renderer in `src/ui.zig`.

- `src/ui.zig`
  - Converts app/game state into `vaxis.Segment` rich text.
  - Renders board, active piece, ghost piece, side panel, overlays.
  - Contains visual style/color choices.

- `src/game/types.zig`
  - Domain types/constants (board size, pieces, rotation, position, cell).

- `src/game/state.zig`
  - Mutable game state model (`GameState`) and initialization.

- `src/game/rules.zig`
  - Deterministic gameplay operations:
    - spawn/move/rotate/collide/lock/clear/score/hard drop/hold.
  - No terminal rendering or event-loop dependencies.

- `src/game/rules_test.zig`
  - Unit tests for pure gameplay behavior.

---

## Runtime flow

1. `main` calls `app.run(init)`.
2. `vxfw.App` dispatches events to app `Model` handlers.
3. A short poll tick runs regularly.
4. App logic gates real gameplay updates with deadlines:
   - **gravity deadline** (piece falls)
   - **lock deadline** (grounded piece lock delay)
5. On state changes, app requests redraw.
6. Draw function asks `ui.renderText(...)` for rich-text segments and renders via `vxfw.RichText`.

---

## Timing model

The runtime uses two layers:

- **Frequent poll tick** (small interval): keeps timing responsive and stable.
- **Game deadlines** (absolute timestamps): determine when gravity and locking actually occur.

Why this design:

- Avoids gameplay speed depending on queue jitter.
- Prevents burst behavior after restart/pause/resume.
- Keeps lock delay behavior predictable.

---

## State ownership

- `GameState` owns board/piece/score/level/hold flags.
- `Model` owns app mode and timing deadlines.
- UI is derived from state and should not mutate gameplay state.

---

## Input and transitions (high level)

- Start screen: `Enter`/`Space` -> `playing`
- Playing:
  - move/rotate/drop/hold
  - `p` -> `paused`
  - game-over condition -> `game_over`
- Paused: `p` -> `playing`
- Game over: `r` -> restart/new game
- `q` or `Ctrl+C` -> quit

---

## Testing strategy

- Primary correctness checks are in `src/game/rules_test.zig`.
- Runtime/UI correctness is validated by build + manual play.

Recommended local checks:

- `zig fmt build.zig src/*.zig src/game/*.zig`
- `zig build`
- `zig build test`
- `zig test src/game/rules_test.zig`
