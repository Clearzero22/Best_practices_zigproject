// Zig example of the use of the standard library HTTP client
// <https://ziglang.org/documentation/0.12.0/std/#std.http.Client> We
// retrieve JSON data from a network API. We are not very paranoid,
// more checks should be created.

const std = @import("std");

// The API we use
// const ref_url = "https://httpbin.org/get";

const ref_url = "https://www.baidu.com";

// Some values
const headers_max_size = 4096;
const body_max_size = 65536;

pub fn main() !void {
    const url = try std.Uri.parse(ref_url);

    // We need an allocator to create a std.http.Client
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    var client = std.http.Client{ .allocator = gpa };
    defer client.deinit();

    var hbuffer: [headers_max_size]u8 = undefined;
    const options = std.http.Client.RequestOptions{ .server_header_buffer = &hbuffer };

    // Call the API endpoint
    var request = try client.open(std.http.Method.GET, url, options);
    defer request.deinit();
    _ = try request.send();
    _ = try request.finish();
    _ = try request.wait();

    // Check the HTTP return code
    if (request.response.status != std.http.Status.ok) {
        return error.WrongStatusResponse;
    }

    // Read the body
    var bbuffer: [body_max_size]u8 = undefined;
    const hlength = request.response.parser.header_bytes_len;
    _ = try request.readAll(&bbuffer);
    const blength = request.response.content_length orelse return error.NoBodyLength; // We trust
    // the Content-Length returned by the server…

    // Display the result
    std.debug.print("{d} header bytes returned:\n{s}\n", .{ hlength, hbuffer[0..hlength] });
    // The response is in JSON so we should here add JSON parsing code.
    std.debug.print("{d} body bytes returned:\n{s}\n", .{ blength, bbuffer[0..blength] });
}
