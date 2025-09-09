const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 读取整个文件内容到内存
    const file_content = try std.fs.cwd().readFileAlloc(allocator, "io_test.zig", 1024 * 1024); // 最大 1MB
    defer allocator.free(file_content);

    std.debug.print("文件内容: {s}\n", .{file_content});
}
