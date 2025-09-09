const std = @import("std");

pub fn main() !void {
    const json_text =
        \\{
        \\  "name": "Alice",
        \\  "age": 30,
        \\  "hobbies": ["reading", "coding"]
        \\}
    ;

    const gpa = std.heap.page_allocator;
    var parsed = try std.json.parse(std.json.Value, &std.json.ParseOptions{
        .allocator = gpa,
    }, json_text);
    defer parsed.deinit(gpa); // 重要：释放动态分配的内存！

    // 访问字段
    const name = parsed.object.get("name").?.string;
    const age = parsed.object.get("age").?.integer;
    const hobbies = parsed.object.get("hobbies").?.array;

    std.debug.print("Name: {s}\n", .{name});
    std.debug.print("Age: {d}\n", .{age});
    for (hobbies.items) |hobby| {
        std.debug.print("- {s}\n", .{hobby.string});
    }
}
