const std = @import("std");
const vaxis = @import("vaxis");

const rules = @import("game/rules.zig");
const game_state = @import("game/state.zig");
const types = @import("game/types.zig");

pub const AppMode = enum {
    start_screen,
    playing,
    paused,
    game_over,
};

fn modeLabel(mode: AppMode) []const u8 {
    return switch (mode) {
        .start_screen => "Start Screen",
        .playing => "Playing",
        .paused => "Paused",
        .game_over => "Game Over",
    };
}

fn pieceLabel(piece: types.Piece) []const u8 {
    return switch (piece) {
        .I => "I",
        .O => "O",
        .T => "T",
        .S => "S",
        .Z => "Z",
        .J => "J",
        .L => "L",
    };
}

fn isActiveCell(active_cells: [4]types.Position, x: i32, y: i32) bool {
    for (active_cells) |cell| {
        if (cell.x == x and cell.y == y) return true;
    }
    return false;
}

fn ghostLandingPosition(mode: AppMode, game: *const game_state.GameState) ?types.Position {
    // Ghost piece is purely a render aid; only compute it while an active piece
    // is meaningful for gameplay.
    if (mode != .playing and mode != .paused) return null;
    if (game.game_over) return null;

    var landing = game.active_pos;
    while (true) {
        const next_pos = types.Position{ .x = landing.x, .y = landing.y + 1 };
        if (rules.collides(game, game.active_piece, next_pos, game.active_rot)) break;
        landing = next_pos;
    }
    return landing;
}

fn pieceColor(piece: types.Piece) vaxis.Color {
    return switch (piece) {
        .I => .{ .index = 6 },
        .O => .{ .index = 3 },
        .T => .{ .index = 5 },
        .S => .{ .index = 2 },
        .Z => .{ .index = 1 },
        .J => .{ .index = 4 },
        .L => .{ .index = 208 },
    };
}

fn appendSegment(
    allocator: std.mem.Allocator,
    list: *std.ArrayList(vaxis.Segment),
    text: []const u8,
    style: vaxis.Style,
) !void {
    try list.append(allocator, .{ .text = text, .style = style });
}

fn appendFmtSegment(
    allocator: std.mem.Allocator,
    list: *std.ArrayList(vaxis.Segment),
    style: vaxis.Style,
    comptime fmt: []const u8,
    args: anytype,
) !void {
    const segment_text = try std.fmt.allocPrint(allocator, fmt, args);
    try appendSegment(allocator, list, segment_text, style);
}

fn appendBoardText(
    mode: AppMode,
    game: *const game_state.GameState,
    allocator: std.mem.Allocator,
    list: *std.ArrayList(vaxis.Segment),
) !void {
    const active_cells = rules.pieceCells(game.active_piece, game.active_pos, game.active_rot);
    const ghost_cells_opt = if (ghostLandingPosition(mode, game)) |ghost_pos|
        rules.pieceCells(game.active_piece, ghost_pos, game.active_rot)
    else
        null;
    const border_style: vaxis.Style = .{ .fg = .{ .index = 7 }, .bold = true };
    const empty_style: vaxis.Style = .{ .fg = .{ .index = 8 }, .dim = true };

    try appendSegment(allocator, list, "+--------------------+\n", border_style);
    for (0..types.board_height) |y_usize| {
        const y: i32 = @intCast(y_usize);
        try appendSegment(allocator, list, "|", border_style);
        for (0..types.board_width) |x_usize| {
            const x: i32 = @intCast(x_usize);

            const active = isActiveCell(active_cells, x, y);

            if (active) {
                const active_style: vaxis.Style = .{ .fg = pieceColor(game.active_piece), .bold = true };
                try appendSegment(allocator, list, "[]", active_style);
                continue;
            }

            const ghost = if (ghost_cells_opt) |ghost_cells|
                isActiveCell(ghost_cells, x, y)
            else
                false;
            if (ghost) {
                const ghost_style: vaxis.Style = .{ .fg = pieceColor(game.active_piece), .dim = true };
                try appendSegment(allocator, list, "[]", ghost_style);
                continue;
            }

            switch (game.board[y_usize][x_usize]) {
                .empty => {
                    try appendSegment(allocator, list, "..", empty_style);
                },
                .filled => |piece| {
                    const settled_style: vaxis.Style = .{ .fg = pieceColor(piece), .bold = true };
                    try appendSegment(allocator, list, "[]", settled_style);
                },
            }
        }
        try appendSegment(allocator, list, "|\n", border_style);
    }
    try appendSegment(allocator, list, "+--------------------+", border_style);
}

