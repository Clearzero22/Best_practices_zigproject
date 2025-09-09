// const std = @import("std");

// var flag = std.atomic.Value(bool).init(false);

// fn trySetOnce() bool {
//     const current = flag.load(.monotonic);
//     if (current) return false;

//     // 标准库方法，安全可靠
//     return flag.cmpxchgWeak(current, true, .release, .monotonic) == null;
// }

// test "cmpxchgStrong 示例" {
//     try std.testing.expect(trySetOnce() == true);
//     try std.testing.expect(trySetOnce() == false);
// }

const std = @import("std");

// 原子标志位，初始 false
var flag = std.atomic.Value(bool).init(false);

// 用于统计有多少线程“成功设置”了标志
var success_count = std.atomic.Value(usize).init(0);

// 尝试一次性设置标志
fn trySetOnce() bool {
    const current = flag.load(.monotonic);
    if (current) return false;

    // 原子地尝试从 false → true
    return flag.cmpxchgWeak(current, true, .release, .monotonic) == null;
}

// 每个线程执行的函数
fn workerThread(thread_id: usize) void {
    const success = trySetOnce();
    if (success) {
        // 如果成功，原子地增加计数
        _ = success_count.fetchAdd(1, .monotonic);
        std.debug.print("✅ 线程 {d} 成功设置了标志！\n", .{thread_id});
    } else {
        std.debug.print("❌ 线程 {d} 设置失败（已被占用）\n", .{thread_id});
    }
}

test "多线程测试：trySetOnce 应只被一个线程成功调用" {
    const num_threads = 5;
    var threads: [num_threads]std.Thread = undefined;

    // 启动多个线程
    for (0..num_threads) |i| {
        threads[i] = std.Thread.spawn(.{}, workerThread, .{i}) catch |err| {
            std.debug.print("创建线程 {d} 失败: {}\n", .{ i, err });
            return;
        };
    }

    // 等待所有线程结束
    for (&threads) |*t| {
        t.join();
    }

    // 检查：只有一个线程成功
    const total_success = success_count.load(.monotonic);
    try std.testing.expect(total_success == 1);
    std.debug.print("\n🎉 测试通过：总共 {d} 个线程，只有 1 个成功设置标志！\n", .{total_success});
}
