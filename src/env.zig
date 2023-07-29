const std = @import("std");

const MalData = @import("data.zig").MalData;
const Lambda = @import("data.zig").Lambda;
const MalError = @import("error.zig").MalError;

pub const MalEnv = struct {
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