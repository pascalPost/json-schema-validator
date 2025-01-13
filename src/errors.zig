const std = @import("std");

// TODO enhance schema logging (schema error, schema warning)
// TODO enhance validation errors (compare to other implementations)

const Error = struct {
    path: []const u8,
    msg: []const u8,
};

pub const Errors = struct {
    arena: std.heap.ArenaAllocator,
    data: std.ArrayListUnmanaged(Error) = .{},

    // TODO why is this an unmanaged list w/ an arean instead of a ArrayList (?)

    pub fn init(allocator: std.mem.Allocator) Errors {
        return .{
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: Errors) void {
        self.arena.deinit();
    }

    pub fn append(self: *Errors, err: Error) !void {
        try self.data.append(self.arena.allocator(), err);
    }

    pub fn empty(self: Errors) bool {
        return self.data.items.len == 0;
    }
};
