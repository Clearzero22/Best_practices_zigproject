const std = @import("std");

fn defaultValue(comptime T: type) T {
    return switch (@typeInfo(T)) {
        .Bool => false,
        .Int, .Float => @as(T, 0),
        .Pointer => null,
        .Optional => null,
        .Struct => @as(T, undefined), // 或提供默认构造函数
        else => @compileError("Unsupported type for defaultValue: " ++ @typeName(T)),
    };
}

pub fn main() void {
    const a: i32 = defaultValue(i32); // → 0
    const b: f64 = defaultValue(f64); // → 0.0
    const c: bool = defaultValue(bool); // → false
    const d: ?u8 = defaultValue(?u8); // → null
    const e: *u8 = defaultValue(*u8); // → null

    std.debug.print("a={d}, b={d}, c={any}, d={any}, e={any}\n", .{ a, b, c, d, e });
}
