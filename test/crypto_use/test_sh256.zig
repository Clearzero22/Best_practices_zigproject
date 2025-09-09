const std = @import("std");

pub fn main() !void {
    const input = "Hello, Zig!";
    var hash: [32]u8 = undefined; // SHA-256 输出 32 字节

    std.crypto.hash.sha2.Sha256.hash(input, &hash, .{});

    std.debug.print("SHA-256: {x}\n", .{hash});
    // 输出: 66a... (64位十六进制)
}
