const std = @import("std");
const c = @cImport({
    @cInclude("stdlib.h");
});

pub fn main() void {
    // C malloc 返回 [*]u8（Zig 中对应 void*）
    const ptr = c.malloc(@sizeOf(i32)) orelse @panic("OOM");
    defer c.free(ptr);

    // 转成我们要用的类型
    const int_ptr = @as(*i32, @ptrCast(ptr));
    int_ptr.* = 12345;

    std.debug.print("Value: {}\n", .{int_ptr.*});
}
