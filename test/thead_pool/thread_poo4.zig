// thread_pool.zig - Refactored with TaskGroup and no globals

const std = @import("std");

/// ========================
///     线程池核心 (Thread Pool)
/// ========================
pub const ThreadPool = struct {
    allocator: std.mem.Allocator,
    threads: []std.Thread,
    tasks: std.ArrayList(Task),
    mutex: std.Thread.Mutex,
    cond: std.Thread.Condition,
    shutdown: std.atomic.Value(bool),

    pub fn init(alloc: std.mem.Allocator, thread_count: usize) !*ThreadPool {
        const self = try alloc.create(ThreadPool);
        errdefer alloc.destroy(self);

        const threads = try alloc.alloc(std.Thread, thread_count);
        errdefer alloc.free(threads);

        var task_list = std.ArrayList(Task).init(alloc);
        errdefer task_list.deinit();

        self.* = .{
            .allocator = alloc,
            .threads = threads,
            .tasks = task_list,
            .mutex = .{},
            .cond = .{},
            .shutdown = std.atomic.Value(bool).init(false),
        };

        return self;
    }

    pub fn start(self: *ThreadPool) !void {
        for (self.threads, 0..) |*thread, i| {
            thread.* = try std.Thread.spawn(.{}, worker, .{ self, i });
        }
    }

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

    pub fn deinit(self: *ThreadPool) void {
        self.shutdown.store(true, .seq_cst);
        self.mutex.lock();
        self.cond.broadcast();
        self.mutex.unlock();

        for (self.threads) |*t| t.join();

        self.tasks.deinit();
        self.allocator.free(self.threads);
        self.allocator.destroy(self);
    }

    fn worker(pool: *ThreadPool, thread_index: usize) void {
        while (true) {
            pool.mutex.lock();

            while (!pool.shutdown.load(.seq_cst) and pool.tasks.items.len == 0) {
                pool.cond.wait(&pool.mutex);
            }

            if (pool.shutdown.load(.seq_cst) and pool.tasks.items.len == 0) {
                pool.mutex.unlock();
                break;
            }

            const task = pool.tasks.orderedRemove(0);
            pool.mutex.unlock();

            std.debug.print("[Worker {}] Executing task...\n", .{thread_index});
            task.func(task.ctx);
        }
    }
};

/// 单个任务（类型擦除）
const Task = struct {
    func: *const fn (ctx: *anyopaque) void,
    ctx: *anyopaque,
};

/// ========================
///     通用任务上下文
/// ========================
/// 包含值 + 同步信号量的任务上下文
fn TaskCtx(comptime T: type) type {
    return struct {
        value: T,
        sem: *std.Thread.Semaphore,
        pool_alloc: std.mem.Allocator, // 存储分配器用于销毁

        pub fn new(
            alloc: std.mem.Allocator,
            val: T,
            s: *std.Thread.Semaphore,
        ) !*Self {
            const self = try alloc.create(Self);
            self.* = .{
                .value = val,
                .sem = s,
                .pool_alloc = alloc,
            };
            return self;
        }

        pub fn destroy(self: *Self) void {
            self.pool_alloc.destroy(self);
        }

        const Self = @This();
    };
}

/// ========================
///     任务组（自动等待）
/// ========================
/// 用于管理一批任务的完成状态
pub const TaskGroup = struct {
    sem: std.Thread.Semaphore,
    count: std.atomic.Value(usize),

    pub fn init() TaskGroup {
        return .{
            .sem = .{},
            .count = std.atomic.Value(usize).init(0),
        };
    }

    /// 提交一个带数据的任务到线程池
    pub fn submit(
        self: *TaskGroup,
        pool: *ThreadPool,
        comptime T: type,
        value: T,
        func: *const fn (*TaskCtx(T)) void,
    ) !void {
        _ = self.count.fetchAdd(1, .monotonic);
        const ctx = try TaskCtx(T).new(pool.allocator, value, &self.sem);
        return pool.submit(TaskCtx(T), func, ctx);
    }

    /// 等待所有已提交的任务完成
    pub fn wait(self: *TaskGroup) void {
        const total = self.count.load(.monotonic);
        var completed: usize = 0;
        while (completed < total) {
            self.sem.wait();
            completed += 1;
        }
        // Reset for reuse (optional)
        _ = self.count.swap(0, .monotonic);
    }
};

/// ========================
///     示例任务函数
/// ========================
const MathOp = struct {
    a: f64,
    b: f64,
    op: u8,
};

fn taskPrintNumber(ctx: *TaskCtx(i32)) void {
    defer ctx.sem.post();
    defer ctx.destroy();

    std.debug.print("🔢 Number Task: {} on thread {}\n", .{ ctx.value, std.Thread.getCurrentId() });
}

fn taskMathOp(ctx: *TaskCtx(MathOp)) void {
    defer ctx.sem.post();
    defer ctx.destroy();

    const result = switch (ctx.value.op) {
        'a' => ctx.value.a + ctx.value.b,
        's' => ctx.value.a - ctx.value.b,
        'm' => ctx.value.a * ctx.value.b,
        'd' => if (ctx.value.b != 0) ctx.value.a / ctx.value.b else std.math.inf(f64),
        else => std.math.nan(f64),
    };

    std.debug.print("🧮 Math Task: {} op {} {} = {} on thread {}\n", .{ ctx.value.a, ctx.value.op, ctx.value.b, result, std.Thread.getCurrentId() });
}

/// ========================
///     主函数
/// ========================
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const thread_count = 4;

    // 创建线程池
    var pool = try ThreadPool.init(allocator, thread_count);
    defer pool.deinit();

    try pool.start();

    // 创建任务组（自动跟踪+等待）
    var tg = TaskGroup.init();

    // === 提交各种任务 ===

    // 1. 整数任务
    const numbers = [_]i32{ 10, 20, 30 };
    for (numbers) |n| {
        try tg.submit(pool, i32, n, taskPrintNumber);
    }

    // 2. 数学任务
    const ops = [_]MathOp{
        .{ .a = 5.5, .b = 2.3, .op = 'a' },
        .{ .a = 10.0, .b = 4.0, .op = 'm' },
        .{ .a = 100.0, .b = 3.0, .op = 'd' },
    };
    for (ops) |op| {
        try tg.submit(pool, MathOp, op, taskMathOp);
    }

    std.debug.print("✅ All tasks submitted. Waiting...\n", .{});

    // 自动等待所有任务完成
    tg.wait();

    std.debug.print("🎉 All tasks completed successfully!\n", .{});
}
