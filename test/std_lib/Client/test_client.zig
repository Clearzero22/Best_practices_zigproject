// const std = @import("std");

// pub fn main() !void {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer _ = gpa.deinit();
//     const allocator = gpa.allocator();

//     // 创建 HTTP 客户端
//     var client = std.http.Client{ .allocator = allocator };
//     defer client.deinit();

//     // 发送 GET 请求
//     const uri = try std.Uri.parse("https://httpbin.org/get");

//     var request = try client.open(.GET, uri, .{});
//     defer request.deinit();

//     // 发送请求
//     try request.start();
//     try request.wait();

//     // 处理响应
//     const response = request.response.?;
//     std.debug.print("Status: {}\n", .{response.head.status});
//     std.debug.print("Content-Type: {?s}\n", .{response.head.content_type});

//     // 读取响应体
//     var buf: [4096]u8 = undefined;
//     while (try response.reader(&buf)) |bytes| {
//         std.io.getStdOut().writeAll(bytes) catch break;
//     }
// }

const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 创建 HTTP 客户端
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    // 准备请求选项，必须包含 server_header_buffer
    var header_buffer: [4096]u8 = undefined;
    const uri = try std.Uri.parse("https://httpbin.org/get");

    var request = try client.open(.GET, uri, .{
        .server_header_buffer = &header_buffer,
    });
    defer request.deinit();

    // 发送请求
    try request.send();

    try request.finish();
    try request.wait();

    // 处理响应
    const response = request.response;
    std.debug.print("Status: {}\n", .{response.status});
    std.debug.print("Content-Type: {?s}\n", .{response.content_type});

    // 正确读取响应体的方式
    // 创建适合传输编码的读取器
    var body_reader = std.http.reader(response.transfer_encoding, response.stream, response.body_left);

    // 读取响应体内容
    var buf: [4096]u8 = undefined;
    while (true) {
        // 读取数据到缓冲区
        const n = try body_reader.read(&buf);
        if (n == 0) break; // 读取完毕

        // 输出到标准输出
        try std.io.getStdOut().writeAll(buf[0..n]);
    }
    std.debug.print("\n", .{});
}
