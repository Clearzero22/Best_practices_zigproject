const std = @import("std");

std.io.Writer(comptime Context: type, comptime WriteError: type, comptime writeFn: fn(context:Context, bytes:[]const u8)WriteError!usize)
pub fn main() !void {
    const uri_str = "https://example.com/hello%20world?key=value%21";
    const uri = try std.Uri.parse(uri_str);

    // path 是 .percent_encoded（因为输入中已编码）
    const path_str = switch (uri.path) {
        .raw => |s| s, // 理论上不会发生（解析器会设为 percent_encoded）
        .percent_encoded => |s| s,
    };

    std.debug.print("Path: {s}\n", .{path_str}); // 输出: hello%20world
}
