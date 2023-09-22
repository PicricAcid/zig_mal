const std = @import("std");

const MalData = @import("data.zig").MalData;
const MalError = @import("error.zig").MalError;

fn skipWhilte(buf: anytype) !void {
    const r = buf.reader();

    loop: while (true) {
        switch (r.readByte() catch 0) {
            ' ', '\t', '\r', '\n' => {},
            ';' => try r.skipUntilDelimiterOrEof('\n'),
            else => |v| {
                if (v != 0) try buf.putBackByte(v);
                break :loop;
            },
        }
    }
}

fn parseNumber(a: std.mem.Allocator, buf: anytype, value: *MalData) !void {
    const r = buf.reader();

    var t = std.ArrayList(u8).init(a);

    loop: while (true) {
        switch (r.readByte() catch 0) {
            '0'...'9', '-', '+', 'e' => |v| try t.append(v),
            else => |v| {
                if (v != 0) try buf.putBackByte(v);
                break :loop;
            },
        }
    }

    var number = try std.fmt.parseInt(i64, t.items, 10);
    value.* = MalData{
        .number = number,
    };
}

fn parseSymbol(a: std.mem.Allocator, buf: anytype, value: *MalData) !void {
    const r = buf.reader();

    var t = std.ArrayList(u8).init(a);

    loop: while (true) {
        switch (r.readByte() catch 0) {
            'a'...'z', 'A'...'Z', '0'...'9', '+', '-', '*', '/', '_', '!', '?', '<', '>', '=' => |v| try t.append(v),
            else => |v| {
                if (v != 0) try buf.putBackByte(v);
                break :loop;
            },
        }
    }

    if (std.mem.eql(u8, t.items, "nil")) {
        value.* = MalData{
            .nil = undefined,
        };
    } else if (std.mem.eql(u8, t.items, "True")) {
        value.* = MalData{
            .True = undefined,
        };
    } else if (std.mem.eql(u8, t.items, "False")) {
        value.* = MalData{
            .False = undefined,
        };
    } else {
        value.* = MalData{
            .symbol = t,
        };
    }
}

pub fn read_list(a: std.mem.Allocator, buf: anytype, value: *MalData) MalError!void {
    const r = buf.reader();

    value.* = MalData{
        .list = std.ArrayList(*MalData).init(a),
    };

    loop: while (true) {
        var byte = try r.readByte();
        switch (byte) {
            ')' => {
                break :loop;
            },
            else => {
                var v = try read_atom(a, buf);
                try value.list.append(v);
            },
        }
    }
}

pub fn read_vector(a: std.mem.Allocator, buf: anytype, value: *MalData) MalError!void {
    const r = buf.reader();

    value.* = MalData{
        .vector = std.ArrayList(*MalData).init(a),
    };

    loop: while (true) {
        var byte = try r.readByte();
        switch (byte) {
            ']' => {
                break :loop;
            },
            else => {
                var v = try read_atom(a, buf);
                try value.vector.append(v);
            },
        }
    }
}

pub fn read_hashmap(a: std.mem.Allocator, buf: anytype, value: *MalData) MalError!void {
    const r = buf.reader();

    value.* = MalData{
        .hashmap = std.StringArrayHashMap(*MalData).init(a),
    };

    var key_flag: i32 = 1;
    loop: while (true) {
        var key = std.ArrayList(u8).init(a);
        defer key.deinit();

        var byte = try r.readByte();
        try buf.putBackByte(byte);
        switch (byte) {
            '}' => break :loop,
            ' ', '\t', '\r', '\n' => {
                try skipWhilte(buf);
            },
            else => {
                if (key_flag == 1) {
                    inloop: while (true) {
                        byte = try r.readByte();
                        switch (byte) {
                            ' ', '\t', '\r', '\n' => {
                                try skipWhilte(buf);
                                break :inloop;
                            },
                            else => |v| {
                                try key.append(v);
                            },
                        }
                    }
                    key_flag = 0;
                }
            }
        }
        if (key_flag == 0) {
            var data = try read_atom(a, buf);
            const keychar = key.toOwnedSlice();
            try value.hashmap.put(keychar, data);
            key_flag = 1;
        }
    }
}
 
