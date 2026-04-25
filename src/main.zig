const std = @import("std");
const app = @import("app.zig");
const build_options = @import("build_options");

const CliCommand = enum {
    run,
    help,
    version,
};

fn parseCliCommand(args: []const []const u8) !CliCommand {
    if (args.len == 0) return .run;
    if (args.len == 1 and std.mem.eql(u8, args[0], "--help")) return .help;
    if (args.len == 1 and std.mem.eql(u8, args[0], "--version")) return .version;
    return error.InvalidArgument;
}

fn printHelp() void {
    std.debug.print(
        "libvaxis_tetris {s}\nUsage: libvaxis_tetris [--help] [--version]\n\nOptions:\n  --help     Show this help message and exit.\n  --version  Show version and exit.\n",
        .{build_options.app_version},
    );
}

test "parseCliCommand supports help and version" {
    const no_args = [_][]const u8{};
    const help_arg = [_][]const u8{"--help"};
    const version_arg = [_][]const u8{"--version"};

    try std.testing.expectEqual(CliCommand.run, try parseCliCommand(&no_args));
    try std.testing.expectEqual(CliCommand.help, try parseCliCommand(&help_arg));
    try std.testing.expectEqual(CliCommand.version, try parseCliCommand(&version_arg));
}

test "parseCliCommand rejects invalid args" {
    const invalid = [_][]const u8{"--unknown"};
    try std.testing.expectError(error.InvalidArgument, parseCliCommand(&invalid));
}

pub fn main(init: std.process.Init) !void {
    var arg_iter = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer arg_iter.deinit();

    _ = arg_iter.next(); // executable name
    var args_buf: [2][]const u8 = undefined;
    var arg_count: usize = 0;
    while (arg_iter.next()) |arg| {
        if (arg_count < args_buf.len) {
            args_buf[arg_count] = arg;
        }
        arg_count += 1;
    }

    const args_slice = if (arg_count <= args_buf.len) args_buf[0..arg_count] else args_buf[0..args_buf.len];
    const command = parseCliCommand(args_slice) catch {
        std.debug.print("error: unsupported arguments\n\n", .{});
        printHelp();
        return error.InvalidArgument;
    };

    switch (command) {
        .run => try app.run(init),
        .help => printHelp(),
        .version => std.debug.print("{s}\n", .{build_options.app_version}),
    }
}
