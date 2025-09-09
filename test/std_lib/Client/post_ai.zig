const std = @import("std");

pub fn main() !void {
    // 获取标准输出写入器（在运行时而非编译时）
    const writer = std.io.getStdOut().writer();

    // 初始化内存分配器
    const alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    const allocator = arena.allocator();
    defer arena.deinit(); // 程序结束时自动释放所有分配的内存

    // 创建HTTP客户端
    var client = std.http.Client{
        .allocator = allocator,
    };

    // 设置请求头，包含Content-Type和Authorization
    const api_key = "be5a32bbe3fea8c0029f8ded518a0eb9.V0YowoDPfTVP1hl9"; // 请替换为您的实际API密钥
    const auth_header = try std.fmt.allocPrint(allocator, "Bearer {s}", .{api_key});
    const headers = &[_]std.http.Header{
        .{ .name = "Content-Type", .value = "application/json" },
        .{ .name = "Authorization", .value = auth_header },
    };

    // 构建请求体JSON
    const request_body =
        \\{
        \\    "model": "glm-4.5",
        \\    "messages": [
        \\        {
        \\            "role": "system",
        \\            "content": "你是一个有用的AI助手。"
        \\        },
        \\        {
        \\            "role": "user",
        \\            "content": "你好，请介绍一下自己。"
        \\        }
        \\    ],
        \\    "temperature": 0.6,
        \\    "stream": true
        \\}
    ;

    // 发送POST请求并获取响应
    const response = try post("https://open.bigmodel.cn/api/paas/v4/chat/completions", headers, request_body, &client, allocator, writer // 将writer作为参数传递
    );

    // 打印完整响应
    try writer.print("\n完整响应:\n{s}\n", .{response.items});
}

// 发送HTTP POST请求的函数（添加writer参数）
fn post(
    url: []const u8,
    headers: []const std.http.Header,
    payload: []const u8,
    client: *std.http.Client,
    allocator: std.mem.Allocator,
    writer: anytype, // 接受任意类型的writer
) !std.ArrayList(u8) {
    try writer.print("\nURL: {s} POST\n", .{url});
    try writer.print("请求体: {s}\n", .{payload});

    // 初始化响应体存储
    var response_body = std.ArrayList(u8).init(allocator);

    try writer.print("发送请求...\n", .{});
    const response = try client.fetch(.{
        .method = .POST,
        .location = .{ .url = url },
        .extra_headers = headers,
        .response_storage = .{ .dynamic = &response_body },
        .payload = payload, // 设置POST请求的 payload
    });

    try writer.print("响应状态码: {d}\n", .{response.status});
    try writer.print("响应体长度: {d} 字节\n", .{response_body.items.len});

    return response_body;
}
