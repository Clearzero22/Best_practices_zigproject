const expect = @import("std").testing.expect;
const MovementState = packed struct {
    running: bool,
    crouching: bool,
    jumping: bool,
    in_air: bool,
};
test "bit aligned pointers" {
    var x = MovementState{
        .running = false,
        .crouching = false,
        .jumping = false,
        .in_air = false,
    };

    const running = &x.running;
    running.* = true;

    const crouching = &x.crouching;
    crouching.* = true;

    try expect(@TypeOf(running) == *align(1:0:1) bool);
    try expect(@TypeOf(crouching) == *align(1:1:1) bool);

    try expect(@import("std").meta.eql(x, .{
        .running = true,
        .crouching = true,
        .jumping = false,
        .in_air = false,
    }));
}
