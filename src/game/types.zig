pub const board_width: usize = 10;
pub const board_height: usize = 20;

pub const Piece = enum {
    I,
    O,
    T,
    S,
    Z,
    J,
    L,
};

pub const Rotation = enum(u2) {
    r0 = 0,
    r90 = 1,
    r180 = 2,
    r270 = 3,
};

pub const Position = struct {
    x: i32,
    y: i32,
};

pub const Cell = union(enum) {
    empty,
    filled: Piece,
};
