const std = @import("std");

const MalError = error{
    SyntaxError,
    ParseError,
    PrintError,
    HashMapError,
    FuncArgError,
    OutOfMemory,
    AccessDenied,
    BrokenPipe,
    ConnectionResetByPeer,
    InputOutput,
    OperationAborted,
    SystemResources,
    Unexpected,
    WouldBlock,
    ConnectionTimedOut,
    IsDir,
    NotOpenForReading,
    EndOfStream,
    InvalidCharacter,
    Overflow,
};

const MalData = union(enum) {
    number: i64,
    symbol: std.ArrayList(u8),
    list: std.ArrayList(*MalData),
    vector: std.ArrayList(*MalData),
    string: std.ArrayList(u8),
    nil: void,
    True: void,
    False: void,
    hashmap: std.StringArrayHashMap(*MalData),
    function: *const fn (a: std.mem.Allocator, args: *MalData) MalError!*MalData,

    const Self = @This();

    pub fn init(a: std.mem.Allocator) !*Self {
        return try a.create(MalData);
    }

    pub fn deinit(self: *Self, a: std.mem.Allocator) void {
        switch (self.*) {
            .number => {},
            .symbol => |s| s.deinit(),
            .list => |l| {
                for (l.items) |i| {
                    i.deinit(a);
                }
                l.deinit();
            },
            .vector => |v| {
                for (v.items) |i| {
                    i.deinit(a);
                }
                v.deinit();
            },
            .string => |s| s.deinit(),
            .nil => {},
            .True => {},
            .False => {},
            .hashmap => |h| {
                var iterator = h.iterator();
                var n = iterator.next();
                while (true) {
                    const pair = n orelse break;
                    a.free(pair.key_ptr.*);
                    pair.value_ptr.*.deinit(a);
                    n = iterator.next();
                }
                self.hashmap.deinit();
            },
            .function => {},
        }

        a.destroy(self);
    }
};

fn mal_add(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    if (args.* == MalData.list) {
        var l = args.list;
        if (l.items.len == 3) {
            if ((l.items[1].* == MalData.number) and (l.items[2].* == MalData.number)) {
                var result = try MalData.init(a);
                result.* = MalData{
                    .number = l.items[1].number + l.items[2].number,
                };

                return result;
            } else {
                return MalError.FuncArgError;
            }
        } else {
            return MalError.FuncArgError;
        }
    } else {
        return MalError.FuncArgError;
    }
}

fn mal_sub(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    if (args.* == MalData.list) {
        var l = args.list;
        if (l.items.len == 3) {
            if ((l.items[1].* == MalData.number) and (l.items[2].* == MalData.number)) {
                var result = try MalData.init(a);
                result.* = MalData{
                    .number = l.items[1].number - l.items[2].number,
                };

                return result;
            } else {
                return MalError.FuncArgError;
            }
        } else {
            return MalError.FuncArgError;
        }
    } else {
        return MalError.FuncArgError;
    }
}

fn mal_mul(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    if (args.* == MalData.list) {
        var l = args.list;
        if (l.items.len == 3) {
            if ((l.items[1].* == MalData.number) and (l.items[2].* == MalData.number)) {
                var result = try MalData.init(a);
                result.* = MalData{
                    .number = l.items[1].number * l.items[2].number,
                };

                return result;
            } else {
                return MalError.FuncArgError;
            }
        } else {
            return MalError.FuncArgError;
        }
    } else {
        return MalError.FuncArgError;
    }
}

fn mal_div(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    if (args.* == MalData.list) {
        var l = args.list;
        if (l.items.len == 3) {
            if ((l.items[1].* == MalData.number) and (l.items[2].* == MalData.number)) {
                var result = try MalData.init(a);
                result.* = MalData{
                    .number = @divTrunc(l.items[1].number, l.items[2].number),
                };

                return result;
            } else {
                return MalError.FuncArgError;
            }
        } else {
            return MalError.FuncArgError;
        }
    } else {
        return MalError.FuncArgError;
    }
}

