const expect = @import("std").testing.expect;

const Data = extern struct { a: i32, b: u8, c: f32, d: bool, e: bool };

test "hmm" {
    const x = Data{
        .a = 10005,
        .b = 42,
        .c = -10.5,
        .d = false,
        .e = true,
    };
    const z = @as([*]const u8, @ptrCast(&x));

    try expect(@as(*const i32, @ptrCast(@alignCast(z))).* == 10005);
    try expect(@as(*const u8, @ptrCast(@alignCast(z + 4))).* == 42);
    try expect(@as(*const f32, @ptrCast(@alignCast(z + 8))).* == -10.5);
    try expect(@as(*const bool, @ptrCast(@alignCast(z + 12))).* == false);
    try expect(@as(*const bool, @ptrCast(@alignCast(z + 13))).* == true);
}
