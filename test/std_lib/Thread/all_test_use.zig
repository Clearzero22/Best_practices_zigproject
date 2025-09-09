const std = @import("std");
const testing = std.testing;

// 用于测试的简单工作函数
fn dummyWorker() void {
    std.Thread.sleep(10_000_000); // 10ms
}

fn panicWorker() void {
    @panic("故意崩溃");
}

fn longWorker(id: usize, duration_ns: u64) void {
    std.debug.print("线程 {d} 开始工作\n", .{id});
    std.Thread.sleep(duration_ns);
    std.debug.print("线程 {d} 工作结束\n", .{id});
}

test "std.Thread.spawn - basic" {
    var thread = try std.Thread.spawn(.{}, dummyWorker, .{});
    thread.join(); // 应正常结束
}

test "std.Thread.spawn - 带参数" {
    var thread = try std.Thread.spawn(.{}, longWorker, .{ 1, 10_000_000 });
    thread.join();
}

test "std.Thread.spawn - 自定义栈大小" {
    var thread = try std.Thread.spawn(.{
        .stack_size = 1024 * 1024, // 1MB
    }, dummyWorker, .{});
    thread.join();
}

test "std.Thread.join - 正常等待" {
    var thread = try std.Thread.spawn(.{}, dummyWorker, .{});
    thread.join(); // 不应崩溃
}

test "std.Thread.detach - 分离线程" {
    var thread = try std.Thread.spawn(.{}, dummyWorker, .{});
    thread.detach(); // 线程结束后自动清理
    // 注意：不能再调用 join() 或其他方法！
}

test "std.Thread.sleep - 休眠基本功能" {
    const start = std.time.nanoTimestamp();
    std.Thread.sleep(50_000_000); // 50ms
    const end = std.time.nanoTimestamp();

    const diff = end - start;
    if (diff < 0) {
        @panic("时间倒流？系统时钟异常！");
    }
    const elapsed = @as(u64, @intCast(diff)); // 先 intCast 再 as（适用于 0.13）
    // 允许误差（系统调度不精确）
    try testing.expect(elapsed >= 40_000_000);
    try testing.expect(elapsed <= 100_000_000);
}

test "std.Thread.yield - 让出 CPU" {
    // 无法精确测试，但应不 panic
    try std.Thread.yield();
}

test "std.Thread.getCurrentId - 获取当前线程 ID" {
    const id = std.Thread.getCurrentId();
    // 至少确保不为零（某些平台 ID 从 1 开始）
    // 注意：Windows 线程 ID 可能为 0，所以不 assert 非零
    _ = id; // just use it
}

test "std.Thread.getCpuCount - 获取 CPU 核心数" {
    const count = try std.Thread.getCpuCount();
    try testing.expect(count > 0);
    std.debug.print("CPU 核心数: {d}\n", .{count});
}

test "std.Thread.setName / getName - 设置和获取线程名" {
    var thread = try std.Thread.spawn(.{}, dummyWorker, .{});

    const name = "TestThread";
    try thread.setName(name);

    var buffer: [std.Thread.max_name_len:0]u8 = undefined;
    if (try thread.getName(&buffer)) |got_name| {
        std.debug.print("获取线程名: '{s}'\n", .{got_name});
        try testing.expect(std.mem.eql(u8, got_name, name));
    } else {
        std.debug.print("平台不支持获取线程名\n", .{});
    }

    thread.join();
}

test "std.Thread.getHandle - 获取线程句柄" {
    var thread = try std.Thread.spawn(.{}, dummyWorker, .{});
    const handle = thread.getHandle();
    _ = handle; // 至少确保不崩溃
    thread.join();
}

// test "std.Thread.spawn - 线程函数 panic 应 abort 整个程序（无法捕获）" {
//     // 注意：子线程 panic 会导致整个程序 abort，无法在测试中“捕获”
//     // 所以此测试仅用于手动验证（运行时会崩溃）

//     if (std.builtin.Mode == .Debug or std.builtin.Mode == .ReleaseSafe) {
//         std.debug.print("\n⚠️  下面测试会故意崩溃，请确认是否要运行\n", .{});
//         // 取消注释下面这行来手动测试崩溃行为
//         var thread = try std.Thread.spawn(.{}, panicWorker, .{});
//         thread.join();
//     }
// }

test "std.Thread.join - 重复调用应为未定义行为（不测试，危险）" {
    // join() 后 Thread 对象被消费，重复调用是 UB，不写测试
    std.debug.print("跳过：重复 join 是未定义行为\n", .{});
}

test "std.Thread.detach - 重复调用应为未定义行为（不测试，危险）" {
    std.debug.print("跳过：重复 detach 是未定义行为\n", .{});
}

// test "std.Thread.Mutex - 基本加锁解锁" {
//     var mutex = std.Thread.Mutex{};
//     mutex.lock();
//     mutex.unlock();
// }

// test "std.Thread.Mutex - 多线程竞争锁" {
//     var mutex = std.Thread.Mutex{};
//     var shared_counter: usize = 0;

