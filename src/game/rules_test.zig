const std = @import("std");
const types = @import("types.zig");
const state_mod = @import("state.zig");
const rules = @import("rules.zig");

fn filled(piece: types.Piece) types.Cell {
    return .{ .filled = piece };
}

test "collision: bounds and filled-cell overlap" {
    var state = state_mod.GameState.init();

    try std.testing.expect(rules.collides(&state, .O, .{ .x = -2, .y = 0 }, .r0));
    try std.testing.expect(rules.collides(&state, .O, .{ .x = 9, .y = 0 }, .r0));
    try std.testing.expect(rules.collides(&state, .O, .{ .x = 3, .y = 19 }, .r0));

    state.board[1][4] = filled(.J);
    try std.testing.expect(rules.collides(&state, .O, .{ .x = 3, .y = 0 }, .r0));
}

test "move legality and rotate legality" {
    var state = state_mod.GameState.init();
    state.active_piece = .I;
    state.active_pos = .{ .x = 0, .y = 0 };
    state.active_rot = .r0;

    try std.testing.expect(!rules.moveLeft(&state));
    try std.testing.expectEqual(@as(i32, 0), state.active_pos.x);

    try std.testing.expect(rules.moveRight(&state));
    try std.testing.expectEqual(@as(i32, 1), state.active_pos.x);

    state.active_piece = .O;
    state.active_pos = .{ .x = 3, .y = 0 };
    state.active_rot = .r0;
    try std.testing.expect(rules.rotateCW(&state));
    try std.testing.expectEqual(types.Rotation.r90, state.active_rot);
}

test "rotate CW near left wall succeeds with kick" {
    var state = state_mod.GameState.init();
    state.active_piece = .I;
    state.active_pos = .{ .x = -1, .y = 0 };
    state.active_rot = .r270;

    try std.testing.expect(rules.rotateCW(&state));
    try std.testing.expectEqual(types.Rotation.r0, state.active_rot);
    try std.testing.expectEqual(types.Position{ .x = 0, .y = 0 }, state.active_pos);
}

test "rotate CW near right wall succeeds with kick" {
    var state = state_mod.GameState.init();
    state.active_piece = .I;
    state.active_pos = .{ .x = 7, .y = 0 };
    state.active_rot = .r90;

    try std.testing.expect(rules.rotateCW(&state));
    try std.testing.expectEqual(types.Rotation.r180, state.active_rot);
    try std.testing.expectEqual(types.Position{ .x = 6, .y = 0 }, state.active_pos);
}

test "rotate CW fails when all kick candidates are blocked" {
    var state = state_mod.GameState.init();
    state.active_piece = .T;
    state.active_pos = .{ .x = 3, .y = 0 };
    state.active_rot = .r0;

    state.board[1][5] = filled(.L); // (0, 0)
    state.board[1][4] = filled(.L); // (-1, 0)
    state.board[1][6] = filled(.L); // (1, 0)
    state.board[1][3] = filled(.L); // (-2, 0)
    state.board[1][7] = filled(.L); // (2, 0)

    try std.testing.expect(!rules.rotateCW(&state));
    try std.testing.expectEqual(types.Rotation.r0, state.active_rot);
    try std.testing.expectEqual(types.Position{ .x = 3, .y = 0 }, state.active_pos);
}

test "lock piece writes piece cells to board" {
    var state = state_mod.GameState.init();
    state.active_piece = .O;
    state.active_pos = .{ .x = 3, .y = 5 };
    state.active_rot = .r0;

    rules.lockPiece(&state);

    try std.testing.expectEqualDeep(filled(.O), state.board[5][4]);
    try std.testing.expectEqualDeep(filled(.O), state.board[5][5]);
    try std.testing.expectEqualDeep(filled(.O), state.board[6][4]);
    try std.testing.expectEqualDeep(filled(.O), state.board[6][5]);
}

test "clear lines single and multi" {
    var state = state_mod.GameState.init();

    for (0..types.board_width) |x| {
        state.board[types.board_height - 1][x] = filled(.I);
    }
    const cleared_one = rules.clearLines(&state);
    try std.testing.expectEqual(@as(u32, 1), cleared_one);
    for (0..types.board_width) |x| {
        try std.testing.expectEqualDeep(types.Cell.empty, state.board[types.board_height - 1][x]);
    }

    for (0..types.board_width) |x| {
        state.board[types.board_height - 1][x] = filled(.T);
        state.board[types.board_height - 2][x] = filled(.T);
    }
    state.board[types.board_height - 3][0] = filled(.S);

    const cleared_two = rules.clearLines(&state);
    try std.testing.expectEqual(@as(u32, 2), cleared_two);
    try std.testing.expectEqualDeep(filled(.S), state.board[types.board_height - 1][0]);
}

