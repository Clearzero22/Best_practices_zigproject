const std = @import("std");
const builtin = @import("builtin");

test "打印当前平台 Target 信息" {
    const target = &builtin.target;

    std.debug.print("=== 当前编译目标信息 ===\n", .{});
    std.debug.print("CPU 架构: {}\n", .{target.cpu.arch});
    std.debug.print("操作系统: {}\n", .{target.os.tag});
    std.debug.print("ABI: {}\n", .{target.abi});
    std.debug.print("对象格式: {}\n", .{target.ofmt});
    std.debug.print("指针位宽: {d} 位\n", .{std.Target.ptrBitWidth(target.*)});
    std.debug.print("栈对齐: {d} 字节\n", .{std.Target.stackAlignment(target.*)});
    std.debug.print("可执行文件扩展名: '{s}'\n", .{std.Target.exeFileExt(target.*)});
    std.debug.print("动态库后缀: '{s}'\n", .{std.Target.dynamicLibSuffix(target.*)});
    std.debug.print("静态库后缀: '{s}'\n", .{std.Target.staticLibSuffix(target.*)});
    std.debug.print("库前缀: '{s}'\n", .{std.Target.libPrefix(target.*)});

    if (std.Target.isGnuLibC(target.*)) {
        std.debug.print("libc 类型: glibc\n", .{});
    } else if (std.Target.isMuslLibC(target.*)) {
        std.debug.print("libc 类型: musl\n", .{});
    } else if (std.Target.isMinGW(target.*)) {
        std.debug.print("libc 类型: MinGW\n", .{});
    }
}