fn make_env(a: std.mem.Allocator) MalError!*MalData {
    var env = try MalData.init(a);

    env.* = MalData{
        .hashmap = std.StringArrayHashMap(*MalData).init(a),
    };

    var add = try MalData.init(a);
    add.* = MalData{
        .function = &mal_add,
    };
    try env.hashmap.put("+", add);

    var sub = try MalData.init(a);
    sub.* = MalData{
        .function = &mal_sub,
    };
    try env.hashmap.put("-", sub);

    var mul = try MalData.init(a);
    mul.* = MalData{
        .function = &mal_mul,
    };
    try env.hashmap.put("*", mul);

    var div = try MalData.init(a);
    div.* = MalData{
        .function = &mal_div,
    };
    try env.hashmap.put("/", div);

    return env;
}

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
            'a'...'z', 'A'...'Z', '0'...'9', '+', '-', '*', '/', '_' => |v| try t.append(v),
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
        '"' => try read_string(a, buf, value),
        '0'...'9' => {
            try buf.putBackByte(byte);
            try parseNumber(a, buf, value);
        },
        'a'...'z', 'A'...'Z', '+', '-', '*', '/' => {
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

pub fn print_str(stdout: anytype, root: *MalData) !void {
    switch (root.*) {
        .number => |n| {
            try stdout.print("{}\n", .{n});
        },
        .symbol => |s| {
            try stdout.print("{s}\n", .{s.items});
        },
        .string => |s| {
            try stdout.print("{s}", .{s.items});
        },
        .list => |l| {
            for (l.items) |i| {
                try print_str(stdout, i);
            }
        },
        .vector => |v| {
            for (v.items) |i| {
                try print_str(stdout, i);
            }
        },
        .nil => try stdout.print("nil\n", .{}),
        .True => try stdout.print("True\n", .{}),
        .False => try stdout.print("False\n", .{}),
        .hashmap => |h| {
            var i = h.iterator();
            while (i.next()) |v| {
                try stdout.print("#{s}: {}, ", .{v.key_ptr.*, v.value_ptr.*});
            }
            try stdout.print("\n", .{});
        },
        .function => {
            try stdout.print("function\n", .{});
        },
    }
}

pub fn eval_ast(a: std.mem.Allocator, env: *MalData, arg: *MalData) MalError!*MalData {
    var result = try MalData.init(a);

    switch(arg.*) {
        .symbol => |s| {
            result.* = MalData{
                .function = env.hashmap.get(s.items).?.function,
            };
        },
        .list => |l| {
            result.* = MalData{
                .list = std.ArrayList(*MalData).init(a),
            };
            for (l.items) |i| {
                var r = try mal_eval(a, env, i);
                try result.list.append(r);
            }
            arg.deinit(a);
        },
        .vector => |v| {
            result.* = MalData{
                .vector = std.ArrayList(*MalData).init(a),
            };
            for (v.items) |i| {
                var r = try mal_eval(a, env, i);
                try result.vector.append(r);
            }
            arg.deinit(a);
        },
        .hashmap => |h| {
            result.* = MalData{
                .hashmap = std.StringArrayHashMap(*MalData).init(a),
            };
            var i = h.iterator();
            while (i.next()) |v| {
                var value = try mal_eval(a, env, v.value_ptr.*);
                try result.hashmap.put(v.key_ptr.*, value);
            }
            arg.deinit(a);
        },
        else => {
            result = arg;
        },
    }

    return result;
}

pub fn mal_read(stdin: anytype, a: std.mem.Allocator) !*MalData {
    var buf = mal_reader(stdin);
    var root = try read_atom(a, &buf);

    return root;
}

pub fn mal_eval(a: std.mem.Allocator, env: *MalData, root: *MalData) !*MalData {
    var result = try MalData.init(a);

    switch(root.*) {
        .list => |l| {
            if (l.items.len >= 1) {
                var r = try eval_ast(a, env, root);
                result = try (r.list.items[0].function)(a, r);
            } else {
                result = root;
            }
        },
        else => {
            result = try eval_ast(a, env, root);
        }
    }
    return result;
}

pub fn mal_print(stdout: anytype, root: *MalData) !void {
    try print_str(stdout, root);
}

pub fn mal_rep(stdin: anytype, stdout: anytype, a: std.mem.Allocator) !void {
    var root = try mal_read(stdin, a);
    defer root.deinit(a);

    var repl_env = try make_env(a);

    var r = try mal_eval(a, repl_env, root);
    try mal_print(stdout, r);
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const a = std.heap.page_allocator;

    while (true) {
        try stderr.print("> ", .{});
        try mal_rep(stdin, stdout, a);
    }
}
