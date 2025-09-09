const std = @import("std");
const builtin = @import("builtin");

test "@atomicStore basic functionality" {
    var value: i32 = 0;
    @atomicStore(i32, &value, 42, .monotonic);
    try std.testing.expect(value == 42);
}

test "@atomicStore with all supported types" {
    // bool
    var b: bool = false;
    @atomicStore(bool, &b, true, .monotonic);
    try std.testing.expect(b == true);

    // integer
    var i: u64 = 0;
    @atomicStore(u64, &i, 0xFFFFFFFFFFFFFFFF, .monotonic);
    try std.testing.expect(i == 0xFFFFFFFFFFFFFFFF);

    // float
    var f: f64 = 0.0;
    @atomicStore(f64, &f, 3.14159, .monotonic);
    try std.testing.expect(f == 3.14159);

    // enum
    const Color = enum { red, green, blue };
    var color: Color = .red;
    @atomicStore(Color, &color, .blue, .monotonic);
    try std.testing.expect(color == .blue);

    // packed struct
    const Flags = packed struct { a: bool, b: u2, c: u3 = 5 };
    var flags: Flags = .{ .a = false, .b = 0 };
    @atomicStore(Flags, &flags, Flags{ .a = true, .b = 3 }, .monotonic);
    try std.testing.expect(flags.a == true);
    try std.testing.expect(flags.b == 3);
    try std.testing.expect(flags.c == 5);

    // pointer
    var x: i32 = 42;
    var ptr: *i32 = undefined;
    @atomicStore(*i32, &ptr, &x, .monotonic);
    try std.testing.expect(ptr == &x);
    try std.testing.expect(ptr.* == 42);
}

test "@atomicStore with different memory orders" {
    var value: i32 = 0;

    inline for (.{ .monotonic, .release, .seq_cst }) |order| {
        @atomicStore(i32, &value, 100, order);
        try std.testing.expect(value == 100);
        value = 0; // reset for next iteration
    }
}
