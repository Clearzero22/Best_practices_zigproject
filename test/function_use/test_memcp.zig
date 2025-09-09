const std = @import("std");

pub fn main() void {
    var dest: [10]u8 = undefined;
    const source = "Hello" ++ [1]u8{0}; // "Hello\0"，6字节

    @memcpy(&dest, source[0..].ptr); // 复制6字节

    std.debug.print("dest = {s}\n", .{dest[0..6]});
    // 输出：dest = Hello
}
