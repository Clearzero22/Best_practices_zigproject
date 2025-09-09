const std = @import("std");

// 错误分析
// ctx 的类型是 *anyopaque，它是一个对齐要求为 1 字节的指针（最宽松的对齐）。
// 你想把它转成 *i32，而 *i32 要求指针对齐到 4 字节边界（在大多数平台上）。
// 使用 @ptrCast 直接提升对齐要求是不安全的，可能导致未定义行为（如崩溃或性能下降）。
// Zig 编译器拒绝这种隐式风险，要求你显式处理对齐问题。
// 解决方案 你需要使用 @alignCast 来显式断言目标指针是对齐的。

fn callLater(callback: fn (*anyopaque) void, ctx: *anyopaque) void {
    // 模拟异步调用
    callback(ctx);
}

fn myCallback(ctx: *anyopaque) void {
    // 转回原始类型
    const data = @as(*i32, @alignCast(@ptrCast(ctx)));

    std.debug.print("Callback got: {}\n", .{data.*});
}

// ✅ 使用泛型，避免 anyopaque
fn callLater1(comptime T: type, callback: fn (ctx: *T) void, ctx: *T) void {
    callback(ctx);
}

fn myCallback1(data: *i32) void {
    std.debug.print("Callback got: {}\n", .{data.*});
}

pub fn main() void {
    var x: i32 = 42;

    // 转为不透明指针传递
    callLater(myCallback, @ptrCast(&x));

    // 泛型使用
    callLater1(i32, myCallback1, &x); // 类型安全！无需强制转换
}
