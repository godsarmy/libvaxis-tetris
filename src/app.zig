const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const game_state = @import("game/state.zig");
const rules = @import("game/rules.zig");
const types = @import("game/types.zig");
const ui = @import("ui.zig");

const base_gravity_ms: u32 = 1600;
const min_gravity_ms: u32 = 220;
const gravity_step_ms: u32 = 25;
const hard_drop_score_per_row: u32 = 2;

// We poll ticks at a small fixed interval instead of waiting for the exact
// gravity interval so the app can react promptly to input/focus changes and
// lock-delay deadlines without stalling redraws between long gravity steps.
const tick_poll_ms: u32 = 50;
const line_clear_flash_ms: u32 = 160;

// When the active piece first touches the stack/floor we start this timer,
// then lock only if it is still grounded at expiry. This preserves expected
// movement/rotation grace time and avoids instant lock on contact.
const lock_delay_ms: u32 = 500;

pub const Model = struct {
    mode: ui.AppMode = .start_screen,
    game: game_state.GameState = game_state.GameState.init(),
    lock_deadline: std.Io.Timestamp = .{ .nanoseconds = 0 },
    next_gravity_deadline: std.Io.Timestamp = .{ .nanoseconds = 0 },
    line_clear_flash_deadline: std.Io.Timestamp = .{ .nanoseconds = 0 },

    pub fn widget(self: *Model) vxfw.Widget {
        return .{
            .userdata = self,
            .eventHandler = typeErasedEventHandler,
            .drawFn = typeErasedDrawFn,
        };
    }

    fn startNewGame(self: *Model, io: std.Io) void {
        self.game = game_state.GameState.init();
        self.lock_deadline = .{ .nanoseconds = 0 };
        self.line_clear_flash_deadline = .{ .nanoseconds = 0 };
        const now_ns: u64 = @intCast(std.Io.Timestamp.now(io, .real).nanoseconds);
        const seed: u32 = @truncate(now_ns ^ (now_ns >> 32));
        rules.seedRandomizer(&self.game, seed);
        rules.spawnPiece(&self.game, null);
        if (self.game.game_over) {
            self.mode = .game_over;
        } else {
            self.mode = .playing;
        }
    }

    fn settleAfterDownBlocked(self: *Model, io: std.Io) void {
        self.lock_deadline = .{ .nanoseconds = 0 };
        rules.lockPiece(&self.game);
        const cleared = rules.clearLines(&self.game);
        rules.updateScoreAndLevel(&self.game, cleared);
        self.triggerLineClearFeedback(io, cleared);
        rules.spawnPiece(&self.game, null);
        self.game.can_hold = true;
        if (self.game.game_over) {
            self.mode = .game_over;
        }
    }

    fn triggerLineClearFeedback(self: *Model, io: std.Io, lines_cleared: u32) void {
        if (lines_cleared == 0) return;
        std.debug.print("\x07", .{});
        const now = std.Io.Timestamp.now(io, .real);
        self.line_clear_flash_deadline = now.addDuration(.fromMilliseconds(line_clear_flash_ms));
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

    fn scheduleGravity(self: *Model, ctx: *vxfw.EventContext) !void {
        try ctx.tick(tick_poll_ms, self.widget());
    }

    fn typeErasedEventHandler(ptr: *anyopaque, ctx: *vxfw.EventContext, event: vxfw.Event) anyerror!void {
        const self: *Model = @ptrCast(@alignCast(ptr));
        switch (event) {
            .init => {
                // Keep focus on this widget from startup so key handling remains
                // deterministic across terminal focus transitions.
                try ctx.requestFocus(self.widget());
                try self.scheduleGravity(ctx);
            },
            .focus_in => {
                // Re-request focus after focus-in events; some terminals/window
                // managers can shift focus during redraws.
                try ctx.requestFocus(self.widget());
            },
            .tick => {
                const now = std.Io.Timestamp.now(ctx.io, .real);

                if (self.line_clear_flash_deadline.nanoseconds != 0 and now.nanoseconds >= self.line_clear_flash_deadline.nanoseconds) {
                    self.line_clear_flash_deadline = .{ .nanoseconds = 0 };
                    ctx.redraw = true;
                }

                if (self.mode == .playing) {
                    if (self.lock_deadline.nanoseconds != 0 and now.nanoseconds >= self.lock_deadline.nanoseconds) {
                        if (self.isGrounded()) {
                            self.settleAfterDownBlocked(ctx.io);
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
                        // Redraw only when gravity advances or lock-delay state
                        // changes so visuals stay current without extra churn.
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
                            self.startNewGame(ctx.io);
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
                            const lines_before = self.game.lines;
                            const dropped = rules.hardDrop(&self.game);
                            self.game.score += dropped * hard_drop_score_per_row;
                            const lines_cleared = self.game.lines - lines_before;
                            self.triggerLineClearFeedback(ctx.io, lines_cleared);
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
                            self.startNewGame(ctx.io);
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
        const show_line_clear_flash = self.line_clear_flash_deadline.nanoseconds != 0;
        const text_spans = try ui.renderText(self.mode, &self.game, show_line_clear_flash, ctx.arena);

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

pub fn run(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.gpa;

    var buffer: [2048]u8 = undefined;
    var app: vxfw.App = try .init(io, alloc, init.environ_map, &buffer);
    defer app.deinit();

    var model: Model = .{};
    try app.run(model.widget(), .{});
}
