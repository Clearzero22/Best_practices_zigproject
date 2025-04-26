//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const webui = @import("webui");
const html = @embedFile("index.html");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // // stdout is for the actual output of your application, for example if you
    // // are implementing gzip, then only the compressed bytes should be sent to
    // // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    // try stdout.print("Run `zig build test` to run the tests.\n", .{});

    // try bw.flush(); // Don't forget to flush!

    // Create Windows

    var nwin = webui.newWindow();

    // Bind HTML elements with C functions
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

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }

// test "use other module" {
//     try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
// }

// test "fuzz example" {
//     const Context = struct {
//         fn testOne(context: @This(), input: []const u8) anyerror!void {
//             _ = context;
//             // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
//             try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
//         }
//     };
//     try std.testing.fuzz(Context{}, Context.testOne, .{});
// }

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("Best_practices_zigproject_lib");
