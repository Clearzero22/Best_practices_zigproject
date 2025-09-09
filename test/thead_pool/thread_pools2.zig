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
    pub fn init(alloc: std.mem.Allocator, thread_count: usize) !ThreadPool {
        const threads = try alloc.alloc(std.Thread, thread_count);
        errdefer alloc.free(threads);

        var tasks = std.ArrayList(Task).init(alloc);
        errdefer tasks.deinit();

        return ThreadPool{
            .allocator = alloc,
            .threads = threads,
            .tasks = tasks,
            .mutex = .{},
            .cond = .{},
            .shutdown = std.atomic.Value(bool).init(false),
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
            var task: ?Task = null;
            pool.mutex.lock();

            // 等待任务或关闭信号
            while (!pool.shutdown.load(.seq_cst) and pool.tasks.items.len == 0) {
                pool.cond.wait(&pool.mutex);
            }

            // 检查是否应退出
            if (pool.shutdown.load(.seq_cst) and pool.tasks.items.len == 0) {
                pool.mutex.unlock();
                break;
            }

            // 取出任务
            if (pool.tasks.items.len > 0) {
                task = pool.tasks.pop(); // ✅ 改用 pop() 避免 O(n) 移除
            }

            pool.mutex.unlock();

            // 执行任务
            if (task) |t| {
                std.debug.print("[Worker {}] Executing task...\n", .{thread_index});
                t.func(t.ctx);
            }
        }
    }
};

// ===== 任务类型定义 =====

// 任务1：处理整数
fn taskPrintNumber(data: *TaskCtx(i32)) void {
    defer data.sem.post(); // 通知完成
    defer allocator.destroy(data); // 释放堆内存

    std.debug.print("🔢 Task Number: {} on thread {}\n", .{ data.value, std.Thread.getCurrentId() });
    std.time.sleep(50_000_000);
}

// 任务2：处理字符串
fn taskPrintString(data: *TaskCtx([]const u8)) void {
    defer data.sem.post();
    defer allocator.destroy(data);

    std.debug.print("🔤 Task String: '{s}' on thread {}\n", .{ data.value, std.Thread.getCurrentId() });
}

// 任务3：处理数学运算
const MathOp = struct {
    a: f32,
    b: f32,
    op: u8, // 'a'dd, 's'ub, 'm'ul, 'd'iv
};

fn taskMathOp(data: *TaskCtx(MathOp)) void {
    defer data.sem.post();
    defer allocator.destroy(data);

    const result = switch (data.value.op) {
        'a' => data.value.a + data.value.b,
        's' => data.value.a - data.value.b,
        'm' => data.value.a * data.value.b,
        'd' => if (data.value.b != 0) data.value.a / data.value.b else std.math.inf(f32),
        else => std.math.nan(f32),
    };

    std.debug.print("🧮 Math Task: {} {} {} = {} on thread {}\n", .{
        data.value.a,
        data.value.op,
        data.value.b,
        result,
        std.Thread.getCurrentId(),
    });

    std.time.sleep(100_000_000);
}

// ===== 泛型上下文包装器 =====
const allocator = std.heap.page_allocator;

/// 通用任务上下文，包含实际值和同步信号量
fn TaskCtx(comptime T: type) type {
    return struct {
        value: T,
        sem: *std.Thread.Semaphore,
    };
}

/// 提交一个带完成通知的任务（自动堆分配）
fn submitWithSignal(
    pool: *ThreadPool,
    comptime T: type,
    value: T,
    func: *const fn (*TaskCtx(T)) void,
    sem: *std.Thread.Semaphore,
) !void {
    const ctx = try pool.allocator.create(TaskCtx(T));
    ctx.* = .{ .value = value, .sem = sem };
    try pool.submit(TaskCtx(T), func, ctx);
}

// ===== 主函数 =====

pub fn main() !void {
    const thread_count = 4;
    var pool = try ThreadPool.init(allocator, thread_count);
    defer pool.deinit();

    try pool.start();

    var sem = std.Thread.Semaphore{}; // 初始化信号量

    // === 提交任务 ===

    // 1. 整数任务
    const numbers = [_]i32{ 10, 20, 30 };
    for (numbers) |n| {
        try submitWithSignal(&pool, i32, n, taskPrintNumber, &sem);
    }

    // 2. 字符串任务
    // try submitWithSignal(&pool, []const u8, "Hello", taskPrintString, &sem);

    // 3. 数学任务
    // const ops = [_]MathOp{
    //     .{ .a = 5.5, .b = 2.3, .op = 'a' },
    //     .{ .a = 10.0, .b = 4.0, .op = 'm' },
    //     .{ .a = 100.0, .b = 3.0, .op = 'd' },
    // };
    // for (ops) |op| {
    //     try submitWithSignal(&pool, MathOp, op, taskMathOp, &sem);
    // }

    const total_tasks = 7;
    std.debug.print("✅ All {}/{} tasks submitted. Waiting for completion...\n", .{ total_tasks, total_tasks });

    // 等待所有任务完成
    var completed: usize = 0;
    while (completed < total_tasks) {
        sem.wait(); // 阻塞直到有任务完成
        completed += 1;
    }

    std.debug.print("🎉 All {} tasks completed successfully!\n", .{total_tasks});
}
