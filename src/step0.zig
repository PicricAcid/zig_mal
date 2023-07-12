const std = @import("std");

pub fn mal_read(stdin: anytype) !*const []u8 {
    var buf: [100]u8 = undefined;
    if (try stdin.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        return &line;
    } else {
        return error.EndOfStream;
    }
}

pub fn mal_eval(line: *const []u8) !*const []u8 {
    return line;
}

pub fn mal_print(stdout: anytype, line: *const []u8) !void {
    try stdout.print("{s}\n", .{line.*});
}

pub fn mal_rep(stdin: anytype, stdout: anytype) !void {
    var line = try mal_read(stdin);
    var l = try mal_eval(line);
    try mal_print(stdout, l);
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    while (true) {
        try stdout.print("> ", .{});
        try mal_rep(stdin, stdout);
    }
}
