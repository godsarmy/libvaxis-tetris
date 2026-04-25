# AGENTS.md

Guidance for coding agents working in this repository.

## Project context

- Language: Zig `0.16.0`
- UI library: [`libvaxis`](https://github.com/rockorager/libvaxis)
- App type: terminal Tetris

## Repository layout

- `src/main.zig` — thin entrypoint
- `src/app.zig` — runtime loop, input handling, state transitions, timing
- `src/ui.zig` — rendering helpers and rich text segments
- `src/game/types.zig` — core game types
- `src/game/state.zig` — mutable game state model
- `src/game/rules.zig` — pure game rules
- `src/game/rules_test.zig` — rules tests

## Local commands

- Format: `zig fmt build.zig src/*.zig src/game/*.zig`
- Build: `zig build`
- Full tests: `zig build test`
- Rules tests only: `zig test src/game/rules_test.zig`
- Run app: `zig build run`

## Development rules

1. Keep gameplay logic in `src/game/rules.zig` pure and deterministic.
2. Prefer UI/runtime changes in `src/app.zig` and `src/ui.zig`.
3. Add or update tests when changing game rules.
4. Run format + build + tests before finishing changes.
5. Avoid introducing unnecessary dependencies.

## Notes about runtime behavior

- The app uses a short poll tick plus explicit gravity/lock deadlines.
- Focus and redraw handling are required for key events and visible updates.
- In headless environments, `zig build run` may fail due to `/dev/tty` (`NoDevice`).
