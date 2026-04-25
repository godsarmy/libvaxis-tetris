const std = @import("std");
const rules = @import("rules.zig");
const state_mod = @import("state.zig");
const types = @import("types.zig");

fn pieceIndex(piece: types.Piece) usize {
    return @intFromEnum(piece);
}

fn filled(piece: types.Piece) types.Cell {
    return .{ .filled = piece };
}

test "seedRandomizer is deterministic for equal seed" {
    var a = state_mod.GameState.init();
    var b = state_mod.GameState.init();

    rules.seedRandomizer(&a, 0xBEEF1234);
    rules.seedRandomizer(&b, 0xBEEF1234);

    for (0..24) |_| {
        rules.spawnPiece(&a, null);
        rules.spawnPiece(&b, null);
        try std.testing.expectEqual(a.active_piece, b.active_piece);
        try std.testing.expectEqual(a.next_piece, b.next_piece);
    }
}

test "seedRandomizer zero matches default-seed sequence" {
    var zero_seed = state_mod.GameState.init();
    var default_seed = state_mod.GameState.init();

    rules.seedRandomizer(&zero_seed, 0);
    rules.seedRandomizer(&default_seed, state_mod.GameState.default_seed);

    for (0..20) |_| {
        rules.spawnPiece(&zero_seed, null);
        rules.spawnPiece(&default_seed, null);
        try std.testing.expectEqual(zero_seed.active_piece, default_seed.active_piece);
    }
}

test "spawnPiece forced piece does not consume next piece" {
    var state = state_mod.GameState.init();
    rules.seedRandomizer(&state, 123456);
    const next_before = state.next_piece;

    rules.spawnPiece(&state, .T);

    try std.testing.expectEqual(types.Piece.T, state.active_piece);
    try std.testing.expectEqual(next_before, state.next_piece);
}

test "clearLines no-op preserves board when no full rows" {
    var state = state_mod.GameState.init();
    state.board[types.board_height - 1][0] = filled(.I);
    state.board[types.board_height - 2][5] = filled(.T);
    const before = state.board;

    const cleared = rules.clearLines(&state);

    try std.testing.expectEqual(@as(u32, 0), cleared);
    try std.testing.expectEqualDeep(before, state.board);
}

test "updateScoreAndLevel clamps score index above four lines" {
    var state = state_mod.GameState.init();

    rules.updateScoreAndLevel(&state, 5);

    try std.testing.expectEqual(rules.line_score_map[4], state.score);
    try std.testing.expectEqual(@as(u32, 5), state.lines);
    try std.testing.expectEqual(@as(u32, 1), state.level);
}

test "hardDrop returns zero and preserves state when paused" {
    var state = state_mod.GameState.init();
    rules.seedRandomizer(&state, 999);
    const next_before = state.next_piece;
    const board_before = state.board;
    const active_before = state.active_piece;
    const pos_before = state.active_pos;
    const rot_before = state.active_rot;
    state.paused = true;

    const dropped = rules.hardDrop(&state);

    try std.testing.expectEqual(@as(u32, 0), dropped);
    try std.testing.expectEqualDeep(board_before, state.board);
    try std.testing.expectEqual(active_before, state.active_piece);
    try std.testing.expectEqual(pos_before, state.active_pos);
    try std.testing.expectEqual(rot_before, state.active_rot);
    try std.testing.expectEqual(next_before, state.next_piece);
}

test "7-bag draw count over two bags remains balanced" {
    var state = state_mod.GameState.init();
    rules.seedRandomizer(&state, 424242);

    var counts = [_]u32{0} ** 7;
    for (0..14) |_| {
        rules.spawnPiece(&state, null);
        counts[pieceIndex(state.active_piece)] += 1;
    }

    for (counts) |count| {
        try std.testing.expectEqual(@as(u32, 2), count);
    }
}
