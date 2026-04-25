const types = @import("types.zig");
const state_mod = @import("state.zig");

pub const line_score_map = [5]u32{ 0, 100, 300, 500, 800 };

const Offset = struct { dx: i32, dy: i32 };

fn nextRandom(state: *state_mod.GameState) u32 {
    var x = state.random_state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    if (x == 0) x = state_mod.GameState.default_seed;
    state.random_state = x;
    return x;
}

fn refillBag(state: *state_mod.GameState) void {
    state.bag = state_mod.GameState.pieces;

    var i: usize = state.bag.len - 1;
    while (i > 0) : (i -= 1) {
        const j = @as(usize, @intCast(nextRandom(state) % @as(u32, @intCast(i + 1))));
        const tmp = state.bag[i];
        state.bag[i] = state.bag[j];
        state.bag[j] = tmp;
    }

    state.bag_remaining = @intCast(state.bag.len);
}

fn drawBagPiece(state: *state_mod.GameState) types.Piece {
    if (state.bag_remaining == 0) {
        refillBag(state);
    }

    state.bag_remaining -= 1;
    return state.bag[state.bag_remaining];
}

pub fn seedRandomizer(state: *state_mod.GameState, seed: u32) void {
    state.setSeed(seed);
    state.next_piece = drawBagPiece(state);
}

fn rotateCWValue(rot: types.Rotation) types.Rotation {
    return switch (rot) {
        .r0 => .r90,
        .r90 => .r180,
        .r180 => .r270,
        .r270 => .r0,
    };
}

const cw_kick_offsets = [_]Offset{
    .{ .dx = 0, .dy = 0 },
    .{ .dx = -1, .dy = 0 },
    .{ .dx = 1, .dy = 0 },
    .{ .dx = -2, .dy = 0 },
    .{ .dx = 2, .dy = 0 },
    .{ .dx = 0, .dy = -1 },
};

fn pieceOffsets(piece: types.Piece, rot: types.Rotation) [4]Offset {
    return switch (piece) {
        .I => switch (rot) {
            .r0 => .{ .{ .dx = 0, .dy = 1 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 2, .dy = 1 }, .{ .dx = 3, .dy = 1 } },
            .r90 => .{ .{ .dx = 2, .dy = 0 }, .{ .dx = 2, .dy = 1 }, .{ .dx = 2, .dy = 2 }, .{ .dx = 2, .dy = 3 } },
            .r180 => .{ .{ .dx = 0, .dy = 2 }, .{ .dx = 1, .dy = 2 }, .{ .dx = 2, .dy = 2 }, .{ .dx = 3, .dy = 2 } },
            .r270 => .{ .{ .dx = 1, .dy = 0 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 1, .dy = 2 }, .{ .dx = 1, .dy = 3 } },
        },
        .O => .{ .{ .dx = 1, .dy = 0 }, .{ .dx = 2, .dy = 0 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 2, .dy = 1 } },
        .T => switch (rot) {
            .r0 => .{ .{ .dx = 1, .dy = 0 }, .{ .dx = 0, .dy = 1 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 2, .dy = 1 } },
            .r90 => .{ .{ .dx = 1, .dy = 0 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 2, .dy = 1 }, .{ .dx = 1, .dy = 2 } },
            .r180 => .{ .{ .dx = 0, .dy = 1 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 2, .dy = 1 }, .{ .dx = 1, .dy = 2 } },
            .r270 => .{ .{ .dx = 1, .dy = 0 }, .{ .dx = 0, .dy = 1 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 1, .dy = 2 } },
        },
        .S => switch (rot) {
            .r0, .r180 => .{ .{ .dx = 1, .dy = 0 }, .{ .dx = 2, .dy = 0 }, .{ .dx = 0, .dy = 1 }, .{ .dx = 1, .dy = 1 } },
            .r90, .r270 => .{ .{ .dx = 1, .dy = 0 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 2, .dy = 1 }, .{ .dx = 2, .dy = 2 } },
        },
        .Z => switch (rot) {
            .r0, .r180 => .{ .{ .dx = 0, .dy = 0 }, .{ .dx = 1, .dy = 0 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 2, .dy = 1 } },
            .r90, .r270 => .{ .{ .dx = 2, .dy = 0 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 2, .dy = 1 }, .{ .dx = 1, .dy = 2 } },
        },
        .J => switch (rot) {
            .r0 => .{ .{ .dx = 0, .dy = 0 }, .{ .dx = 0, .dy = 1 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 2, .dy = 1 } },
            .r90 => .{ .{ .dx = 1, .dy = 0 }, .{ .dx = 2, .dy = 0 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 1, .dy = 2 } },
            .r180 => .{ .{ .dx = 0, .dy = 1 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 2, .dy = 1 }, .{ .dx = 2, .dy = 2 } },
            .r270 => .{ .{ .dx = 1, .dy = 0 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 0, .dy = 2 }, .{ .dx = 1, .dy = 2 } },
        },
        .L => switch (rot) {
            .r0 => .{ .{ .dx = 2, .dy = 0 }, .{ .dx = 0, .dy = 1 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 2, .dy = 1 } },
            .r90 => .{ .{ .dx = 1, .dy = 0 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 1, .dy = 2 }, .{ .dx = 2, .dy = 2 } },
            .r180 => .{ .{ .dx = 0, .dy = 1 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 2, .dy = 1 }, .{ .dx = 0, .dy = 2 } },
            .r270 => .{ .{ .dx = 0, .dy = 0 }, .{ .dx = 1, .dy = 0 }, .{ .dx = 1, .dy = 1 }, .{ .dx = 1, .dy = 2 } },
        },
    };
}

