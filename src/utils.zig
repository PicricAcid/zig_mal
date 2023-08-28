const std = @import("std");

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