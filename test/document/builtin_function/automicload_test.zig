const std = @import("std");
const builtin = @import("builtin");

// ✅ 这个测试验证了 @atomicLoad 能正确读取值。
// pub const AtomicOrder = enum {
//     monotonic,  // 最弱，仅保证原子性
//     acquire,    // 获取语义，禁止后续读写重排到前面
//     release,    // 释放语义，禁止前面读写重排到后面
//     acq_rel,    // acquire + release
//     seq_cst,    // 最强，全局顺序一致
// };

test "@atomicLoad basic usage" {
    var value: i32 = 42;
    const loaded = @atomicLoad(i32, &value, .monotonic);
    try std.testing.expect(loaded == 42);
}

// 🧪 更完整的测试：多线程 + 不同内存序

const AtomicOrder = builtin.AtomicOrder;

test "@atomicLoad with different memory orders" {
    var value: i32 = 100;

    // 测试所有合法的内存顺序
    inline for (.{ .monotonic, .acquire, .seq_cst }) |order| {
        const loaded = @atomicLoad(i32, &value, order);
        try std.testing.expect(loaded == 100);
    }
}

test "@atomicLoad in multi-threaded context (simulated)" {
    var shared_value: i32 = 0;
    const ptr = &shared_value;

    // 模拟：主线程写入
    @atomicStore(i32, ptr, 999, .release);

    // 模拟：工作线程读取
    const read_value = @atomicLoad(i32, ptr, .acquire);

    try std.testing.expect(read_value == 999);
}

test "@atomicLoad with supported types" {
    // bool
    var b: bool = true;
    try std.testing.expect(@atomicLoad(bool, &b, .monotonic) == true);

    // integer
    var i: u64 = 0x123456789ABCDEF0;
    try std.testing.expect(@atomicLoad(u64, &i, .monotonic) == 0x123456789ABCDEF0);

    // float
    var f: f64 = 3.14159;
    try std.testing.expect(@atomicLoad(f64, &f, .monotonic) == 3.14159);

    // enum
    const Color = enum { red, green, blue };
    var color: Color = .green;
    try std.testing.expect(@atomicLoad(Color, &color, .monotonic) == .green);

    // packed struct
    const Flags = packed struct { a: bool, b: u2, c: u3 = 5 };
    var flags: Flags = .{ .a = true, .b = 2 };
    const loaded_flags = @atomicLoad(Flags, &flags, .monotonic);
    try std.testing.expect(loaded_flags.a == true);
    try std.testing.expect(loaded_flags.b == 2);
    try std.testing.expect(loaded_flags.c == 5);

    // pointer
    var x: i32 = 42;
    var ptr: *i32 = &x;
    const loaded_ptr = @atomicLoad(*i32, &ptr, .monotonic);
    try std.testing.expect(loaded_ptr == &x);
    try std.testing.expect(loaded_ptr.* == 42);
}
