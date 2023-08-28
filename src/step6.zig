const std = @import("std");

const MalData = @import("data.zig").MalData;
const Lambda = @import("data.zig").Lambda;
const MalError = @import("error.zig").MalError;
const MalEnv = @import("env.zig").MalEnv;
const Core = @import("core.zig");
const Reader = @import("reader.zig");
const Printer = @import("printer.zig");
const Utils = @import("utils.zig");

var eta: *MalEnv = undefined;

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

pub fn eval_let(a: std.mem.Allocator, env: **MalEnv, root: **MalData) MalError!void {
    const e = env.*;
    const r = root.*;

    var new_env = try MalEnv.init(a, e);

    if (r.list.items[1].* == MalData.list) {
        var binding_list = r.list.items[1];

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

    env.* = new_env;
    root.* = try r.list.items[2].copy(a);
}

pub fn eval_do(a: std.mem.Allocator, env: **MalEnv, root: **MalData) MalError!void {
    var r = root.*;
    var e = env.*;

    root.* = r.list.pop();
    _ = r.list.orderedRemove(0);
    _ = try eval_ast(a, e, try r.copy(a));
    r.deinit(a);
}

pub fn eval_if(a: std.mem.Allocator, env: **MalEnv, root: **MalData) MalError!void {
    var r = root.*;
    var e = env.*;

    if (r.list.items.len >= 3) {
        var judge = try mal_eval(a, e, r.list.items[1]);
        defer judge.deinit(a);
        switch(judge.*) {
            .nil, .False => {
                if (r.list.items.len >= 4) {
                    root.* = r.list.items[3];
                } else {
                    root.*.* = MalData{
                        .nil = undefined,
                    };
                }
            },
            else => {
                root.* = r.list.items[2];
            },
        }
    } else {
        return MalError.SyntaxError;
    }
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
    switch(root.list.items[0].*) {
         .function => |f| {
            var result = try (f)(a, root);
            return result;
        },
        .lambda => |l| {
            var d_args_len = l.args.list.items.len;
            var args_len = root.list.items.len - 1;
            var new_env = try l.env.copy(a);
            defer new_env.deinit(a);
            if (d_args_len == args_len) {
                var i:u32 = 0;
                while (i < d_args_len) {
                    var value = try root.list.items[i+1].copy(a);
                    try new_env.set(l.args.list.items[i].symbol.items, value);
                    i = i + 1;
                }
            } else {
                return MalError.LambdaArgsError;
            }
            var result = try mal_eval(a, new_env, l.body);
            return result;
        },
        else => return MalError.ApplyFunctionError,
    }
}

pub fn mal_read(stdin: anytype, a: std.mem.Allocator) !*MalData {
    var buf = Reader.mal_reader(stdin);
    var root = try Reader.read_atom(a, &buf);

    return root;
}

pub fn read_from_string(a: std.mem.Allocator, str: [] const u8) !*MalData {
    var fbs = std.io.fixedBufferStream(str);
    var buf = Reader.mal_reader(fbs.reader());
    var root = try Reader.read_atom(a, &buf);

    return root;
}

pub fn mal_eval(a: std.mem.Allocator, env: *MalEnv, root: *MalData) MalError!*MalData {
    var current_env = env;
    var current_root = root;

    while(true) {
        switch(current_root.*) {
            .list => |l| {
                if (l.items.len >= 1) {
                    var symbol: []const u8 = undefined;
                    if (l.items[0].* == MalData.symbol) {
                        symbol = l.items[0].symbol.items;
                    } else {
                        symbol = "";
                    }
                    if (std.mem.eql(u8, symbol, "def!")) {
                        return try eval_def(a, current_env, current_root);
                    } else if (std.mem.eql(u8, symbol, "let*")) {
                        try eval_let(a, &current_env, &current_root);
                        continue;
                    } else if (std.mem.eql(u8, symbol, "do")) {
                        try eval_do(a, &current_env, &current_root);
                        continue;
                    } else if (std.mem.eql(u8, symbol, "if")) {
                        try eval_if(a, &current_env, &current_root);
                        continue;
                    } else if (std.mem.eql(u8, symbol, "lambda")) {
                        return try eval_lambda(a, current_env, current_root);
                    } else {
                        var r = try eval_ast(a, current_env, current_root);
                        var result = try apply_function(a, r);
                        return result;
                    }
                } else {
                    return current_root;
                }
            },
            else => {
                return try eval_ast(a, current_env, current_root);
            },
        }
    }
}

pub fn fn_eval(a: std.mem.Allocator, root: *MalData) MalError!*MalData {
    if (root.* == MalData.list) {
        if (root.list.items.len == 2) {
            return try mal_eval(a, try eta.copy(a), try root.list.items[1].copy(a));
        } else {
            return MalError.FuncArgError;
        }
    } else {
        return MalError.FuncArgError;
    }
}

pub fn make_env(stdout: anytype, a: std.mem.Allocator) MalError!*MalEnv {
    var env = try MalEnv.init(a, null);

    for (Core.gamma) |g| {
        var f = try MalData.init(a);
        f.* = MalData{
            .function = g.func,
        };
        try env.set(g.name, f);
    }

    var eval_func = try MalData.init(a);
    eval_func.* = MalData{
        .function = &fn_eval,
    };
    try env.set("eval", eval_func);

    const load_file_string: [] const u8 = \\(def! load-file (lambda (f) (eval (read-string (str "(do " (slurp f) "\nnil)")))))
    ;
    try rep_from_string(stdout, a, env, load_file_string);
    try stdout.print("set env.. load-file\n", .{});

    return env;
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

pub fn rep_from_string(stdout: anytype, a: std.mem.Allocator, env: *MalEnv, str: [] const u8) !void {
    var root = try read_from_string(a, str);

    var r = try mal_eval(a, env, root);
    defer r.deinit(a);

    try mal_print(stdout, r);
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const a = std.heap.page_allocator;
    eta = try make_env(stdout, a);

    const args = try std.process.argsAlloc(a);
    if (args.len > 1) {
        if (args.len > 2) {
            var arg_list = try MalData.init(a);
            arg_list.* = MalData{
                .list = std.ArrayList(*MalData).init(a),
            };
            for (args[2..]) |arg| {
                var ar = try MalData.init(a);
                ar.* = MalData{
                    .string = std.ArrayList(u8).init(a),
                };
                var w = ar.string.writer();
                try w.print("{s}", .{arg});
                
                try arg_list.list.append(ar);
            }
            try eta.set("*ARGV*", arg_list);
        }

        const exe_str = try Utils.concat(a, try Utils.concat(a, "(load-file \"", args[1]), "\")");
        try rep_from_string(stdout, a, eta, exe_str);
        
        return;
    }

    while (true) {
        try stderr.print("> ", .{});
        try mal_rep(stdin, stdout, a, eta);
    }
}
