const std = @import("std");

const MalError = @import("error.zig").MalError;
const MalEnv = @import("env.zig").MalEnv;

pub const MalData = union(enum) {
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
    lambda: *Lambda,

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
            .lambda => |l| l.deinit(a),
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
            .lambda => |l| {
                var lambda = try Lambda.init(a, l.args, l.body, l.env.outer);
                result.* = MalData{
                    .lambda = lambda,
                };
            },
        }

        return result;
    }
};

pub const Lambda = struct {
    args: *MalData,
    body: *MalData,
    env: *MalEnv,

    const Self = @This();

    pub fn init(a: std.mem.Allocator, args: *MalData, body: *MalData, outer: ?*MalEnv) MalError!*Lambda{
        var result = try a.create(Lambda);
        var env = try MalEnv.init(a, outer);
        result.* = Lambda{
            .args = try args.copy(a),
            .body = try body.copy(a),
            .env = env,
        };

        return result;
    }

    pub fn deinit(self: *Self, a: std.mem.Allocator) void {
        self.args.deinit(a);
        self.body.deinit(a);
        self.env.deinit(a);
    }
};