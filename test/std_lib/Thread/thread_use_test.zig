const std = @import("std");

var counter = std.atomic.Value(usize).init(0);
var mutex = std.Thread.Mutex{};

fn worker(id: usize) void {
    for (0..1000) |_| {
        // 方式1：原子操作（推荐）
        _ = counter.fetchAdd(1, .monotonic);

        // 方式2：互斥锁（适合复杂操作）
        // mutex.lock();
        // counter += 1;
        // mutex.unlock();
    }
    std.debug.print("线程 {d} 完成\n", .{id});
}

test "多线程原子计数" {
    const thread_count = 4;
    var threads: [thread_count]std.Thread = undefined;

    for (0..thread_count) |i| {
        threads[i] = try std.Thread.spawn(.{}, worker, .{i});
    }

    for (&threads) |*t| {
        t.join();
    }

    const final = counter.load(.monotonic);
    try std.testing.expect(final == 4000);
    std.debug.print("✅ 最终计数: {d}\n", .{final});
}
