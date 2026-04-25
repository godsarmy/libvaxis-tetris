const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const game_state = @import("game/state.zig");
const rules = @import("game/rules.zig");
const types = @import("game/types.zig");

const base_gravity_ms: u32 = 1600;
const min_gravity_ms: u32 = 220;
const gravity_step_ms: u32 = 25;
const hard_drop_score_per_row: u32 = 2;
const tick_poll_ms: u32 = 50;
const lock_delay_ms: u32 = 500;

const AppMode = enum {
    start_screen,
    playing,
    paused,
    game_over,
};

const Model = struct {
    mode: AppMode = .start_screen,
    game: game_state.GameState = game_state.GameState.init(),
    lock_deadline: std.Io.Timestamp = .{ .nanoseconds = 0 },
    next_gravity_deadline: std.Io.Timestamp = .{ .nanoseconds = 0 },

    pub fn widget(self: *Model) vxfw.Widget {
        return .{
            .userdata = self,
            .eventHandler = typeErasedEventHandler,
            .drawFn = typeErasedDrawFn,
        };
    }

    fn startNewGame(self: *Model) void {
        self.game = game_state.GameState.init();
        self.lock_deadline = .{ .nanoseconds = 0 };
        rules.spawnPiece(&self.game, null);
        if (self.game.game_over) {
            self.mode = .game_over;
        } else {
            self.mode = .playing;
        }
    }

    fn settleAfterDownBlocked(self: *Model) void {
        self.lock_deadline = .{ .nanoseconds = 0 };
        rules.lockPiece(&self.game);
        const cleared = rules.clearLines(&self.game);
        rules.updateScoreAndLevel(&self.game, cleared);
        rules.spawnPiece(&self.game, null);
        self.game.can_hold = true;
        if (self.game.game_over) {
            self.mode = .game_over;
        }
    }

    fn clearLockPending(self: *Model) void {
        self.lock_deadline = .{ .nanoseconds = 0 };
    }

    fn isGrounded(self: *const Model) bool {
        const below = types.Position{ .x = self.game.active_pos.x, .y = self.game.active_pos.y + 1 };
        return rules.collides(&self.game, self.game.active_piece, below, self.game.active_rot);
    }

    fn gravityMsForLevel(level: u32) u32 {
        const level_offset = if (level > 0) level - 1 else 0;
        const reduction = level_offset * gravity_step_ms;
        if (reduction >= (base_gravity_ms - min_gravity_ms)) {
            return min_gravity_ms;
        }
        return base_gravity_ms - reduction;
    }

    fn resetGravityDeadline(self: *Model, io: std.Io) void {
        const interval_ms = gravityMsForLevel(self.game.level);
        const now = std.Io.Timestamp.now(io, .real);
        self.next_gravity_deadline = now.addDuration(.fromMilliseconds(interval_ms));
    }

    fn togglePause(self: *Model) void {
        switch (self.mode) {
            .playing => {
                self.mode = .paused;
                self.game.paused = true;
            },
            .paused => {
                self.mode = .playing;
                self.game.paused = false;
                self.next_gravity_deadline = .{ .nanoseconds = 0 };
            },
            else => {},
        }
    }

    fn modeLabel(self: *const Model) []const u8 {
        return switch (self.mode) {
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

    fn ghostLandingPosition(self: *const Model) ?types.Position {
        // Ghost piece is purely a render aid; only compute it while an active piece
        // is meaningful for gameplay.
        if (self.mode != .playing and self.mode != .paused) return null;
        if (self.game.game_over) return null;

        var landing = self.game.active_pos;
        while (true) {
            const next_pos = types.Position{ .x = landing.x, .y = landing.y + 1 };
            if (rules.collides(&self.game, self.game.active_piece, next_pos, self.game.active_rot)) break;
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

    fn appendBoardText(self: *const Model, allocator: std.mem.Allocator, list: *std.ArrayList(vaxis.Segment)) !void {
        const active_cells = rules.pieceCells(self.game.active_piece, self.game.active_pos, self.game.active_rot);
        const ghost_cells_opt = if (self.ghostLandingPosition()) |ghost_pos|
            rules.pieceCells(self.game.active_piece, ghost_pos, self.game.active_rot)
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
                    const active_style: vaxis.Style = .{ .fg = pieceColor(self.game.active_piece), .bold = true };
                    try appendSegment(allocator, list, "[]", active_style);
                    continue;
                }

                const ghost = if (ghost_cells_opt) |ghost_cells|
                    isActiveCell(ghost_cells, x, y)
                else
                    false;
                if (ghost) {
                    const ghost_style: vaxis.Style = .{ .fg = pieceColor(self.game.active_piece), .dim = true };
                    try appendSegment(allocator, list, "[]", ghost_style);
                    continue;
                }

                switch (self.game.board[y_usize][x_usize]) {
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

    fn appendSidePanelText(self: *const Model, allocator: std.mem.Allocator, list: *std.ArrayList(vaxis.Segment)) !void {
        const label_style: vaxis.Style = .{ .fg = .{ .index = 7 }, .bold = true };
        const value_style: vaxis.Style = .{};
        const controls_style: vaxis.Style = .{ .fg = .{ .index = 7 }, .bold = true };

        try appendFmtSegment(
            allocator,
            list,
            value_style,
            "Score: {d}\nLines: {d}\nLevel: {d}\n",
            .{ self.game.score, self.game.lines, self.game.level },
        );

        try appendSegment(allocator, list, "Next: ", label_style);
        const next_style: vaxis.Style = .{ .fg = pieceColor(self.game.next_piece), .bold = true };
        try appendFmtSegment(allocator, list, next_style, "{s}\n\n", .{pieceLabel(self.game.next_piece)});

        try appendSegment(allocator, list, "Hold: ", label_style);
        if (self.game.held_piece) |held_piece| {
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

    fn renderText(self: *const Model, allocator: std.mem.Allocator) ![]vaxis.Segment {
        var text: std.ArrayList(vaxis.Segment) = .empty;
        errdefer text.deinit(allocator);

        const title_style: vaxis.Style = .{ .fg = .{ .index = 7 }, .bold = true };
        const state_label_style: vaxis.Style = .{ .fg = .{ .index = 7 }, .bold = true };
        const state_value_style: vaxis.Style = .{};

        try appendSegment(allocator, &text, "libvaxis-tetris\n", title_style);
        try appendSegment(allocator, &text, "State: ", state_label_style);
        try appendFmtSegment(allocator, &text, state_value_style, "{s}\n", .{self.modeLabel()});

        switch (self.mode) {
            .paused => try appendSegment(allocator, &text, ">>> PAUSED <<<\n", overlayStyle(.paused)),
            .game_over => try appendSegment(allocator, &text, ">>> GAME OVER - Press r to restart <<<\n", overlayStyle(.game_over)),
            .start_screen => try appendSegment(allocator, &text, ">>> Press Enter/Space to start <<<\n", overlayStyle(.start_screen)),
            .playing => {},
        }

        try appendSegment(allocator, &text, "\n", .{});
        try appendBoardText(self, allocator, &text);
        try appendSegment(allocator, &text, "\n\n", .{});
        try appendSidePanelText(self, allocator, &text);

        return try text.toOwnedSlice(allocator);
    }

    fn scheduleGravity(self: *Model, ctx: *vxfw.EventContext) !void {
        try ctx.tick(tick_poll_ms, self.widget());
    }

    fn typeErasedEventHandler(ptr: *anyopaque, ctx: *vxfw.EventContext, event: vxfw.Event) anyerror!void {
        const self: *Model = @ptrCast(@alignCast(ptr));
        switch (event) {
            .init => {
                try ctx.requestFocus(self.widget());
                try self.scheduleGravity(ctx);
            },
            .focus_in => {
                try ctx.requestFocus(self.widget());
            },
            .tick => {
                if (self.mode == .playing) {
                    const now = std.Io.Timestamp.now(ctx.io, .real);

                    if (self.lock_deadline.nanoseconds != 0 and now.nanoseconds >= self.lock_deadline.nanoseconds) {
                        if (self.isGrounded()) {
                            self.settleAfterDownBlocked();
                            self.resetGravityDeadline(ctx.io);
                            ctx.redraw = true;
                        } else {
                            self.clearLockPending();
                        }
                    }

                    if (self.next_gravity_deadline.nanoseconds == 0 or now.nanoseconds >= self.next_gravity_deadline.nanoseconds) {
                        if (rules.moveDown(&self.game)) {
                            self.clearLockPending();
                        } else {
                            if (self.lock_deadline.nanoseconds == 0) {
                                self.lock_deadline = now.addDuration(.fromMilliseconds(lock_delay_ms));
                            }
                        }
                        self.resetGravityDeadline(ctx.io);
                        ctx.redraw = true;
                    }
                }
                try self.scheduleGravity(ctx);
            },
            .key_press => |key| {
                if (key.matches('q', .{}) or key.matches('c', .{ .ctrl = true })) {
                    ctx.quit = true;
                    return;
                }

                var changed: bool = false;

                switch (self.mode) {
                    .start_screen => {
                        if (key.matches(vaxis.Key.enter, .{}) or key.matches(vaxis.Key.space, .{})) {
                            self.startNewGame();
                            self.resetGravityDeadline(ctx.io);
                            changed = true;
                        }
                    },
                    .playing => {
                        if (key.matches('p', .{})) {
                            self.togglePause();
                            changed = true;
                        } else if (key.matches(vaxis.Key.left, .{})) {
                            if (rules.moveLeft(&self.game)) {
                                self.clearLockPending();
                                changed = true;
                            }
                        } else if (key.matches(vaxis.Key.right, .{})) {
                            if (rules.moveRight(&self.game)) {
                                self.clearLockPending();
                                changed = true;
                            }
                        } else if (key.matches(vaxis.Key.down, .{})) {
                            if (rules.moveDown(&self.game)) {
                                self.clearLockPending();
                                changed = true;
                            }
                        } else if (key.matches(vaxis.Key.up, .{}) or key.matches('x', .{})) {
                            if (rules.rotateCW(&self.game)) {
                                self.clearLockPending();
                                changed = true;
                            }
                        } else if (key.matches('c', .{})) {
                            self.clearLockPending();
                            if (rules.holdPiece(&self.game)) changed = true;
                            if (self.game.game_over) self.mode = .game_over;
                        } else if (key.matches(vaxis.Key.space, .{})) {
                            self.clearLockPending();
                            const dropped = rules.hardDrop(&self.game);
                            self.game.score += dropped * hard_drop_score_per_row;
                            changed = true;
                            if (self.game.game_over) self.mode = .game_over;
                        }
                    },
                    .paused => {
                        if (key.matches('p', .{})) {
                            self.togglePause();
                            changed = true;
                        }
                    },
                    .game_over => {
                        if (key.matches('r', .{})) {
                            self.startNewGame();
                            self.resetGravityDeadline(ctx.io);
                            changed = true;
                        }
                    },
                }

                if (changed) {
                    ctx.redraw = true;
                }
            },
            else => {},
        }
    }

    fn typeErasedDrawFn(ptr: *anyopaque, ctx: vxfw.DrawContext) std.mem.Allocator.Error!vxfw.Surface {
        const self: *Model = @ptrCast(@alignCast(ptr));
        const text_spans = try renderText(self, ctx.arena);

        const text: vxfw.RichText = .{
            .text = text_spans,
            .softwrap = false,
        };
        const text_child: vxfw.SubSurface = .{
            .origin = .{ .row = 0, .col = 0 },
            .surface = try text.draw(ctx),
        };

        const children = try ctx.arena.alloc(vxfw.SubSurface, 1);
        children[0] = text_child;

        return .{
            .size = ctx.max.size(),
            .widget = self.widget(),
            .buffer = &.{},
            .children = children,
        };
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.gpa;

    var buffer: [2048]u8 = undefined;
    var app: vxfw.App = try .init(io, alloc, init.environ_map, &buffer);
    defer app.deinit();

    var model: Model = .{};
    try app.run(model.widget(), .{});
}
