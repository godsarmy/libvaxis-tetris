const std = @import("std");
const state_mod = @import("state.zig");
const types = @import("types.zig");

test "GameState.init sets expected defaults" {
    const state = state_mod.GameState.init();

    try std.testing.expectEqual(types.Position{ .x = 3, .y = 0 }, state.active_pos);
    try std.testing.expectEqual(types.Rotation.r0, state.active_rot);
    try std.testing.expectEqual(@as(?types.Piece, null), state.held_piece);
    try std.testing.expect(state.can_hold);
    try std.testing.expectEqual(@as(u8, 0), state.bag_remaining);
    try std.testing.expectEqual(state_mod.GameState.default_seed, state.random_state);
    try std.testing.expectEqual(@as(u32, 0), state.score);
    try std.testing.expectEqual(@as(u32, 0), state.lines);
    try std.testing.expectEqual(@as(u32, 1), state.level);
    try std.testing.expect(!state.paused);
    try std.testing.expect(!state.game_over);

    for (state.board) |row| {
        for (row) |cell| {
            try std.testing.expectEqualDeep(types.Cell.empty, cell);
        }
    }
}

test "GameState.setSeed with zero falls back to default seed" {
    var state = state_mod.GameState.init();
    state.bag_remaining = 3;

    state.setSeed(0);

    try std.testing.expectEqual(state_mod.GameState.default_seed, state.random_state);
    try std.testing.expectEqual(@as(u8, 0), state.bag_remaining);
}

test "GameState.setSeed with non-zero preserves explicit seed" {
    var state = state_mod.GameState.init();
    state.bag_remaining = 4;

    state.setSeed(0xA5A5A5A5);

    try std.testing.expectEqual(@as(u32, 0xA5A5A5A5), state.random_state);
    try std.testing.expectEqual(@as(u8, 0), state.bag_remaining);
}
