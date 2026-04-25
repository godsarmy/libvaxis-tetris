# libvaxis Tetris Plan (Zig 0.16)

Use this as a live checklist. Mark items as you complete them.

## Legend
- [ ] Not started
- [~] In progress
- [x] Done
- [!] Blocked

---

## Phase 0 — Project setup

### 0.1 Initialize repo for Zig app
- [x] Run `zig init`
- [x] Confirm `build.zig` and `src/main.zig` exist
- [x] Run `zig build` once to verify baseline compiles

### 0.2 Add libvaxis dependency
- [x] Run `zig fetch --save git+https://github.com/rockorager/libvaxis.git`
- [x] Wire dependency in `build.zig`:
  - [x] `const vaxis = b.dependency("vaxis", .{ ... })`
  - [x] `exe.root_module.addImport("vaxis", vaxis.module("vaxis"))`
- [x] Build again to confirm dependency setup

### 0.3 Minimal vaxis boot test
- [x] In `src/main.zig`, create minimal app that initializes vaxis
- [x] Enter alt screen, render a simple label, exit cleanly
- [!] Confirm app runs without panic (blocked in this environment: `/dev/tty` unavailable, error `NoDevice`)

**Exit criteria:** project builds and can render one frame with vaxis.

---

## Phase 1 — Core game model (pure logic, no terminal rendering)

### 1.1 Define core data types (`src/game/types.zig`)
- [x] Board constants: width=10, height=20
- [x] Cell enum / block representation
- [x] Piece enum (I, O, T, S, Z, J, L)
- [x] Rotation state enum (0/90/180/270)
- [x] Position struct (`x`, `y`)

### 1.2 Define game state (`src/game/state.zig`)
- [x] Board array storage
- [x] Active piece + position + rotation
- [x] Next queue (start with 1-next; extend later)
- [x] Score, lines, level
- [x] Flags: paused, game_over

### 1.3 Implement rules (`src/game/rules.zig`)
- [x] Piece spawn
- [x] Collision detection
- [x] Horizontal move (+ bounds checks)
- [x] Soft drop by one row
- [x] Rotation (basic, no kicks initially)
- [x] Lock piece into board
- [x] Line clear detection + compaction
- [x] Score update per lines cleared
- [x] Level progression trigger

### 1.4 Unit tests for pure logic (`src/game/rules_test.zig`)
- [x] Collision tests
- [x] Move/rotate legality tests
- [x] Lock behavior tests
- [x] Single/multi line clear tests
- [x] Game-over-on-spawn test

**Exit criteria:** all pure logic tests pass; game state transitions are deterministic.

---

## Phase 2 — Runtime loop and controls

### 2.1 Event loop and timing (`src/app.zig` or `src/main.zig`)
- [x] Add fixed gravity tick (start ~500ms)
- [x] Separate input events from tick updates
- [x] Maintain monotonic timing for stable gameplay

### 2.2 Input mapping
- [x] Left/Right arrows: move piece
- [x] Down: soft drop
- [x] Up or `x`: rotate CW
- [x] Space: hard drop
- [x] `p`: pause/resume
- [x] `q` or Ctrl+C: quit

### 2.3 State transitions
- [x] Start screen -> playing
- [x] Playing -> paused -> playing
- [x] Playing -> game over
- [x] Game over -> restart

**Exit criteria:** keyboard controls and gravity update the game model correctly.

---

## Phase 3 — Terminal rendering with libvaxis

### 3.1 Screen layout
- [x] Playfield box (10x20 visible cells)
- [x] Side panel: score, lines, level
- [x] Side panel: next piece preview
- [x] Footer/help controls

### 3.2 Draw pipeline
- [x] Clear/redraw frame each tick or state change
- [x] Render settled board cells
- [x] Render active falling piece
- [x] Render pause/game-over overlays

### 3.3 Visual style
- [x] Assign colors per tetromino type
- [x] Ensure readable fallback on low-color terminals
- [x] Keep consistent border/spacing

**Exit criteria:** game is fully playable and visually readable in terminal.

---

## Phase 4 — Gameplay polish

### 4.1 Mechanics improvements
- [x] Lock delay
- [x] Hard drop scoring bonus
- [x] Better gravity curve by level
- [ ] Optional basic wall-kick rules

### 4.2 Quality-of-life
- [x] Ghost piece
- [x] Hold piece (single hold per drop)
- [x] Pause hint and restart hint text

### 4.3 Optional audio/feedback (if desired)
- [ ] Terminal bell/visual flash on line clear (optional)

**Exit criteria:** gameplay feels responsive and close to modern Tetris behavior.

---

## Phase 5 — Verification and packaging

### 5.1 Validation
- [x] Run `zig test` for game logic modules
- [x] Run `zig build`
- [!] Manual play test (10+ minutes) (blocked in this environment: `/dev/tty` unavailable)
- [!] Resize terminal during play and verify behavior (blocked in this environment: `/dev/tty` unavailable)

### 5.2 Cleanup
- [ ] Split code into modules (`game`, `ui`, `app`)
- [ ] Add comments for non-obvious rules
- [x] Remove dead code and debug prints

### 5.3 Documentation
- [x] Add `README.md` with:
  - [x] Build/run instructions
  - [x] Controls
  - [x] Feature list
  - [x] Known limitations

**Exit criteria:** reproducible build, tested gameplay, clear docs.

---

## Suggested implementation order (strict)
1. Phase 0
2. Phase 1
3. Phase 2
4. Phase 3
5. Phase 5.1 baseline checks
6. Phase 4 polish
7. Phase 5 full cleanup/docs

---

## Progress snapshot
- Overall status: [~] In progress
- Current phase: `5`
- Next actionable item: `5.2 Cleanup`