fn appendSidePanelText(game: *const game_state.GameState, allocator: std.mem.Allocator, list: *std.ArrayList(vaxis.Segment)) !void {
    const label_style: vaxis.Style = .{ .fg = .{ .index = 7 }, .bold = true };
    const value_style: vaxis.Style = .{};
    const controls_style: vaxis.Style = .{ .fg = .{ .index = 7 }, .bold = true };

    try appendFmtSegment(
        allocator,
        list,
        value_style,
        "Score: {d}\nLines: {d}\nLevel: {d}\n",
        .{ game.score, game.lines, game.level },
    );

    try appendSegment(allocator, list, "Next: ", label_style);
    const next_style: vaxis.Style = .{ .fg = pieceColor(game.next_piece), .bold = true };
    try appendFmtSegment(allocator, list, next_style, "{s}\n\n", .{pieceLabel(game.next_piece)});

    try appendSegment(allocator, list, "Hold: ", label_style);
    if (game.held_piece) |held_piece| {
        const held_style: vaxis.Style = .{ .fg = pieceColor(held_piece), .bold = true };
        try appendFmtSegment(allocator, list, held_style, "{s}\n\n", .{pieceLabel(held_piece)});
    } else {
        try appendSegment(allocator, list, "-\n\n", value_style);
    }

    try appendSegment(allocator, list, "Controls:\n", controls_style);
    try appendSegment(allocator, list, "  Enter/Space: Start\n", value_style);
    try appendSegment(allocator, list, "  Left/Right: Move\n", value_style);
    try appendSegment(allocator, list, "  Down: Soft drop\n", value_style);
    try appendSegment(allocator, list, "  Up/x: Rotate\n", value_style);
    try appendSegment(allocator, list, "  c: Hold\n", value_style);
    try appendSegment(allocator, list, "  Space: Hard drop\n", value_style);
    try appendSegment(allocator, list, "  p: Pause/resume\n", value_style);
    try appendSegment(allocator, list, "  r: Restart (game over)\n", value_style);
    try appendSegment(allocator, list, "  q: Quit\n", value_style);
}

fn overlayStyle(mode: AppMode) vaxis.Style {
    return switch (mode) {
        .paused => .{ .fg = .{ .index = 3 }, .bold = true },
        .game_over => .{ .fg = .{ .index = 1 }, .bold = true },
        .start_screen => .{ .fg = .{ .index = 6 }, .bold = true },
        .playing => .{},
    };
}

pub fn renderText(mode: AppMode, game: *const game_state.GameState, show_line_clear_flash: bool, allocator: std.mem.Allocator) ![]vaxis.Segment {
    var text: std.ArrayList(vaxis.Segment) = .empty;
    errdefer text.deinit(allocator);

    const title_style: vaxis.Style = .{ .fg = .{ .index = 7 }, .bold = true };
    const state_label_style: vaxis.Style = .{ .fg = .{ .index = 7 }, .bold = true };
    const state_value_style: vaxis.Style = .{};

    try appendSegment(allocator, &text, "libvaxis-tetris\n", title_style);
    try appendSegment(allocator, &text, "State: ", state_label_style);
    try appendFmtSegment(allocator, &text, state_value_style, "{s}\n", .{modeLabel(mode)});

    switch (mode) {
        .paused => try appendSegment(allocator, &text, ">>> PAUSED <<<\n", overlayStyle(.paused)),
        .game_over => try appendSegment(allocator, &text, ">>> GAME OVER - Press r to restart <<<\n", overlayStyle(.game_over)),
        .start_screen => try appendSegment(allocator, &text, ">>> Press Enter/Space to start <<<\n", overlayStyle(.start_screen)),
        .playing => {},
    }

    if (show_line_clear_flash) {
        const flash_style: vaxis.Style = .{ .fg = .{ .index = 2 }, .bold = true };
        try appendSegment(allocator, &text, ">>> LINE CLEAR! <<<\n", flash_style);
    }

    try appendSegment(allocator, &text, "\n", .{});
    try appendBoardText(mode, game, allocator, &text);
    try appendSegment(allocator, &text, "\n\n", .{});
    try appendSidePanelText(game, allocator, &text);

    return try text.toOwnedSlice(allocator);
}
