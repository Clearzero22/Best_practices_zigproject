const std = @import("std");
const Treap = std.Treap;

const TestTreap = Treap(u64, std.math.order);
const TestNode = TestTreap.Node;

test "std.Treap: insert, find, replace, remove" {
    var treap = TestTreap{};
    var nodes: [10]TestNode = undefined;

    var prng = std.rand.DefaultPrng.init(0xdeadbeef);
    var iter = SliceIterRandomOrder(TestNode).init(&nodes, prng.random());

    // insert check
    iter.reset();
    while (iter.next()) |node| {
        const key = prng.random().int(u64);

        // make sure the current entry is empty.
        var entry = treap.getEntryFor(key);
        try testing.expectEqual(entry.key, key);
        try testing.expectEqual(entry.node, null);

        // insert the entry and make sure the fields are correct.
        entry.set(node);
        try testing.expectEqual(node.key, key);
        try testing.expectEqual(entry.key, key);
        try testing.expectEqual(entry.node, node);
    }

    // find check
    iter.reset();
    while (iter.next()) |node| {
        const key = node.key;

        // find the entry by-key and by-node after having been inserted.
        var entry = treap.getEntryFor(node.key);
        try testing.expectEqual(entry.key, key);
        try testing.expectEqual(entry.node, node);
        try testing.expectEqual(entry.node, treap.getEntryForExisting(node).node);
    }

    // in-order iterator check
    {
        var it = treap.inorderIterator();
        var last_key: u64 = 0;
        while (it.next()) |node| {
            try std.testing.expect(node.key >= last_key);
            last_key = node.key;
        }
    }

    // replace check
    iter.reset();
    while (iter.next()) |node| {
        const key = node.key;

        // find the entry by node since we already know it exists
        var entry = treap.getEntryForExisting(node);
        try testing.expectEqual(entry.key, key);
        try testing.expectEqual(entry.node, node);

        var stub_node: TestNode = undefined;

        // replace the node with a stub_node and ensure future finds point to the stub_node.
        entry.set(&stub_node);
        try testing.expectEqual(entry.node, &stub_node);
        try testing.expectEqual(entry.node, treap.getEntryFor(key).node);
        try testing.expectEqual(entry.node, treap.getEntryForExisting(&stub_node).node);

        // replace the stub_node back to the node and ensure future finds point to the old node.
        entry.set(node);
        try testing.expectEqual(entry.node, node);
        try testing.expectEqual(entry.node, treap.getEntryFor(key).node);
        try testing.expectEqual(entry.node, treap.getEntryForExisting(node).node);
    }

    // remove check
    iter.reset();
    while (iter.next()) |node| {
        const key = node.key;

        // find the entry by node since we already know it exists
        var entry = treap.getEntryForExisting(node);
        try testing.expectEqual(entry.key, key);
        try testing.expectEqual(entry.node, node);

        // remove the node at the entry and ensure future finds point to it being removed.
        entry.set(null);
        try testing.expectEqual(entry.node, null);
        try testing.expectEqual(entry.node, treap.getEntryFor(key).node);

        // insert the node back and ensure future finds point to the inserted node
        entry.set(node);
        try testing.expectEqual(entry.node, node);
        try testing.expectEqual(entry.node, treap.getEntryFor(key).node);
        try testing.expectEqual(entry.node, treap.getEntryForExisting(node).node);

        // remove the node again and make sure it was cleared after the insert
        entry.set(null);
        try testing.expectEqual(entry.node, null);
        try testing.expectEqual(entry.node, treap.getEntryFor(key).node);
    }
}
