const std = @import("std");

var counter: usize = 0;
var mutex = std.Thread.Mutex{};

fn worker(id: usize) void {
    for (0..1000) |_| {
        mutex.lock();
        defer mutex.unlock();
        counter += 1;
    }
}

pub fn main() !void {
    var threads: [4]std.Thread.Thread = undefined;

    for (threads) |*t, i| {
        t.* = try std.Thread.spawn(.{}, worker, .{i});
    }

    for (threads) |t| {
        t.join();
    }

    std.debug.print("Final counter: {}\n", .{counter}); // 应该是 4000
}