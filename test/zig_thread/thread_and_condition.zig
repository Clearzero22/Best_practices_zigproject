const std = @import("std");

var buffer: usize = 0;
var mutex = std.Thread.Mutex{};
var cond = std.Thread.Condition{};
var done = false;

fn producer() void {
    var i: usize = 1;
    while (i <= 5) : (i += 1) {
        mutex.lock();
        defer mutex.unlock();

        while (buffer != 0) {
            cond.wait(&mutex);
        }

        buffer = i;
        std.debug.print("Produced: {}\n", .{i});
        std.debug.print("线程 id {} ", .{std.Thread.getCurrentId()});
        cond.broadcast();
    }

    mutex.lock();
    defer mutex.unlock();
    done = true;
    cond.broadcast();
}

fn consumer() void {
    while (true) {
        mutex.lock();
        defer mutex.unlock();

        while (buffer == 0 and !done) {
            cond.wait(&mutex);
        }

        if (done and buffer == 0) break;

        std.debug.print("Consumed: {}\n", .{buffer});
        std.debug.print("线程 id {} ", .{std.Thread.getCurrentId()});

        buffer = 0;
        cond.broadcast();
    }
}

pub fn main() !void {
    var p = try std.Thread.spawn(.{}, producer, .{});
    var c = try std.Thread.spawn(.{}, consumer, .{});

    p.join();
    c.join();
}
