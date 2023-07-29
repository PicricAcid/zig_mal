const std = @import("std");

const MalData = @import("data.zig").MalData;

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
    }
}