//     const num_threads = 4;
//     const increments_per_thread = 1000;

//     var threads: [num_threads]std.Thread = undefined;

//     fn worker() void{for (0..increments_per_thread) |_| {
//         mutex.lock();
//         shared_counter += 1;
//         mutex.unlock();
//     }};

//     for (0..num_threads) |i| {
//         threads[i] = try std.Thread.spawn(.{}, worker, .{});
//     }

//     for (&threads) |*t| {
//         t.join();
//     }

//     try testing.expect(shared_counter == num_threads * increments_per_thread);
// }

// test "std.Thread.RwLock - 读写锁基本功能" {
//     var rwlock = std.Thread.RwLock{};
//     var data: usize = 0;

//     // 写锁
//     rwlock.writeLock();
//     data = 42;
//     rwlock.writeUnlock();

//     // 读锁
//     rwlock.readLock();
//     const val = data;
//     rwlock.readUnlock();

//     try testing.expect(val == 42);
// }

test "std.Thread.Condition - 条件变量基本功能" {
    var mutex = std.Thread.Mutex{};
    var cond = std.Thread.Condition{};
    var ready: bool = false;

    var thread = try std.Thread.spawn(.{}, struct {
        fn waiter(m: *std.Thread.Mutex, c: *std.Thread.Condition, r: *bool) void {
            m.lock();
            while (!r.*) {
                c.wait(m);
            }
            m.unlock();
            std.debug.print("条件满足，线程继续\n", .{});
        }
    }.waiter, .{ &mutex, &cond, &ready });

    std.Thread.sleep(10_000_000); // 等待一会儿

    mutex.lock();
    ready = true;
    cond.signal(); // 唤醒一个等待者
    mutex.unlock();

    thread.join();
}

// test "std.Thread.Semaphore - 信号量基本功能" {
//     var sem = std.Thread.Semaphore{ .count = 2 };

//     // acquire 应不阻塞（count=2）
//     sem.acquire();
//     sem.acquire();

//     // 再次 acquire 应阻塞 —— 我们启动一个线程测试
//     var thread = try std.Thread.spawn(.{}, struct {
//         fn blocker(s: *std.Thread.Semaphore) void {
//             s.acquire(); // 应阻塞，直到主线程 release
//             std.debug.print("信号量获取成功\n", .{});
//         }
//     }.blocker, .{&sem});

//     std.Thread.sleep(10_000_000); // 确保线程已阻塞
//     sem.release(); // 释放一个许可

//     thread.join(); // 应正常结束
// }

// // test "std.Thread.WaitGroup - 等待组功能" {
// //     var wg = std.Thread.WaitGroup{};
// //     const num_workers = 3;

// //     var threads: [num_workers]std.Thread = undefined;

// //     fn worker(w: *std.Thread.WaitGroup) void {
// //         defer w.done();
// //         std.Thread.sleep(10_000_000); // 模拟工作
// //     }

// //     wg.add(num_workers);

// //     for (0..num_workers) |i| {
// //         threads[i] = try std.Thread.spawn(.{}, worker, .{&wg});
// //     }

// //     wg.wait(); // 应等待所有 worker 调用 done()

// //     for (&threads) |*t| {
// //         t.join();
// //     }
// // }

// // ⚠️ 以下为平台相关或高级功能，简单测试或跳过

// test "std.Thread.Futex - 仅在 Linux 测试" {
//     if (std.Target.current.os.tag != .linux) {
//         std.debug.print("跳过：Futex 仅在 Linux 支持\n", .{});
//         return;
//     }

//     // Futex 是底层原语，通常不直接使用，这里仅确保类型存在
//     _ = std.Thread.Futex;
//     std.debug.print("Futex 类型存在（Linux）\n", .{});
// }

// test "std.Thread.Pool - 实验性功能（简单测试）" {
//     // Pool 是实验性功能，接口可能变动
//     // 这里仅确保能创建
//     var pool = std.Thread.Pool{};
//     defer pool.deinit();

//     try pool.spawn(dummyWorker, .{});
//     // 注意：Pool 的 spawn 不返回 Thread，需用其他方式同步
//     std.Thread.sleep(50_000_000); // 等待任务执行
// }

// test "std.Thread.ResetEvent - Windows 专用" {
//     if (std.Target.current.os.tag != .windows) {
//         std.debug.print("跳过：ResetEvent 仅在 Windows 支持\n", .{});
//         return;
//     }

//     var event = std.Thread.ResetEvent{};
//     defer event.deinit();

//     // 简单测试初始化和方法调用
//     event.reset();
//     event.set();
// }

test "std.Thread.spawn - 大量线程压力测试" {
    const num_threads = 1000;
    var threads: [num_threads]std.Thread = undefined;

    for (0..num_threads) |i| {
        threads[i] = try std.Thread.spawn(.{}, struct {
            fn lightWork(id: usize) void {
                _ = id;
            }
        }.lightWork, .{i});
    }

    for (&threads) |*t| {
        t.join();
    }

    std.debug.print("✅ 成功创建并回收 {d} 个线程\n", .{num_threads});
}