test "hard drop locks, clears, updates score and spawns" {
    var state = state_mod.GameState.init();
    state.active_piece = .O;
    state.active_pos = .{ .x = 3, .y = 0 };
    state.active_rot = .r0;
    state.next_piece = .I;

    for (0..types.board_width) |x| {
        if (x == 4 or x == 5) continue;
        state.board[types.board_height - 1][x] = filled(.Z);
    }

    const dropped = rules.hardDrop(&state);
    try std.testing.expect(dropped > 0);

    try std.testing.expectEqual(@as(u32, 100), state.score);
    try std.testing.expectEqual(@as(u32, 1), state.lines);
    try std.testing.expectEqual(@as(u32, 1), state.level);

    try std.testing.expectEqual(types.Piece.I, state.active_piece);
    try std.testing.expectEqual(types.Position{ .x = 3, .y = 0 }, state.active_pos);
    try std.testing.expectEqual(types.Rotation.r0, state.active_rot);
}

test "game over on spawn collision" {
    var state = state_mod.GameState.init();

    state.board[1][4] = filled(.L);
    rules.spawnPiece(&state, .O);

    try std.testing.expect(state.game_over);
}

test "hold with empty slot stores active and spawns next" {
    var state = state_mod.GameState.init();
    state.active_piece = .T;
    state.active_pos = .{ .x = 4, .y = 8 };
    state.active_rot = .r90;
    state.next_piece = .J;

    try std.testing.expect(rules.holdPiece(&state));
    try std.testing.expectEqual(@as(?types.Piece, .T), state.held_piece);
    try std.testing.expectEqual(types.Piece.J, state.active_piece);
    try std.testing.expectEqual(types.Position{ .x = 3, .y = 0 }, state.active_pos);
    try std.testing.expectEqual(types.Rotation.r0, state.active_rot);
    try std.testing.expectEqual(types.Piece.L, state.next_piece);
    try std.testing.expect(!state.can_hold);
}

test "hold swaps with held piece and blocks repeat hold" {
    var state = state_mod.GameState.init();
    state.active_piece = .S;
    state.active_pos = .{ .x = 5, .y = 10 };
    state.active_rot = .r180;
    state.held_piece = .O;
    state.can_hold = true;
    state.next_piece = .Z;

    try std.testing.expect(rules.holdPiece(&state));
    try std.testing.expectEqual(@as(?types.Piece, .S), state.held_piece);
    try std.testing.expectEqual(types.Piece.O, state.active_piece);
    try std.testing.expectEqual(types.Position{ .x = 3, .y = 0 }, state.active_pos);
    try std.testing.expectEqual(types.Rotation.r0, state.active_rot);
    try std.testing.expectEqual(types.Piece.Z, state.next_piece);
    try std.testing.expect(!state.can_hold);

    const prev_active = state.active_piece;
    try std.testing.expect(!rules.holdPiece(&state));
    try std.testing.expectEqual(prev_active, state.active_piece);
}

test "hold denied when paused or game over" {
    var paused_state = state_mod.GameState.init();
    paused_state.paused = true;
    try std.testing.expect(!rules.holdPiece(&paused_state));
    try std.testing.expectEqual(@as(?types.Piece, null), paused_state.held_piece);

    var game_over_state = state_mod.GameState.init();
    game_over_state.game_over = true;
    try std.testing.expect(!rules.holdPiece(&game_over_state));
    try std.testing.expectEqual(@as(?types.Piece, null), game_over_state.held_piece);
}

test "hold swap collision sets game over" {
    var state = state_mod.GameState.init();
    state.active_piece = .T;
    state.held_piece = .O;
    state.can_hold = true;

    state.board[1][4] = filled(.L);
    try std.testing.expect(rules.holdPiece(&state));

    try std.testing.expect(state.game_over);
    try std.testing.expectEqual(types.Piece.O, state.active_piece);
    try std.testing.expectEqual(@as(?types.Piece, .T), state.held_piece);
    try std.testing.expect(!state.can_hold);
}

test "hard drop resets can_hold after lock and spawn" {
    var state = state_mod.GameState.init();
    state.active_piece = .I;
    state.active_pos = .{ .x = 3, .y = 0 };
    state.active_rot = .r0;
    state.can_hold = false;

    _ = rules.hardDrop(&state);
    try std.testing.expect(state.can_hold);
}

test "spawn does not reset can_hold" {
    var state = state_mod.GameState.init();
    state.can_hold = false;
    state.next_piece = .J;

    rules.spawnPiece(&state, null);
    try std.testing.expectEqual(types.Piece.J, state.active_piece);
    try std.testing.expect(!state.can_hold);
}

test "score and level mapping" {
    var state = state_mod.GameState.init();

    rules.updateScoreAndLevel(&state, 1);
    rules.updateScoreAndLevel(&state, 2);
    rules.updateScoreAndLevel(&state, 3);
    rules.updateScoreAndLevel(&state, 4);

    try std.testing.expectEqual(@as(u32, 1700), state.score);
    try std.testing.expectEqual(@as(u32, 10), state.lines);
    try std.testing.expectEqual(@as(u32, 2), state.level);
}
