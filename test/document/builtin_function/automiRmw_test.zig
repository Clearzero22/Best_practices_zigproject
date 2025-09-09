const std = @import("std");

const SpinLock = struct {
    locked: u8, // 0 = unlocked, 1 = locked

    pub fn lock(self: *SpinLock) void {
        while (@atomicRmw(u8, &self.locked, .Xchg, 1, .acquire) == 1) {
            // 自旋等待，直到拿到锁（交换成功，返回旧值 0）
            std.time.sleep(1); // 避免忙等
        }
    }

    pub fn unlock(self: *SpinLock) void {
        @atomicStore(u8, &self.locked, 0, .release);
    }
};

test "SpinLock with @atomicRmw Xchg" {
    var lock = SpinLock{ .locked = 0 };
    lock.lock(); // 获取锁
    lock.unlock(); // 释放锁
}
