const std = @import("std");

const MalData = @import("data.zig").MalData;
const MalError = @import("error.zig").MalError;
const MalEnv = @import("env.zig").MalEnv;
const Reader = @import("reader.zig");
const Printer = @import("printer.zig");
const Atom = @import("data.zig").Atom;
const Utils = @import("utils.zig");

const read_from_string = @import("step6.zig").read_from_string;
const apply_function = @import("step6.zig").apply_function;

const FuncPair = struct {
    name: [] const u8,
    func: *const fn (a: std.mem.Allocator, args: *MalData) MalError!*MalData,
};

pub const gamma = [_] FuncPair{
    FuncPair{ .name = "+", .func = &mal_add},
    FuncPair{ .name = "-", .func = &mal_sub},
    FuncPair{ .name = "*", .func = &mal_mul},
    FuncPair{ .name = "/", .func = &mal_div},
    FuncPair{ .name = "=", .func = &mal_equal},
    FuncPair{ .name = "<", .func = &mal_lt},
    FuncPair{ .name = ">", .func = &mal_gt},
    FuncPair{ .name = "<=", .func = &mal_le},
    FuncPair{ .name = ">=", .func = &mal_ge},
    FuncPair{ .name = "prn", .func = &mal_prn},
    FuncPair{ .name = "str", .func = &mal_str},
    FuncPair{ .name = "read-string", .func = &mal_read_string},
    FuncPair{ .name = "slurp", .func = &mal_slurp},
    FuncPair{ .name = "list", .func = &mal_list},
    FuncPair{ .name = "list?", .func = &mal_is_list},
    FuncPair{ .name = "empty?", .func = &mal_is_empty},
    FuncPair{ .name = "count", .func = &mal_count},
    FuncPair{ .name = "atom", .func = &mal_make_atom},
    FuncPair{ .name = "atom?", .func = &mal_is_atom},
    FuncPair{ .name = "deref", .func = &mal_deref},
    FuncPair{ .name = "reset!", .func = &mal_reset},
    FuncPair{ .name = "swap!", .func = &mal_swap},
    FuncPair{ .name = "cons", .func = &mal_cons},
    FuncPair{ .name = "concat", .func = &mal_concat},
};

pub fn make_env(a: std.mem.Allocator) MalError!*MalEnv {
    var env = try MalEnv.init(a, null);

    for (gamma) |g| {
        var f = try MalData.init(a);
        f.* = MalData{
            .function = g.func,
        };
        try env.set(g.name, f);
    }

    return env;
}

fn as_number(arg: *MalData) MalError!i64 {
    if (arg.* == MalData.number) {
        return arg.number;
    } else {
        return MalError.DataTypeError;
    }
}

fn arg_check(arg: *MalData) MalError!*MalData {
    if (arg.* == MalData.list) {
        if (arg.list.items.len > 1) {
            return arg;
        } else {
            return MalError.FuncArgError;
        }
    } else {
        return MalError.FuncArgError;
    }
}

fn mal_add(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    if (args.* == MalData.list) {
        var l = args.list;
        if (l.items.len == 3) {
            var result = try MalData.init(a);
            defer result.deinit(a);
            result.* = MalData{
                .number = try as_number(l.items[1]) + try as_number(l.items[2]),
            };

            return try result.copy(a);
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
            var result = try MalData.init(a);
            defer result.deinit(a);
            result.* = MalData{
                .number = try as_number(l.items[1]) - try as_number(l.items[2]),
            };

            return try result.copy(a);
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
            var result = try MalData.init(a);
            defer result.deinit(a);
            result.* = MalData{
                .number = try as_number(l.items[1]) * try as_number(l.items[2]),
            };

            return try result.copy(a);
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
            var result = try MalData.init(a);
            defer result.deinit(a);
            result.* = MalData{
                .number = @divTrunc(try as_number(l.items[1]), try as_number(l.items[2])),
            };

            return try result.copy(a);
        } else {
            return MalError.FuncArgError;
        }
    } else {
        return MalError.FuncArgError;
    }
}

