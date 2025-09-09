const std = @import("std");

test "get and print your thread" {
    var client: std.http.Client = .{
        .allocator = std.testing.allocator,
    };
    defer client.deinit();

    const stdout_writer_buf: []u8 = try std.testing.allocator.alloc(u8, 4096);
    defer std.testing.allocator.free(stdout_writer_buf);

    const stdout: std.fs.File = std.fs.File.stdout();
    // Release lock on stdout so we can print
    try stdout.lock(.none);

    var stdout_writer: std.Io.Writer = stdout.writer(stdout_writer_buf).interface;

    const fetch: std.http.Client.FetchResult = try client.fetch(.{
        // Print to stdout
        .response_writer = &stdout_writer,
        .location = .{
            .url = "https://ziggit.dev/t/get-html-page-content/11894",
        },
    });
    try std.testing.expect(fetch.status == .ok);
}
