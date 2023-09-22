const std = @import("std");
const MalError = @import("error.zig").MalError;
const MalData = @import("data.zig").MalData;

pub fn concat(a: std.mem.Allocator, str1: []const u8, str2: []const u8) ![]const u8 {
    const size: usize = str1.len + str2.len;
    var i: u32 = 0;
    var pos: u32 = 0;
    const result = try a.alloc(u8, size);

    while (i < str1.len) {
        result[pos] = str1[i];
        i = i + 1;
        pos = pos + 1;
    }
    
    i = 0;
    while(i < str2.len) {
        result[pos] = str2[i];
        i = i + 1;
        pos = pos + 1;
    }

    return result;
}

pub fn malstr_concat(a: std.mem.Allocator, str1: *MalData, str2: *MalData) MalError!*MalData {
    if ((str1.* == MalData.string) and (str2.* == MalData.string)) {
        var result = try str1.copy(a);
        for (str2.string.items) |s| {
            try result.string.append(s);
        }

        return result;
    } else {
        return MalError.FuncArgError;
    }
}

pub fn mallist_concat(a: std.mem.Allocator, str_list: *MalData) MalError!*MalData {
    switch (str_list.*) {
        .list => |l| {
            if (l.items[0].* == MalData.string) {
                var result = try l.items[0].copy(a);

                for (l.items[1..]) |str| {
                    if (str.* == MalData.string) {
                        for (str.string.items) |s| {
                            try result.string.append(s);
                        }
                    } else {
                        return MalError.FuncArgError;
                    }
                }
                return result;
            } else {
                return MalError.FuncArgError;
            }
        },
        .vector => |v| {
            if (v.items[0].* == MalData.string) {
                var result = try v.items[0].copy(a);

                for (v.items[1..]) |str| {
                    if (str.* == MalData.string) {
                        for (str.string.items) |s| {
                            try result.string.append(s);
                        }
                    } else {
                        return MalError.FuncArgError;
                    }
                }
                return result;
            } else {
                return MalError.FuncArgError;
            }
        },
        else => return MalError.FuncArgError,
    }
}