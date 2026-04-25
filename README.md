# libvaxis-tetris

Terminal Tetris written in Zig using [libvaxis](https://github.com/rockorager/libvaxis).

## Requirements

- Zig `0.16.0`
- A real TTY-compatible terminal (for libvaxis `/dev/tty` access)

## Build

```bash
zig build
```

## Run

```bash
zig build run
```

## Run tests

```bash
zig build test
zig test src/game/rules_test.zig
```

## Controls

- `Enter` / `Space` (start screen): start game
- `←` / `→`: move piece
- `↓`: soft drop
- `↑` or `x`: rotate clockwise
- `Space` (in game): hard drop
- `c`: hold piece
- `p`: pause / resume
- `r` (game over): restart
- `q` or `Ctrl+C`: quit

## Current features

- 10x20 board
- Tetromino spawn, movement, rotation, collision
- Line clearing + score + level tracking
- Gravity tick loop with level-based speed curve
- One-tick lock delay
- Hard drop with bonus scoring
- Hold piece (single hold per drop)
- Ghost piece rendering
- Next piece preview
- Colored terminal rendering using `vxfw.RichText`

## Known limitations

- No wall-kick system yet (basic rotation only)
- No bag randomizer yet (currently deterministic sequence)
- Manual interactive testing requires a real terminal/TTY; headless environments may fail with `NoDevice` when opening `/dev/tty`