pub fn pieceCells(piece: types.Piece, pos: types.Position, rot: types.Rotation) [4]types.Position {
    const offsets = pieceOffsets(piece, rot);
    var cells: [4]types.Position = undefined;
    for (offsets, 0..) |offset, i| {
        cells[i] = .{ .x = pos.x + offset.dx, .y = pos.y + offset.dy };
    }
    return cells;
}

pub fn collides(state: *const state_mod.GameState, piece: types.Piece, pos: types.Position, rot: types.Rotation) bool {
    const cells = pieceCells(piece, pos, rot);
    for (cells) |cell| {
        const x = cell.x;
        const y = cell.y;

        if (x < 0 or x >= @as(i32, types.board_width) or y < 0 or y >= @as(i32, types.board_height)) {
            return true;
        }

        switch (state.board[@intCast(y)][@intCast(x)]) {
            .empty => {},
            .filled => return true,
        }
    }
    return false;
}

pub fn spawnPiece(state: *state_mod.GameState, forced_piece: ?types.Piece) void {
    if (state.game_over) return;

    const piece = forced_piece orelse state.next_piece;
    state.active_piece = piece;
    state.active_pos = state_mod.GameState.spawn_position;
    state.active_rot = .r0;
    if (forced_piece == null) {
        state.next_piece = drawBagPiece(state);
    }

    if (collides(state, state.active_piece, state.active_pos, state.active_rot)) {
        state.game_over = true;
    }
}

pub fn moveLeft(state: *state_mod.GameState) bool {
    if (state.game_over or state.paused) return false;
    const next_pos = types.Position{ .x = state.active_pos.x - 1, .y = state.active_pos.y };
    if (collides(state, state.active_piece, next_pos, state.active_rot)) return false;
    state.active_pos = next_pos;
    return true;
}

pub fn moveRight(state: *state_mod.GameState) bool {
    if (state.game_over or state.paused) return false;
    const next_pos = types.Position{ .x = state.active_pos.x + 1, .y = state.active_pos.y };
    if (collides(state, state.active_piece, next_pos, state.active_rot)) return false;
    state.active_pos = next_pos;
    return true;
}

pub fn moveDown(state: *state_mod.GameState) bool {
    if (state.game_over or state.paused) return false;
    const next_pos = types.Position{ .x = state.active_pos.x, .y = state.active_pos.y + 1 };
    if (collides(state, state.active_piece, next_pos, state.active_rot)) return false;
    state.active_pos = next_pos;
    return true;
}

pub fn rotateCW(state: *state_mod.GameState) bool {
    if (state.game_over or state.paused) return false;
    const next_rot = rotateCWValue(state.active_rot);
    for (cw_kick_offsets) |kick| {
        const next_pos = types.Position{
            .x = state.active_pos.x + kick.dx,
            .y = state.active_pos.y + kick.dy,
        };
        if (!collides(state, state.active_piece, next_pos, next_rot)) {
            state.active_pos = next_pos;
            state.active_rot = next_rot;
            return true;
        }
    }
    return false;
}

pub fn holdPiece(state: *state_mod.GameState) bool {
    if (state.game_over or state.paused or !state.can_hold) return false;

    const outgoing_piece = state.active_piece;

    if (state.held_piece) |held_piece| {
        state.active_piece = held_piece;
        state.active_pos = state_mod.GameState.spawn_position;
        state.active_rot = .r0;
        state.held_piece = outgoing_piece;

        if (collides(state, state.active_piece, state.active_pos, state.active_rot)) {
            state.game_over = true;
        }
    } else {
        state.held_piece = outgoing_piece;
        spawnPiece(state, null);
    }

    state.can_hold = false;
    return true;
}

pub fn lockPiece(state: *state_mod.GameState) void {
    if (state.game_over) return;
    const cells = pieceCells(state.active_piece, state.active_pos, state.active_rot);
    for (cells) |cell| {
        const x = cell.x;
        const y = cell.y;
        if (x < 0 or x >= @as(i32, types.board_width) or y < 0 or y >= @as(i32, types.board_height)) continue;
        state.board[@intCast(y)][@intCast(x)] = .{ .filled = state.active_piece };
    }
}

pub fn clearLines(state: *state_mod.GameState) u32 {
    var new_board = [_][types.board_width]types.Cell{[_]types.Cell{.empty} ** types.board_width} ** types.board_height;
    var write_y: i32 = @as(i32, types.board_height) - 1;
    var cleared: u32 = 0;

    var y: i32 = @as(i32, types.board_height) - 1;
    while (y >= 0) : (y -= 1) {
        var full = true;
        for (state.board[@intCast(y)]) |cell| {
            switch (cell) {
                .empty => {
                    full = false;
                    break;
                },
                .filled => {},
            }
        }

        if (full) {
            cleared += 1;
        } else {
            new_board[@intCast(write_y)] = state.board[@intCast(y)];
            write_y -= 1;
        }
    }

    state.board = new_board;
    return cleared;
}

pub fn updateScoreAndLevel(state: *state_mod.GameState, lines_cleared: u32) void {
    if (lines_cleared == 0) return;

    const idx = if (lines_cleared > 4) 4 else lines_cleared;
    state.score += line_score_map[idx];
    state.lines += lines_cleared;
    state.level = (state.lines / 10) + 1;
}

pub fn hardDrop(state: *state_mod.GameState) u32 {
    if (state.game_over or state.paused) return 0;

    var dropped: u32 = 0;
    while (moveDown(state)) {
        dropped += 1;
    }

    lockPiece(state);
    const cleared = clearLines(state);
    updateScoreAndLevel(state, cleared);
    spawnPiece(state, null);
    state.can_hold = true;

    return dropped;
}