fn mal_equal(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;
    if (l.items.len == 3) {
        var result = try MalData.init(a);
        defer result.deinit(a);
        if (try as_number(l.items[1]) == try as_number(l.items[2])) {
            result.* = MalData{
                .True = undefined,
            };
        } else {
            result.* = MalData{
                .False = undefined,
            };
        }

        return try result.copy(a);
    } else {
        return MalError.FuncArgError;
    }
}

fn mal_lt(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;
    if (l.items.len == 3) {
        var result = try MalData.init(a);
        defer result.deinit(a);
        if (try as_number(l.items[1]) < try as_number(l.items[2])) {
            result.* = MalData {
                .True = undefined,
            };
        } else {
            result.* = MalData{
                .False = undefined,
            };
        }

        return try result.copy(a);
    } else {
        return MalError.FuncArgError;
    }
}

fn mal_gt(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;
    if (l.items.len == 3) {
        var result = try MalData.init(a);
        defer result.deinit(a);
        if (try as_number(l.items[1]) > try as_number(l.items[2])) {
            result.* = MalData {
                .True = undefined,
            };
        } else {
            result.* = MalData{
                .False = undefined,
            };
        }

        return try result.copy(a);
    } else {
        return MalError.FuncArgError;
    }
}

fn mal_le(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;
    if (l.items.len == 3) {
        var result = try MalData.init(a);
        defer result.deinit(a);
        if (try as_number(l.items[1]) <= try as_number(l.items[2])) {
            result.* = MalData {
                .True = undefined,
            };
        } else {
            result.* = MalData{
                .False = undefined,
            };
        }

        return try result.copy(a);
    } else {
        return MalError.FuncArgError;
    }
}

fn mal_ge(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;
    if (l.items.len == 3) {
        var result = try MalData.init(a);
        defer result.deinit(a);
        if (try as_number(l.items[1]) >= try as_number(l.items[2])) {
            result.* = MalData {
                .True = undefined,
            };
        } else {
            result.* = MalData{
                .False = undefined,
            };
        }

        return try result.copy(a);
    } else {
        return MalError.FuncArgError;
    }
}

fn mal_prn(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;
    const stdout = std.io.getStdOut().writer();

    try Printer.print_str(stdout, l.items[1]);

    var result = try MalData.init(a);
    defer result.deinit(a);

    result.* = MalData{
        .nil = undefined,
    };

    return try result.copy(a);
}

fn mal_str(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    
    var i: u32 = 1;
    var str = std.ArrayList(u8).init(a);

    while(i < arg_list.list.items.len) {
        var s = try Printer.pr_str(a, arg_list.list.items[i]);
        try str.appendSlice(s.string.items);
        i = i + 1;
    }
    
    return try Printer.new_string(a, str);
}

fn mal_read_string(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);

    var arg = arg_list.list.items[1];
    if (arg.* == MalData.string) {
        return try read_from_string(a, arg.string.items);
    } else {
        return MalError.FuncArgError;
    }
}

fn mal_slurp(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);

    var arg = arg_list.list.items[1];
    if (arg.* == MalData.string) {
        const s = try std.fs.cwd().readFileAlloc(a, arg.string.items, 512); //catch return MalError.FileReadError;
        defer a.free(s);

        var str = std.ArrayList(u8).init(a);
        
        for (s) |i| {
            try str.append(i);
        }

        return try Printer.new_string(a, str);
    } else {
        return MalError.FuncArgError;
    }
}

fn mal_list(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;
    var i: u32 = 1;
    var result = try MalData.init(a);
    defer result.deinit(a);

    result.* = MalData{
        .list = std.ArrayList(*MalData).init(a),
    };

    while (i < l.items.len) {
        try result.list.append(l.items[i]);
        i = i + 1;
    }

    return try result.copy(a);
}

fn mal_is_list(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;

    var result = try MalData.init(a);
    defer result.deinit(a);

    if (l.items[1].* == MalData.list) {
        result.* = MalData{
            .True = undefined,
        };
    } else {
        result.* = MalData{
            .False = undefined,
        };
    }

    return try result.copy(a);
}

