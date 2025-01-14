const std = @import("std");
const eql = @import("value.zig").eql;

const Tag = enum { path_len, index };

const Storage = union(Tag) {
    path_len: usize,
    index: usize,
};

/// Stack data structure. It saves either index or pathes (strings). For pathes, a length is saved that referes to the string in the buffer.
pub const Stack = struct {
    allocator: std.mem.Allocator,
    path_buffer: std.ArrayListUnmanaged(u8),
    data: std.ArrayListUnmanaged(Storage),
    root: std.json.Value,

    pub fn init(allocator: std.mem.Allocator, root_node: std.json.Value, capacity: usize) !Stack {
        // TODO allow to give an estimated depth and init with capacity
        return .{
            .allocator = allocator,
            .path_buffer = try std.ArrayListUnmanaged(u8).initCapacity(allocator, capacity),
            .data = try std.ArrayListUnmanaged(Storage).initCapacity(allocator, capacity),
            .root = root_node,
        };
    }

    pub fn deinit(self: *Stack) void {
        self.path_buffer.deinit(self.allocator);
        self.data.deinit(self.allocator);
    }

    pub fn pushPath(self: *Stack, path: []const u8) !void {
        try self.path_buffer.appendSlice(self.allocator, path);
        try self.data.append(self.allocator, .{ .path_len = path.len });
    }

    pub fn pushIndex(self: *Stack, index: usize) !void {
        try self.data.append(self.allocator, .{ .index = index });
    }

    pub fn pop(self: *Stack) void {
        const item = self.data.pop();
        switch (item) {
            .path_len => |len| {
                self.path_buffer.shrinkRetainingCapacity(self.path_buffer.items.len - len);
            },
            .index => {},
        }
    }

    pub fn constructPath(self: Stack, allocator: std.mem.Allocator) ![]const u8 {
        // TODO performance can be enhanced!
        var path = std.ArrayList(u8).init(allocator);
        try path.append('#');

        var buffer_head: usize = 0;
        for (self.data.items) |storage| {
            try path.append('/');
            switch (storage) {
                .index => |index| {
                    var writer = path.writer();
                    try writer.print("{}", .{index});
                },
                .path_len => |len| {
                    const start = buffer_head;
                    buffer_head += len;
                    try path.appendSlice(self.path_buffer.items[start..buffer_head]);
                },
            }
        }

        return try path.toOwnedSlice();
    }

    pub fn value(self: Stack, abs_path: []const u8) !?std.json.Value {
        std.debug.assert(abs_path[0] == '#');
        if (abs_path.len == 1) return self.root;

        var it = try std.fs.path.componentIterator(abs_path[1..]);
        var parent = self.root;
        while (it.next()) |component| {
            switch (parent) {
                .object => |object| {
                    if (object.get(component.name)) |v| {
                        parent = v;
                    } else {
                        std.debug.print("could not find key {s} in object at path {s}\n", .{ component.name, component.path });
                        return null;
                    }
                },
                .array => |array| {
                    const idx = try std.fmt.parseInt(usize, component.name, 10);
                    if (idx >= array.items.len) {
                        std.debug.print("requested array index {} does not exist in array at path {s}\n", .{ idx, component.path });
                        return null;
                    }
                    return array.items[idx];
                },
                else => {
                    std.debug.panic("given parent has no subvalues.", .{});
                },
            }
        }

        return parent;
    }
};

test "stack" {
    const schema =
        \\{
        \\  "$id": "https://example.com/complex-object.schema.json",
        \\  "$schema": "https://json-schema.org/draft/2020-12/schema",
        \\  "title": "Complex Object",
        \\  "type": "object",
        \\  "properties": {
        \\    "name": {
        \\      "type": "string"
        \\    },
        \\    "age": {
        \\      "type": "integer",
        \\      "minimum": 0
        \\    },
        \\    "address": {
        \\      "type": "object",
        \\      "properties": {
        \\        "street": {
        \\          "type": "string"
        \\        },
        \\        "city": {
        \\          "type": "string"
        \\        },
        \\        "state": {
        \\          "type": "string"
        \\        },
        \\        "postalCode": {
        \\          "type": "string",
        \\          "pattern": "\\d{5}"
        \\        }
        \\      },
        \\      "required": ["street", "city", "state", "postalCode"]
        \\    },
        \\    "hobbies": {
        \\      "type": "array",
        \\      "items": {
        \\        "type": "string"
        \\      }
        \\    }
        \\  },
        \\  "required": ["name", "age"]
        \\}
    ;

    const allocator = std.testing.allocator;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, schema, .{});
    defer parsed.deinit();

    var stack = try Stack.init(allocator, parsed.value, 10);
    defer stack.deinit();

    // the initial path of the stack is the root
    {
        const path = try stack.constructPath(allocator);
        defer allocator.free(path);
        try std.testing.expectEqualStrings("#", path);

        const node = (try stack.value(path)).?;
        try std.testing.expect(eql(node, stack.root));
    }

    try stack.pushPath("properties");
    {
        const path = try stack.constructPath(allocator);
        defer allocator.free(path);
        try std.testing.expectEqualStrings("#/properties", path);

        const node = (try stack.value(path)).?;
        try std.testing.expect(eql(node, stack.root.object.get("properties").?));
    }

    try stack.pushPath("address");
    {
        const path = try stack.constructPath(allocator);
        defer allocator.free(path);
        try std.testing.expectEqualStrings("#/properties/address", path);

        const node = (try stack.value(path)).?;
        try std.testing.expect(eql(node, stack.root.object.get("properties").?.object.get("address").?));
    }

    try stack.pushPath("required");
    {
        const path = try stack.constructPath(allocator);
        defer allocator.free(path);
        try std.testing.expectEqualStrings("#/properties/address/required", path);

        const node = (try stack.value(path)).?;
        try std.testing.expect(eql(node, stack.root.object.get("properties").?.object.get("address").?.object.get("required").?));
    }

    try stack.pushIndex(1);
    {
        const path = try stack.constructPath(allocator);
        defer allocator.free(path);
        try std.testing.expectEqualStrings("#/properties/address/required/1", path);

        const node = (try stack.value(path)).?;
        try std.testing.expect(eql(node, stack.root.object.get("properties").?.object.get("address").?.object.get("required").?.array.items[1]));
    }

    stack.pop();
    {
        const path = try stack.constructPath(allocator);
        defer allocator.free(path);
        try std.testing.expectEqualStrings("#/properties/address/required", path);
    }

    stack.pop();
    {
        const path = try stack.constructPath(allocator);
        defer allocator.free(path);
        try std.testing.expectEqualStrings("#/properties/address", path);
    }
}
