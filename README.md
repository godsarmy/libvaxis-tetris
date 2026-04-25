# libvaxis-tetris

Terminal Tetris written in Zig using [libvaxis](https://github.com/rockorager/libvaxis).

See also:

- [ARCHITECTURE.md](./ARCHITECTURE.md) for module/runtime design
- [AGENTS.md](./AGENTS.md) for contributor/agent workflow notes

## Requirements

- Zig `0.16.0`
- A real TTY-compatible terminal (for libvaxis `/dev/tty` access)
- Verify AI agent capacity to write Zig code with libvaxis.

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
```

## Format

```bash
zig fmt build.zig src/*.zig src/game/*.zig
```

## Controls

- `Enter` / `Space` (start screen): start game
- `←` / `→`: move piece
- `↓`: soft drop
- `↑` or `x`: rotate clockwise
- `g`: toggle ghost piece on/off
- `Space` (in game): hard drop
- `c`: hold piece
- `p`: pause / resume
- `r` (game over): restart
- `q` or `Ctrl+C`: quit

## Current features

- 10x20 board
- Tetromino spawn, movement, rotation, collision
- Line clearing + score + level tracking
- Level-based gravity speed curve
- Time-based lock delay (auto-lock while grounded)
- Hard drop with bonus scoring
- 7-bag piece randomizer
- Hold piece (single hold per drop)
- Ghost piece rendering (toggle with `g`)
- Next piece preview
- Line-clear feedback (terminal bell + flash message)
- Colored terminal rendering using `vxfw.RichText`

## Known limitations

- Manual interactive testing requires a real terminal/TTY; headless environments may fail with `NoDevice` when opening `/dev/tty`

## License

MIT — see [LICENSE](./LICENSE).