fn mal_is_empty(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;

    var result = try MalData.init(a);
    defer result.deinit(a);
    if (l.items[1].* == MalData.list) {
        if (l.items[1].list.items.len > 0) {
            result.* = MalData{
                .True = undefined,
            };
        } else {
         result.* = MalData{
                .False = undefined,
            };
        }
    } else {
        return MalError.FuncArgError;
    }
        
    return try result.copy(a);
}

fn mal_count(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;

    var result = try MalData.init(a);
    defer result.deinit(a);
    if (l.items[1].* == MalData.list) {
        result.* = MalData{
            .number = @intCast(i64, l.items[1].list.items.len),
        };
        return try result.copy(a);
    } else {
        return MalError.FuncArgError;
    }
}

fn mal_make_atom(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;

    var result = try MalData.init(a);
    defer result.deinit(a);

    var new_atom = try Atom.init(a, l.items[1]);
    new_atom.ref_count += 1;
    
    result.* = MalData{
        .atom = new_atom,
    };

    return result.copy(a);
}

fn mal_is_atom(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;

    var result = try MalData.init(a);
    defer result.deinit(a);

    if (l.items[1].* == MalData.atom) {
        result.* = MalData{
            .True = undefined,
        };
    } else {
        result.* = MalData{
            .False = undefined,
        };
    }

    return result.copy(a);
}

fn mal_deref(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    const stdout = std.io.getStdOut().writer();
    var arg_list = try arg_check(args);
    var l = arg_list.list;

    if (l.items[1].* == MalData.atom) {
        try stdout.print("{}\n", .{l.items[1].atom.atom.*});
        return try l.items[1].atom.atom.*.copy(a);
    } else {
        return MalError.AtomDefineError;
    }
}

fn mal_reset(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;

    if (l.items.len >= 2) {
        if (l.items[1].* == MalData.atom) {
            var new_atom = try Atom.init(a, l.items[2]);
            l.items[1].atom.ref_count -= 1; 
            l.items[1].atom.atom.*.deinit(a);
            l.items[1].* = MalData{
                .atom = new_atom,
            };

            return try l.items[2].copy(a);
        } else {
            return MalError.FuncArgError;
        }
    } else {
        return MalError.FuncArgError;
    }
}

fn mal_swap(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;

    if (l.items.len >= 2) {
        if (l.items[1].* == MalData.atom) {
            if (l.items[2].* == MalData.lambda) {
                var new_arg = try MalData.init(a);
                defer new_arg.deinit(a);

                new_arg.* = MalData{
                    .list = std.ArrayList(*MalData).init(a),
                };
                try new_arg.list.append(try l.items[2].copy(a));
                try new_arg.list.append(try mal_deref(a, l.items[1]));

                var i: u32 = 2;
                while(i < l.items.len) {
                    try new_arg.list.append(try l.items[i].copy(a));
                    i = i + 1;
                }

                var new_atom = try Atom.init(a, try apply_function(a, new_arg));

                var result = try MalData.init(a);
                defer result.deinit(a);

                result.* = MalData{
                    .atom = new_atom,
                };

                return try result.copy(a);
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

fn mal_cons(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;

    if (l.items.len >= 3) {
        if (l.items[1].* == MalData.string) {
            if (l.items[2].* == MalData.list) {
                var result = try MalData.init(a);
                defer result.deinit(a);

                var ll = l.items[2].list;
                result.* = MalData{
                    .list = std.ArrayList(*MalData).init(a),
                };
                for (ll.items) |i| {
                    var str = try Utils.malstr_concat(a, l.items[1], i);
                    try result.list.append(str);
                }

                return try result.copy(a);
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

fn mal_concat(a: std.mem.Allocator, args: *MalData) MalError!*MalData {
    var arg_list = try arg_check(args);
    var l = arg_list.list;

    if (l.items[1].* == MalData.list) {
        var result = try Utils.mallist_concat(a, l.items[1]);

        return result;
    } else {
        return MalError.FuncArgError;
    }
}