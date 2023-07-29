const std = @import("std");

const MalData = @import("data.zig").MalData;
const Lambda = @import("data.zig").Lambda;
const MalError = @import("error.zig").MalError;
const MalEnv = @import("env.zig").MalEnv;
const Core = @import("core.zig");
const Reader = @import("reader.zig");
const Printer = @import("printer.zig");

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
    defer result.deinit(a);

    return try result.copy(a);
}

pub fn eval_do(a: std.mem.Allocator, env: *MalEnv, root: *MalData) MalError!*MalData {
    var result: *MalData = undefined;
    defer result.deinit(a);
    if (root.list.items[1].* == MalData.list) {
        for (root.list.items) |i| {
            result = try eval_ast(a, env, i);
        }
    } else {
        return MalError.SyntaxError;
    }

    return try result.copy(a);
}

pub fn eval_if(a: std.mem.Allocator, env: *MalEnv, root: *MalData) MalError!*MalData {
    var result: *MalData = undefined;
    defer result.deinit(a);
    if (root.list.items.len >= 3) {
        var judge = try mal_eval(a, env, root.list.items[1]);
        defer judge.deinit(a);
        switch(judge.*) {
            .nil, .False => {
                if (root.list.items.len >= 4) {
                    result = try mal_eval(a, env, root.list.items[3]);
                } else {
                    result.* = MalData{
                        .nil = undefined,
                    };
                }
            },
            else => {
                result = try mal_eval(a, env, root.list.items[2]);
            },
        }
    } else {
        return MalError.SyntaxError;
    }

    return try result.copy(a);
}

pub fn eval_lambda(a: std.mem.Allocator, env: *MalEnv, root: *MalData) MalError!*MalData {
    if (root.list.items.len >= 3) {
        var result = try MalData.init(a);
        defer result.deinit(a);

        var l = try Lambda.init(a, root.list.items[1], root.list.items[2], env);
        result.* = MalData{
            .lambda = l,
        };
        return try result.copy(a);
    } else {
        return MalError.LambdaDefineError;
    }
}

pub fn apply_function(a: std.mem.Allocator, root: *MalData) MalError!*MalData {
    var result: *MalData = undefined;
    defer result.deinit(a);
    switch(root.list.items[0].*) {
        .function => |f| {
            result = try (f)(a, root);
        },
        .lambda => |l| {
            var d_args_len = l.args.list.items.len;
            var args_len = root.list.items.len - 1;
            if (d_args_len == args_len) {
                var i:u32 = 0;
                while (i < d_args_len) {
                    var value = try root.list.items[i+1].copy(a);
                    try l.env.set(l.args.list.items[i].symbol.items, value);
                    i = i + 1;
                }
            } else {
                return MalError.LambdaArgsError;
            }
            result = try mal_eval(a, l.env, l.body);
        },
        else => return MalError.ApplyFunctionError,
    }

    return try result.copy(a);
}

pub fn mal_read(stdin: anytype, a: std.mem.Allocator) !*MalData {
    var buf = Reader.mal_reader(stdin);
    var root = try Reader.read_atom(a, &buf);

    return root;
}

pub fn mal_eval(a: std.mem.Allocator, env: *MalEnv, root: *MalData) MalError!*MalData {
    var result = try MalData.init(a);

    switch(root.*) {
        .list => |l| {
            if (l.items.len >= 1) {
                var symbol: []const u8 = undefined;
                if (l.items[0].* == MalData.symbol) {
                    symbol = l.items[0].symbol.items;
                } else {
                    symbol = "";
                }
                if (std.mem.eql(u8, symbol, "def!")) {
                    result = try eval_def(a, env, root);
                } else if (std.mem.eql(u8, symbol, "let*")) {
                    result = try eval_let(a, env, root);
                } else if (std.mem.eql(u8, symbol, "do")) {
                    result = try eval_do(a, env, root);
                } else if (std.mem.eql(u8, symbol, "if")) {
                    result = try eval_if(a, env, root);
                } else if (std.mem.eql(u8, symbol, "lambda")) {
                    result = try eval_lambda(a, env, root);
                } else {
                    var r = try eval_ast(a, env, root);
                    result = try apply_function(a, r);
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
    try Printer.print_str(stdout, root);
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
    var repl_env = try Core.make_env(a);

    while (true) {
        try stderr.print("> ", .{});
        try mal_rep(stdin, stdout, a, repl_env);
    }
}
