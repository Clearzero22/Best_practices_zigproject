# 📚 `ThreadPool` 线程池模块文档

---

## 🔧 概述

`ThreadPool` 是一个轻量级、高性能的线程池实现，专为 Zig 语言设计。它通过复用固定数量的工作线程来异步执行用户提交的任务，有效减少线程创建/销毁的开销，适用于高并发任务处理场景。

该模块提供以下核心功能：

- ✅ 固定大小线程池管理
- ✅ 安全的任务提交与调度
- ✅ 基于条件变量的阻塞唤醒机制
- ✅ 平滑关闭与资源清理
- ✅ 类型安全的任务上下文传递（通过 `comptime`）

---

## 📦 模块结构

```zig
const ThreadPool = struct { ... };
```

### 核心组件

| 成员 | 类型 | 描述 |
|------|------|------|
| `allocator` | `std.mem.Allocator` | 内存分配器，用于动态内存管理 |
| `threads` | `[]std.Thread` | 工作线程数组 |
| `tasks` | `std.ArrayList(Task)` | 任务队列（FIFO） |
| `mutex` | `std.Thread.Mutex` | 保护共享状态的互斥锁 |
| `cond` | `std.Thread.Condition` | 条件变量，用于线程阻塞与唤醒 |
| `shutdown` | `std.atomic.Value(bool)` | 原子标志，指示线程池是否正在关闭 |

---

## 🛠️ 公共 API

### 1. `init` —— 创建线程池实例

```zig
pub fn init(allocator: std.mem.Allocator, thread_count: usize) !ThreadPool
```

#### 参数

- `allocator`: 用于内存分配的分配器（如 `std.heap.page_allocator`）
- `thread_count`: 工作线程的数量（必须 > 0）

#### 返回值

- 成功：返回初始化后的 `ThreadPool`
- 失败：返回错误码（如 `error.OutOfMemory`）

#### 示例

```zig
var pool = try ThreadPool.init(std.heap.page_allocator, 4);
defer pool.deinit();
```

> ⚠️ **注意**：必须调用 `deinit()` 清理资源，避免内存泄漏。

---

### 2. `start` —— 启动所有工作线程

```zig
pub fn start(self: *ThreadPool) !void
```

#### 行为

- 为每个线程调用 `std.Thread.spawn` 启动 `worker` 函数
- 所有线程开始监听任务队列

#### 错误处理

- 若任一线程启动失败，返回相应错误（如 `error.SystemResources`）
- 已启动的线程不会自动回收（需手动管理）

#### 示例

```zig
try pool.start();
```

> ✅ 必须在 `submit` 前调用此函数。

---

### 3. `submit` —— 提交任务到线程池

```zig
pub fn submit(self: *ThreadPool, comptime T: type, func: *const fn (ctx: *T) void, ctx: *T) !void
```

#### 参数

- `T`: 上下文类型（编译时推导）
- `func`: 要执行的函数指针，接受 `*T` 类型参数
- `ctx`: 用户定义的上下文数据指针

#### 线程安全

- 使用 `mutex` 保护任务队列
- 添加任务后通过 `cond.signal()` 唤醒一个等待线程

#### 示例

```zig
fn myTask(data: *i32) void {
    std.debug.print("Processing {}\n", .{data.*});
}

var value: i32 = 42;
try pool.submit(i32, myTask, &value);
```

> ⚠️ **警告**：确保 `ctx` 指向的数据在整个任务执行期间有效（避免悬垂指针）。

---

### 4. `deinit` —— 关闭并清理线程池

```zig
pub fn deinit(self: *ThreadPool) void
```

#### 行为

1. 设置 `shutdown` 标志为 `true`
2. 广播条件变量，唤醒所有阻塞中的线程
3. 调用 `join()` 等待所有线程退出
4. 释放内部资源（任务列表、线程数组）

#### 阻塞性质

- 此函数是 **阻塞的**
- 直到所有线程完成当前任务并退出才返回
- 不会中断正在运行的任务（无抢占式取消）

#### 示例

```zig
pool.deinit(); // 阻塞直到所有线程结束
```

> ✅ 推荐使用 `defer pool.deinit()` 确保资源释放。

---

## 🔄 内部工作机制

### 任务调度流程

1. 用户调用 `submit(...)` 将任务加入队列
2. `cond.signal()` 唤醒一个空闲工作线程
3. 工作线程从队列取出任务并解锁
4. 在无锁状态下执行任务函数
5. 执行完毕后继续等待新任务

### 工作线程主循环 (`worker`)

```zig
while (true) {
    lock(mutex)
    while (no_tasks && !shutdown) wait(cond)
    if (shutdown && no_tasks) break
    task = take_task()
    unlock(mutex)
    if (task) task.func(task.ctx)
}
```

#### 特性

- ✅ **锁粒度最小化**：仅在访问共享队列时加锁
- ✅ **高效唤醒**：`signal()` 避免惊群效应（除非 `broadcast`）
- ✅ **优雅关闭**：检测 `shutdown` 标志后退出

---

## 🧪 使用示例

```zig
const std = @import("std");

fn printNumber(num: *i32) void {
    std.debug.print("Task: {} on thread {}\n", .{
        num.*, std.Thread.getCurrentId()
    });
    std.time.sleep(50_000_000); // 模拟耗时操作
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var pool = try ThreadPool.init(allocator, 3);
    defer pool.deinit();

    try pool.start();

    // 提交多个独立任务
    var values = [_]i32{ 1, 2, 3, 4, 5 };
    for (&values) |*v| {
        try pool.submit(i32, printNumber, v);
    }

    std.debug.print("All tasks submitted.\n", .{});

    // 等待足够时间让任务完成
    std.time.sleep(1_000_000_000);
}
```

---

## ⚠️ 注意事项与限制

| 项目 | 说明 |
|------|------|
| ❌ **无任务优先级支持** | 所有任务按 FIFO 顺序处理 |
| ❌ **无任务取消机制** | 无法中断已提交或正在运行的任务 |
| ⚠️ **不等待任务完成** | `deinit` 不保证所有任务已完成（仅等待线程退出） |
| ⚠️ **上下文生命周期责任** | 调用者必须确保 `ctx` 数据在任务执行期间有效 |
| ⚠️ **未处理异常任务** | 任务内部 panic 会导致线程终止，影响池稳定性 |
| 💡 **推荐用途** | 短期、可预测、无共享状态的计算密集型任务 |

---

## 📈 性能建议

- ✅ 使用较小的线程数（通常等于 CPU 核心数）
- ✅ 避免提交长时间阻塞任务（如网络 I/O），以免占用工作线程
- ✅ 对于大量短期任务，批量提交可减少锁竞争
- ✅ 考虑结合 `std.event.Loop` 实现异步 I/O 协程模型

---

## 🧩 扩展建议（未来改进方向）

| 功能 | 描述 |
|------|------|
| ✅ 任务完成回调 | 支持 `onComplete: ?fn(*anyopaque) void` |
| ✅ 动态线程伸缩 | 根据负载自动增减线程数 |
| ✅ 任务队列容量限制 | 防止无限积压导致 OOM |
| ✅ 统计信息接口 | 获取活跃线程数、任务吞吐量等 |
| ✅ 优先级队列 | 支持高/中/低优先级任务调度 |

---

## 📎 许可证

MIT License — 自由使用、修改和分发。

---

> 📞 如需支持或报告问题，请联系开发者社区或提交 Issue。
>
> **版本**: v1.0.0  
> **作者**: Zig 社区开发者  
> **最后更新**: 2025年9月9日