const std = @import("std");

const Node = struct {
    data: i32,
    next: ?*Node,
};

// 使用 std.atomic.Value 包装 head，确保所有访问都是原子的
var head = std.atomic.Value(?*Node).init(null);

fn push(new_node: *Node) void {
    while (true) {
        const current_head = head.load(.monotonic);
        new_node.next = current_head;
        // 尝试原子地将 head 从 current_head 更新为 new_node
        if (head.cmpxchgWeak(current_head, new_node, .release, .monotonic)) |_| {
            // 失败了（值被其他线程改了，或虚假失败）→ 重试
            continue;
        } else {
            // 成功了！
            break;
        }
    }
}

fn pop() ?*Node {
    while (true) {
        const current_head = head.load(.monotonic) orelse return null;
        const new_head = current_head.next;
        // 尝试原子地将 head 从 current_head 更新为 new_head
        if (head.cmpxchgWeak(current_head, new_head, .acquire, .monotonic)) |_| {
            // 失败了 → 重试
            continue;
        } else {
            // 成功了！
            return current_head;
        }
    }
}

test "lock-free stack: single-threaded correctness" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 初始化栈
    head.store(null, .monotonic);

    // 创建并推入 3 个节点
    const node1 = try allocator.create(Node);
    node1.* = .{ .data = 1, .next = null };
    push(node1);

    const node2 = try allocator.create(Node);
    node2.* = .{ .data = 2, .next = null };
    push(node2);

    const node3 = try allocator.create(Node);
    node3.* = .{ .data = 3, .next = null };
    push(node3);

    // 弹出，顺序应该是 3 -> 2 -> 1
    const popped1 = pop().?;
    try std.testing.expect(popped1.data == 3);

    const popped2 = pop().?;
    try std.testing.expect(popped2.data == 2);

    const popped3 = pop().?;
    try std.testing.expect(popped3.data == 1);

    // 栈应为空
    try std.testing.expect(pop() == null);

    // 清理内存
    allocator.destroy(node1);
    allocator.destroy(node2);
    allocator.destroy(node3);
}

test "lock-free stack: multi-threaded stress test" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 初始化栈
    head.store(null, .monotonic);

    const num_threads = 4;
    const operations_per_thread = 1000;

    // 用于统计的原子计数器
    var total_pushed = std.atomic.Value(usize).init(0);
    var total_popped = std.atomic.Value(usize).init(0);

    // 启动工作线程
    var threads: [num_threads]std.Thread = undefined;
    for (&threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{
            .stack_size = 1024 * 1024,
        }, workerThread, .{
            allocator,
            i,
            operations_per_thread,
            &total_pushed,
            &total_popped,
        });
    }

    // 等待所有线程完成
    for (&threads) |*thread| {
        thread.join();
    }

    // 验证：推入总数 == 弹出总数
    const pushed = total_pushed.load(.monotonic);
    const popped = total_popped.load(.monotonic);
    try std.testing.expect(pushed == popped);

    // 验证栈为空
    try std.testing.expect(head.load(.monotonic) == null);

    std.debug.print("✅ 并发测试完成: 共推入 {d} 个节点, 弹出 {d} 个节点\n", .{ pushed, popped });
}

fn workerThread(
    allocator: std.mem.Allocator,
    operation_count: usize,
    total_pushed: *std.atomic.Value(usize),
    total_popped: *std.atomic.Value(usize),
) void {
    var local_pushed: usize = 0;
    var local_popped: usize = 0;

    for (0..operation_count) |_| {
        // 随机选择 push 或 pop
        if (@import("std").crypto.random.boolean()) {
            // PUSH
            const node = allocator.create(Node) catch continue;
            node.* = .{
                .data = @intCast(@import("std").crypto.random.int(u32)), // ← 修复：去掉 i32,
                .next = null,
            };
            push(node);
            local_pushed += 1;
        } else {
            // POP
            if (pop()) |node| {
                allocator.destroy(node);
                local_popped += 1;
            }
        }
    }

    // 原子地更新全局计数器
    _ = total_pushed.fetchAdd(local_pushed, .monotonic);
    _ = total_popped.fetchAdd(local_popped, .monotonic);
}
