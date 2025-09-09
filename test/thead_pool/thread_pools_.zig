const std = @import("std");

/// 一个任务：函数 + 上下文
const Task = struct {
    func: *const fn (ctx: *anyopaque) void,
    ctx: *anyopaque,
};

/// 线程池结构
pub const ThreadPool = struct {
    allocator: std.mem.Allocator,
    threads: []std.Thread,
    tasks: std.ArrayList(Task),
    mutex: std.Thread.Mutex,
    cond: std.Thread.Condition,
    shutdown: std.atomic.Value(bool),

    /// 创建线程池
    pub fn init(allocator: std.mem.Allocator, thread_count: usize) !ThreadPool {
        const threads = try allocator.alloc(std.Thread, thread_count);
        errdefer allocator.free(threads);

        var tasks = std.ArrayList(Task).init(allocator);
        errdefer tasks.deinit();

        return ThreadPool{
            .allocator = allocator,
            .threads = threads,
            .tasks = tasks,
            .mutex = .{},
            .cond = .{},
            .shutdown = std.atomic.Value(bool).init(false), // ✅ 正确初始化

        };
    }

    /// 启动所有工作线程
    pub fn start(self: *ThreadPool) !void {
        for (self.threads, 0..) |*thread, i| {
            thread.* = try std.Thread.spawn(.{}, worker, .{ self, i });
        }
    }

    /// 提交任务到线程池
    pub fn submit(self: *ThreadPool, comptime T: type, func: *const fn (ctx: *T) void, ctx: *T) !void {
        const task = Task{
            .func = @as(*const fn (*anyopaque) void, @ptrCast(func)),
            .ctx = @as(*anyopaque, @ptrCast(ctx)),
        };

        self.mutex.lock();
        defer self.mutex.unlock();

        try self.tasks.append(task);
        self.cond.signal(); // 唤醒一个等待的工作线程
    }

    /// 关闭线程池（等待所有任务完成）
    pub fn deinit(self: *ThreadPool) void {
        // 1. 设置关闭标志
        self.shutdown.store(true, .seq_cst);

        // 2. 唤醒所有线程，让它们检查关闭标志
        self.mutex.lock();
        self.cond.broadcast();
        self.mutex.unlock();

        // 3. 等待所有线程结束
        for (self.threads) |*thread| {
            thread.join();
        }

        // 4. 清理资源
        self.tasks.deinit();
        self.allocator.free(self.threads);
    }

    /// 工作线程主函数
    fn worker(pool: *ThreadPool, thread_index: usize) void {
        while (true) {
            // ✅ 第一步：在锁内获取任务
            var task: ?Task = null;
            pool.mutex.lock();

            // 等待任务或关闭信号
            while (!pool.shutdown.load(.seq_cst) and pool.tasks.items.len == 0) {
                pool.cond.wait(&pool.mutex);
            }

            // 检查是否关闭且无任务
            if (pool.shutdown.load(.seq_cst) and pool.tasks.items.len == 0) {
                pool.mutex.unlock();
                break; // 退出线程
            }

            // 取出任务（仍在锁内）
            if (pool.tasks.items.len > 0) {
                task = pool.tasks.swapRemove(0);
            }

            pool.mutex.unlock(); // ✅ 尽快释放锁

            // ✅ 第二步：解锁后执行任务
            if (task) |t| {
                std.debug.print("[Worker {}] Executing task...\n", .{thread_index});

                t.func(t.ctx);
            }
        }
    }
};

fn myTask(data: *i32) void {
    std.debug.print("Processing {} on thread {}\n", .{ data.*, std.Thread.getCurrentId() });
    std.time.sleep(100_000_000); // 模拟工作
}

// 不同的任务

// 任务1：处理整数
fn taskPrintNumber(data: *i32) void {
    std.debug.print("🔢 Task Number: {} on thread {}\n", .{ data.*, std.Thread.getCurrentId() });
    std.time.sleep(50_000_000);
}

// 任务2：处理字符串
fn taskPrintString(data: *[]const u8) void {
    const str = data.*;
    std.debug.print("🔤 Task String: '{s}' on thread {}\n", .{ str, std.Thread.getCurrentId() });
}
// 任务3：处理自定义结构体
const MathOp = struct {
    a: f32,
    b: f32,
    op: u8, // 'a'dd, 's'ub, 'm'ul, 'd'iv
};

fn taskMathOp(data: *MathOp) void {
    const result = switch (data.op) {
        'a' => data.a + data.b,
        's' => data.a - data.b,
        'm' => data.a * data.b,
        'd' => if (data.b != 0) data.a / data.b else std.math.inf(f32),
        else => std.math.nan(f32),
    };

    std.debug.print("🧮 Math Task: {} {} {} = {} on thread {}\n", .{ data.a, data.op, data.b, result, std.Thread.getCurrentId() });

    std.time.sleep(100_000_000);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var pool = try ThreadPool.init(allocator, 4);
    defer pool.deinit();

    try pool.start();

    // 提交多个任务 导致地址复用
    // var i: i32 = 0;
    // while (i < 10) : (i += 1) {
    //     try pool.submit(i32, myTask, &i);
    // }

    // 创建一个数组保存 0~9
    //     // ✅ 安全地提交任务：每个任务有独立的数据

    // var values = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };

    // for (&values) |*value| {
    //     try pool.submit(i32, myTask, value);
    // }

    // std.debug.print("All tasks submitted. Waiting...\n", .{});

    // // 主线程做其他事...
    // std.time.sleep(101 * 100_000_000);

    // 执行不同的任务
    // --- 提交多种不同类型的任务 ---

    // ✅ 1. 整数任务
    var numbers = [_]i32{ 10, 20, 30 };
    for (&numbers) |*n| {
        try pool.submit(i32, taskPrintNumber, n);
    }

    var hello: []const u8 = "Hello";
    try pool.submit([]const u8, taskPrintString, &hello);

    // ✅ 3. 结构体任务
    var ops = [_]MathOp{
        .{ .a = 5.5, .b = 2.3, .op = 'a' },
        .{ .a = 10.0, .b = 4.0, .op = 'm' },
        .{ .a = 100.0, .b = 3.0, .op = 'd' },
    };
    for (&ops) |*op| {
        try pool.submit(MathOp, taskMathOp, op);
    }

    std.debug.print("✅ All heterogeneous tasks submitted. Waiting...\n", .{});

    // 等待所有任务完成
    std.time.sleep(2_000_000_000); // 2 秒

}
