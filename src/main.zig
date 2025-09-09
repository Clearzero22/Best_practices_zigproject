//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const webui = @import("webui");

// 嵌入html文件
const html = @embedFile("index.html");

pub fn webserver() !void {
    // 初始化本地地址
    const address = try std.net.Address.parseIp4("0.0.0.0", 8080);
    var server = try std.net.StreamServer.init(.{});
    defer server.deinit();
    try server.listen(address);

    std.debug.print("Listening on http://0.0.0.0:8080\n", .{});

    while (true) {
        var connection = try server.accept();
        defer connection.stream.close();

        var buffer: [1024]u8 = undefined;
        const size = try connection.stream.read(&buffer);
        const request = buffer[0..size];

        std.debug.print("Received request:\n{s}\n", .{request});
        // 返回字符串响应
        const response =
            \\HTTP/1.1 200 OK\r\n
            \\Content-Type: text/html; charset=UTF-8\r\n
            \\Connection: close\r\n
            \\Content-Length: 48\r\n
            \\r\n
            \\<html><body><h1>Hello from Zig Server!</h1></body></html>
        ;

        _ = try connection.stream.write(response);
    }
}

pub fn main() !void {
    // 创建一个新的窗口
    var nwin = webui.newWindow();

    // Bind HTML elements with C functions
    // 绑定 C function
    _ = try nwin.bind("my_function_count", my_function_count);
    _ = try nwin.bind("my_function_exit", my_function_exit);

    // Show the window
    try nwin.show(html);
    // _ = nwin.showBrowser(html, .Chrome);

    // Wait until all windows get closed
    webui.wait();

    // Free all memory resources (Optional)
    webui.clean();
}

fn my_function_count(e: *webui.Event) void {
    // This function gets called every time the user clicks on "my_function_count"

    // Create a buffer to hold the response
    var response = std.mem.zeroes([64]u8);

    const win = e.getWindow();

    // Run JavaScript
    win.script("return GetCount();", 0, &response) catch {
        if (!win.isShown()) {
            std.debug.print("window closed\n", .{});
        } else {
            std.debug.print("js error:{s}\n", .{response});
        }
    };

    const res_buf = response[0..std.mem.len(@as([*:0]u8, @ptrCast(&response)))];

    // Get the count
    var tmp_count = std.fmt.parseInt(i32, res_buf, 10) catch |err| blk: {
        std.log.err("error is {}", .{err});
        break :blk -50;
    };

    // Increment
    tmp_count += 1;

    // Generate a JavaScript
    var js: [64]u8 = std.mem.zeroes([64]u8);
    const buf = std.fmt.bufPrint(&js, "SetCount({});", .{tmp_count}) catch unreachable;

    // convert to a Sentinel-Terminated slice
    const content: [:0]const u8 = js[0..buf.len :0];

    // Run JavaScript (Quick Way)
    win.run(content);
}

fn my_function_exit(_: *webui.Event) void {

    // Close all opened windows
    webui.exit();
}

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("Best_practices_zigproject_lib");
