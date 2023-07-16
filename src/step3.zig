const std = @import("std");

const MalError = error{
    SyntaxError,
    ParseError,
    PrintError,
    HashMapError,
    FuncArgError,
    EnvFindError,
    EnvDefineError,
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

    pub fn copy(self: *Self, a: std.mem.Allocator) MalError!*MalData {
        var result = try MalData.init(a);

        switch(self.*) {
            .number => |n| {
                result.* = MalData{
                    .number = n,
                };
            },
            .symbol => |s| {
                result.* = MalData{
                    .symbol = std.ArrayList(u8).init(a),
                };
                for (s.items) |i| {
                    try result.symbol.append(i);
                }
            },
            .list => |l| {
                result.* = MalData{
                    .list = std.ArrayList(*MalData).init(a),
                };
                for (l.items) |i| {
                    var r = try i.copy(a);
                    try result.list.append(r);
                }
            },
            .vector => |v| {
                result.* = MalData{
                    .vector = std.ArrayList(*MalData).init(a),
                };
                for (v.items) |i| {
                    var r = try i.copy(a);
                    try result.vector.append(r);
                }
            },
            .string => |s| {
                result.* = MalData{
                    .string = std.ArrayList(u8).init(a),
                };
                for (s.items) |i| {
                    try result.string.append(i);
                }
            },
            .nil => {
                result.* = MalData{
                    .nil = undefined,
                };
            },
            .True => {
                result.* = MalData{
                    .True = undefined,
                };
            },
            .False => {
                result.* = MalData{
                    .False = undefined,
                };
            },
            .hashmap => |h| {
                result.* = MalData{
                    .hashmap = std.StringArrayHashMap(*MalData).init(a),
                };

                var iterator = h.iterator();
                var n = iterator.next();
                while (true) {
                    const pair = n orelse break;
                    var r = try pair.value_ptr.*.copy(a);
                    try result.hashmap.put(pair.key_ptr.*, r);
                    n = iterator.next();
                }
            },
            .function => {
                result.* = MalData{
                    .function = self.function,
                };
            },
        }

        return result;
    }
};

const MalEnv = struct {
    env: *MalData,
    outer: ?*MalEnv,

    const Self = @This();

    pub fn init(a: std.mem.Allocator, outer: ?*MalEnv) !*Self{
        var env = try MalData.init(a);
        env.* = MalData{
            .hashmap = std.StringArrayHashMap(*MalData).init(a),
        };

        var result = try a.create(MalEnv);
        result.* = MalEnv{
            .env = env,
            .outer = outer,
        };

        return result;
    }

    pub fn deinit(self: *Self, a: std.mem.Allocator) void {
        self.env.deinit(a);
    }

    pub fn set(self: *Self, symbol: []const u8, value: *MalData) MalError!void {
        try self.env.hashmap.put(symbol, value);
    }

    pub fn get(self: *Self, symbol: []const u8) MalError!*MalData {
        if (self.env.hashmap.get(symbol)) |v| {
            return v;
        } else {
            if (self.outer != null) {
                return try self.outer.?.get(symbol);
            } else {
                return MalError.EnvFindError;
            }
            return MalError.EnvFindError;
        }
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

fn make_env(a: std.mem.Allocator) MalError!*MalEnv {
    var env = try MalEnv.init(a, null);

    var add = try MalData.init(a);
    add.* = MalData{
        .function = &mal_add,
    };
    try env.set("+", add);

    var sub = try MalData.init(a);
    sub.* = MalData{
        .function = &mal_sub,
    };
    try env.set("-", sub);

    var mul = try MalData.init(a);
    mul.* = MalData{
        .function = &mal_mul,
    };
    try env.set("*", mul);

    var div = try MalData.init(a);
    div.* = MalData{
        .function = &mal_div,
    };
    try env.set("/", div);

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
            'a'...'z', 'A'...'Z', '0'...'9', '+', '-', '*', '/', '_', '!' => |v| try t.append(v),
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

pub fn eval_ast(a: std.mem.Allocator, env: *MalEnv, arg: *MalData) MalError!*MalData {
    var result = try MalData.init(a);

    switch(arg.*) {
        .symbol => |s| {
            result = try env.get(s.items);
        },
        .list => |l| {
            result.* = MalData{
                .list = std.ArrayList(*MalData).init(a),
            };
            for (l.items) |i| {
                var r = try mal_eval(a, env, i);
                try result.list.append(r);
            }
        },
        .vector => |v| {
            result.* = MalData{
                .vector = std.ArrayList(*MalData).init(a),
            };
            for (v.items) |i| {
                var r = try mal_eval(a, env, i);
                try result.vector.append(r);
            }
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
        },
        else => {
            result = arg;
        },
    }

    return result;
}

pub fn eval_def(a: std.mem.Allocator, env: *MalEnv, root: *MalData) MalError!*MalData {
    var symbol = root.list.items[1];
    var value = try mal_eval(a, env, root.list.items[2]);
    var v = try value.copy(a);

    if (symbol.* == MalData.symbol) {
        try env.set(symbol.symbol.items, v);
    } else {
        return MalError.EnvDefineError;
    }

    return value;
}

pub fn eval_let(a: std.mem.Allocator, env: *MalEnv, root: *MalData) MalError!*MalData {
    var new_env = try MalEnv.init(a, env);
    defer new_env.deinit(a);

    if (root.list.items[1].* == MalData.list) {
        var binding_list = root.list.items[1];

        var flag: i64 = 0;
        var symbol: *MalData = undefined;
        for (binding_list.list.items) |bind| {
            if (flag == 0) {
                flag = 1;
                symbol = bind;
            } else {
                try new_env.set(symbol.symbol.items, bind);
                flag = 0;
            }
        }
    } else {
        return MalError.EnvDefineError;
    }

    var result = try mal_eval(a, new_env, root.list.items[2]);

    return try result.copy(a);
}

pub fn mal_read(stdin: anytype, a: std.mem.Allocator) !*MalData {
    var buf = mal_reader(stdin);
    var root = try read_atom(a, &buf);

    return root;
}

pub fn mal_eval(a: std.mem.Allocator, env: *MalEnv, root: *MalData) MalError!*MalData {
    var result = try MalData.init(a);

    switch(root.*) {
        .list => |l| {
            if (l.items.len >= 1) {
                if (std.mem.eql(u8, l.items[0].symbol.items, "def!")) {
                    result = try eval_def(a, env, root);
                } else if (std.mem.eql(u8, l.items[0].symbol.items, "let*")) {
                    result = try eval_let(a, env, root);
                } else {
                    var r = try eval_ast(a, env, root);
                    result = try (r.list.items[0].function)(a, r);
                }
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

pub fn mal_rep(stdin: anytype, stdout: anytype, a: std.mem.Allocator, env: *MalEnv) !void {
    var root = try mal_read(stdin, a);

    var r = try mal_eval(a, env, root);
    defer r.deinit(a);

    try mal_print(stdout, r);
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const a = std.heap.page_allocator;
    var repl_env = try make_env(a);

    while (true) {
        try stderr.print("> ", .{});
        try mal_rep(stdin, stdout, a, repl_env);
    }
}
