const types = @import("types.zig");

pub const GameState = struct {
    pub const spawn_position = types.Position{ .x = 3, .y = 0 };
    pub const pieces = [7]types.Piece{ .I, .O, .T, .S, .Z, .J, .L };
    pub const default_seed: u32 = 0x12345678;

    board: [types.board_height][types.board_width]types.Cell,

    active_piece: types.Piece,
    active_pos: types.Position,
    active_rot: types.Rotation,

    held_piece: ?types.Piece,
    can_hold: bool,

    next_piece: types.Piece,
    bag: [7]types.Piece,
    bag_remaining: u8,
    random_state: u32,

    score: u32,
    lines: u32,
    level: u32,

    paused: bool,
    game_over: bool,

    pub fn setSeed(self: *GameState, seed: u32) void {
        self.random_state = if (seed == 0) default_seed else seed;
        self.bag_remaining = 0;
    }

    pub fn init() GameState {
        return .{
            .board = [_][types.board_width]types.Cell{[_]types.Cell{.empty} ** types.board_width} ** types.board_height,
            .active_piece = .I,
            .active_pos = spawn_position,
            .active_rot = .r0,
            .held_piece = null,
            .can_hold = true,
            .next_piece = .O,
            .bag = pieces,
            .bag_remaining = 0,
            .random_state = default_seed,
            .score = 0,
            .lines = 0,
            .level = 1,
            .paused = false,
            .game_over = false,
        };
    }
};