pub fn read_string(a: std.mem.Allocator, buf: anytype, value: *MalData) !void {
    const r = buf.reader();

    var t = std.ArrayList(u8).init(a);

    loop: while (true) {
        var byte = try r.readByte();
        switch (byte) {
            '"' => {
                break :loop;
            },
            '\\' => {
                switch (r.readByte() catch 0) {
                    'n' => try t.append('\n'),
                    't' => try t.append('\t'),
                    'r' => try t.append('\r'),
                    else => |vv| try t.append(vv),
                }
            },
            else => |v| {
                try t.append(v);
            },
        }
    }

    value.* = MalData{
        .string = t,
    };
}

pub fn read_atom(a: std.mem.Allocator, buf: anytype) MalError!*MalData {
    const r = buf.reader();
    try skipWhilte(buf);

    var byte = try r.readByte();
    var value = try MalData.init(a);

    switch (byte) {
        '(' => {
            try buf.putBackByte(byte);
            try read_list(a, buf, value);
        },
        '[' => {
            try buf.putBackByte(byte);
            try read_vector(a, buf, value);
        },
        '{' => {
            try read_hashmap(a, buf, value);
        },
        '@' => {
            value.* = MalData{
                .list = std.ArrayList(*MalData).init(a),
            };

            var v = try MalData.init(a);
            v.* = MalData{
                .symbol = std.ArrayList(u8).init(a),
            };
            var w = v.symbol.writer();
            try w.print("deref", .{});

            try value.list.append(v);

            var v2 = try MalData.init(a);
            try parseSymbol(a, buf, v2);

            try value.list.append(v2);
        },
        '\'' => {
            value.* = MalData{
                .list = std.ArrayList(*MalData).init(a),
            };

            var v = try MalData.init(a);
            v.* = MalData{
                .symbol = std.ArrayList(u8).init(a),
            };
            var w = v.symbol.writer();
            try w.print("quote", .{});

            try value.list.append(v);

            var v2 = try MalData.init(a);
            try parseSymbol(a, buf, v2);

            try value.list.append(v2);
        },
        '`' => {
            value.* = MalData{
                .list = std.ArrayList(*MalData).init(a),
            };

            var v = try MalData.init(a);
            v.* = MalData{
                .symbol = std.ArrayList(u8).init(a),
            };
            var w = v.symbol.writer();
            try w.print("quasiquote", .{});

            try value.list.append(v);

            var v2 = try MalData.init(a);
            try parseSymbol(a, buf, v2);

            try value.list.append(v2);
        },
        '~' => {
            var b = try r.readByte();
            if (b == '@') {
                value.* = MalData{
                    .list = std.ArrayList(*MalData).init(a),
                };

                var v = try MalData.init(a);
                v.* = MalData{
                    .symbol = std.ArrayList(u8).init(a),
                };
                var w = v.symbol.writer();
                try w.print("unquote", .{});

                try value.list.append(v);

                var v2 = try MalData.init(a);
                try parseSymbol(a, buf, v2);

                try value.list.append(v2);
            } else {
                try buf.putBackByte(b);
                value.* = MalData{
                    .list = std.ArrayList(*MalData).init(a),
                };

                var v = try MalData.init(a);
                v.* = MalData{
                    .symbol = std.ArrayList(u8).init(a),
                };
                var w = v.symbol.writer();
                try w.print("splice-unquote", .{});

                try value.list.append(v);

                var v2 = try MalData.init(a);
                try parseSymbol(a, buf, v2);

                try value.list.append(v2);
            }
        },
        '"' => try read_string(a, buf, value),
        '0'...'9' => {
            try buf.putBackByte(byte);
            try parseNumber(a, buf, value);
        },
        'a'...'z', 'A'...'Z', '+', '-', '*', '/', '<', '>', '=' => {
            try buf.putBackByte(byte);
            try parseSymbol(a, buf, value);
        },
        ' ', '\t', '\r', '\n', ';' => try skipWhilte(buf),
        else => return error.ParseError,
    }

    return value;
}

pub fn mal_reader(r: anytype) bufReader(@TypeOf(r)) {
    return std.io.peekStream(2, r);
}

pub fn bufReader(comptime r: anytype) type {
    return std.io.PeekStream(std.fifo.LinearFifoBufferType{ .Static = 2 }, r);
}