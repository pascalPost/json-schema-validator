const std = @import("std");

const RegexWrapper = opaque {};
extern fn createRegex([*]const u8) callconv(.C) *RegexWrapper;
extern fn destroyRegex(*RegexWrapper) callconv(.C) void;
extern fn matchRegex(*RegexWrapper, [*]const u8) callconv(.C) bool;

pub const Regex = struct {
    regex: *RegexWrapper,

    pub fn init(pattern: []const u8) Regex {
        return .{ .regex = createRegex(pattern.ptr) };
    }

    pub fn deinit(self: Regex) void {
        destroyRegex(self.regex);
    }

    pub fn match(self: Regex, text: []const u8) bool {
        return matchRegex(self.regex, text.ptr);
    }
};

test "regex" {
    const regex = Regex.init("f.*o");
    defer regex.deinit();
    try std.testing.expect(regex.match("foo"));
}
