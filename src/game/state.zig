const types = @import("types.zig");

pub const GameState = struct {
    pub const spawn_position = types.Position{ .x = 3, .y = 0 };

    board: [types.board_height][types.board_width]types.Cell,

    active_piece: types.Piece,
    active_pos: types.Position,
    active_rot: types.Rotation,

    held_piece: ?types.Piece,
    can_hold: bool,

    next_piece: types.Piece,

    score: u32,
    lines: u32,
    level: u32,

    paused: bool,
    game_over: bool,

    pub fn init() GameState {
        return .{
            .board = [_][types.board_width]types.Cell{[_]types.Cell{.empty} ** types.board_width} ** types.board_height,
            .active_piece = .I,
            .active_pos = spawn_position,
            .active_rot = .r0,
            .held_piece = null,
            .can_hold = true,
            .next_piece = .O,
            .score = 0,
            .lines = 0,
            .level = 1,
            .paused = false,
            .game_over = false,
        };
    }
};
