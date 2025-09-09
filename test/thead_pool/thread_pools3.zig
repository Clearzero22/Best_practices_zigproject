// thread_pool.zig
const std = @import("std");

/// 一个任务：函数 + 上下文（类型擦除）
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

        var task_list = std.ArrayList(Task).init(alloc);
        errdefer task_list.deinit();

        return .{
            .allocator = alloc,
            .threads = threads,
            .tasks = task_list,
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

    /// 提交任务（泛型安全）
    pub fn submit(
        self: *ThreadPool,
        comptime T: type,
        func: *const fn (*T) void,
        ctx: *T,
    ) !void {
        const task = Task{
            .func = @ptrCast(func),
            .ctx = @ptrCast(ctx),
        };

        self.mutex.lock();
        defer self.mutex.unlock();

        try self.tasks.append(task);
        self.cond.signal(); // 唤醒一个线程
    }

    /// 关闭线程池（等待所有任务完成）
    pub fn deinit(self: *ThreadPool) void {
        // 设置关闭标志
        self.shutdown.store(true, .seq_cst);

        // 唤醒所有线程
        self.mutex.lock();
        self.cond.broadcast();
        self.mutex.unlock();

        // 等待所有线程退出
        for (self.threads) |*t| t.join();

        // 清理资源
        self.tasks.deinit();
        self.allocator.free(self.threads);
    }

    /// 工作线程主函数
    fn worker(pool: *ThreadPool, thread_index: usize) void {
        while (true) {
            pool.mutex.lock();

            // 等待任务或关闭信号
            while (!pool.shutdown.load(.seq_cst) and pool.tasks.items.len == 0) {
                pool.cond.wait(&pool.mutex);
            }

            // 是否退出？
            if (pool.shutdown.load(.seq_cst) and pool.tasks.items.len == 0) {
                pool.mutex.unlock();
                break;
            }

            // 取出第一个任务（FIFO）
            const task = pool.tasks.orderedRemove(0); // FIFO：先进先出
            pool.mutex.unlock();

            // 执行任务
            std.debug.print("[Worker {}] Executing task...\n", .{thread_index});
            task.func(task.ctx);
        }
    }
};

// ======== 任务定义区 ========

// 全局分配器
const allocator = std.heap.page_allocator;

// 通用上下文包装器（含值 + 信号量）
fn TaskCtx(comptime T: type) type {
    return struct {
        value: T,
        sem: *std.Thread.Semaphore,

        pub fn new(alloc: std.mem.Allocator, val: T, s: *std.Thread.Semaphore) !*Self {
            const self = try alloc.create(Self);
            self.* = .{ .value = val, .sem = s };
            return self;
        }

        pub fn destroy(self: *Self, alloc: std.mem.Allocator) void {
            alloc.destroy(self);
        }

        const Self = @This();
    };
}

/// 提交一个自动管理生命周期的任务
fn submitTask(
    pool: *ThreadPool,
    comptime T: type,
    value: T,
    func: *const fn (*TaskCtx(T)) void,
    sem: *std.Thread.Semaphore,
) !void {
    const ctx = try TaskCtx(T).new(pool.allocator, value, sem);
    try pool.submit(TaskCtx(T), func, ctx);
}

// 全局引用 allocator（用于 destroy）
var pool_allocator: std.mem.Allocator = undefined;

// ======== 主函数 ========
pub fn main() !void {
    pool_allocator = allocator; // 初始化全局 allocator

    const thread_count = 4;
    var pool = try ThreadPool.init(allocator, thread_count);
    defer pool.deinit();

    try pool.start();

    var sem = std.Thread.Semaphore{}; // 用于同步等待

    // === 提交任务 ===
    const total_tasks = 7;
    var submitted: usize = 0;

    // 1. 整数任务
    const numbers = [_]i32{ 10, 20, 30 };
    for (numbers) |n| {
        try submitTask(&pool, i32, n, taskPrintNumber, &sem);
        submitted += 1;
    }

    // 2. 字符串任务（使用 c"..."）
    // try submitTask(&pool, [*:0]const u8, c"Hello", taskPrintString, &sem);
    // try submitTask(&pool, [*:0]const u8, c"World", taskPrintString, &sem);
    submitted += 2;

    // 3. 数学任务
    const ops = [_]MathOp{
        .{ .a = 5.5, .b = 2.3, .op = 'a' },
        .{ .a = 10.0, .b = 4.0, .op = 'm' },
        .{ .a = 100.0, .b = 3.0, .op = 'd' },
    };
    for (ops) |op| {
        try submitTask(&pool, MathOp, op, taskMathOp, &sem);
        submitted += 1;
    }

    std.debug.print("✅ All {}/{} tasks submitted. Waiting for completion...\n", .{ submitted, total_tasks });

    // 等待所有任务完成
    var completed: usize = 0;
    while (completed < total_tasks) {
        sem.wait();
        completed += 1;
    }

    std.debug.print("🎉 All {} tasks completed successfully!\n", .{total_tasks});
}
