const std = @import("std");

pub const Stack = struct {
    data: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) Stack {
        return Stack{ .data = std.ArrayList(u8).init(allocator) };
    }

    pub fn deinit(self: Stack) void {
        self.data.deinit();
    }

    pub fn push(self: *Stack, p: []const u8) !void {
        try self.data.appendSlice(p);
    }

    pub fn pop(self: *Stack) void {
        _ = self.data.pop();
    }

    pub fn path(self: Stack) []const u8 {
        return self.data.items;
    }
};
