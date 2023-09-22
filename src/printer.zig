const std = @import("std");

const MalData = @import("data.zig").MalData;
const MalError = @import("error.zig").MalError;

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
            try stdout.print("#<function>\n", .{});
        },
        .lambda => {
            try stdout.print("#<lambda>\n", .{});
        },
        .atom => {
            try stdout.print("#<atom>\n", .{});
        },
    }
}

pub fn new_string(a: std.mem.Allocator, str: std.ArrayList(u8)) MalError!*MalData {
    var result = try MalData.init(a);
    defer result.deinit(a);

    result.* = MalData{
        .string = std.ArrayList(u8).init(a),
    };

    for (str.items) |i| {
        try result.string.append(i);
    }

    return try result.copy(a);
}

pub fn pr_str(a: std.mem.Allocator, root: *MalData) MalError!*MalData {
    switch (root.*) {
        .number => |n| {
            var str = std.ArrayList(u8).init(a);
            var w = str.writer();
            try w.print("{}\n", .{n});
            
            return try new_string(a, str);
        },
        .symbol => |s| {
            var str = std.ArrayList(u8).init(a);
            var w = str.writer();
            try w.print("{s}\n", .{s.items});

            return try new_string(a, str);
        },
        .string => |s| {
            var str = std.ArrayList(u8).init(a);
            var w = str.writer();
            try w.print("{s}", .{s.items});

            return try new_string(a, str);
        },
        .list => |l| {
            var str = std.ArrayList(u8).init(a);
            for (l.items) |i| {
                var s = try pr_str(a, i);
                defer s.deinit(a);
                try str.appendSlice(s.string.items);
                try str.append(',');
            }

            return try new_string(a, str);
        },
        .vector => |v| {
            var str = std.ArrayList(u8).init(a);
            for (v.items) |i| {
                var s = try pr_str(a, i);
                defer s.deinit(a);
                try str.appendSlice(s.string.items);
                try str.append(',');
            }

            return try new_string(a, str);
        },
        .nil => {
            var str = std.ArrayList(u8).init(a);
            var w = str.writer();
            try w.print("nil\n", .{});

            return try new_string(a, str);
        },
        .True => {
            var str = std.ArrayList(u8).init(a);
            var w = str.writer();
            try w.print("True\n", .{});

            return try new_string(a, str);
        },
        .False => {
            var str = std.ArrayList(u8).init(a);
            var w = str.writer();
            try w.print("False\n", .{});

            return try new_string(a, str);
        },
        .hashmap => |h| {
            var str = std.ArrayList(u8).init(a);
            var w = str.writer();
            var i = h.iterator();
            while (i.next()) |v| {
                try w.print("#{s}: {}, ", .{v.key_ptr.*, v.value_ptr.*});
            }
            try w.print("\n", .{});

            return try new_string(a, str);
        },
        .function => {
            var str = std.ArrayList(u8).init(a);
            var w = str.writer();
            try w.print("#<function>\n", .{});

            return try new_string(a, str);
        },
        .lambda => {
            var str = std.ArrayList(u8).init(a);
            var w = str.writer();
            try w.print("#<lambda>\n", .{});

            return try new_string(a, str);
        },
        .atom => {
            var str = std.ArrayList(u8).init(a);
            var w = str.writer();
            try w.print("#<atom>\n", .{});

            return try new_string(a, str);
        },
    }
}