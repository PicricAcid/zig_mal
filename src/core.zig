const std = @import("std");

const MalData = @import("data.zig").MalData;
const MalError = @import("error.zig").MalError;
const MalEnv = @import("env.zig").MalEnv;
const Printer = @import("printer.zig");

const FuncPair = struct {
    name: [] const u8,
    func: *const fn (a: std.mem.Allocator, args: *MalData) MalError!*MalData,
};

const gamma = [_] FuncPair{
    FuncPair{ .name = "+", .func = &mal_add},
    FuncPair{ .name = "-", .func = &mal_sub},
    FuncPair{ .name = "*", .func = &mal_mul},
    FuncPair{ .name = "/", .func = &mal_div},
    FuncPair{ .name = "=", .func = &mal_equal},
    FuncPair{ .name = "<", .func = &mal_lt},
    FuncPair{ .name = ">", .func = &mal_gt},
    FuncPair{ .name = "<=", .func = &mal_le},
    FuncPair{ .name = ">=", .func = &mal_ge},
    FuncPair{ .name = "list", .func = &mal_list},
    FuncPair{ .name = "list?", .func = &mal_is_list},
    FuncPair{ .name = "empty?", .func = &mal_is_empty},
    FuncPair{ .name = "count", .func = &mal_count},
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