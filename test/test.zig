const std = @import("std");

fn processBytes(ptr: [*]u8, len: usize) void {
    for (ptr[0..len]) |byte| {
        std.debug.print("byte[{d}] = \n", .{byte});
    }
}

fn callLater(callback: fn (*anyopaque) void, ctx: *anyopaque) void {
    // 模拟异步执行
    callback(ctx);
}

fn myCallback(ctx: *anyopaque) void {
    // 转回原始类型
    const data = @as(*i32, @ptrCast(ctx));
    std.debug.print("Callback got: {}\n", .{data.*});
}

pub fn main() void {
    var x: u32 = 0x12345678;

    // 显式声明目标类型
    const p: [*]u8 = @ptrCast(&x);

    std.debug.print("bytes: {x} {x} {x} {x}\n", .{
        p[0], p[1], p[2], p[3],
    });

    var data: [4]u32 = .{ 0x11223344, 0x55667788, 0x99AABBCC, 0xDDEEFF00 };

    // 直接在参数位置使用 @ptrCast —— 目标类型由函数签名推断
    processBytes(@ptrCast(&data), data.len * @sizeOf(u32));

    var x1: i32 = 42;

    // 转为不透明指针传递
    callLater(myCallback, @ptrCast(&x1));
}
