const std = @import("std");

var buffer: [100]u8 = undefined;
var index: usize = 0;

fn writeToBuffer(context: *usize, bytes: []const u8) !usize {
    const i = context.*;
    const space_left = buffer.len - i;
    if (bytes.len > space_left) return error.BufferTooSmall;
    @memcpy(buffer[i..][0..bytes.len], bytes);
    context.* += bytes.len;
    return bytes.len;
}

pub fn main() !void {
    var writer = std.io.Writer(*usize, error{BufferTooSmall}, writeToBuffer){
        .context = &index,
    };

    try writer.writeAll("Hello");
    try writer.writeAll(", Zig!");

    std.debug.print("Buffer: {s}\n", .{buffer[0..index]});
}
