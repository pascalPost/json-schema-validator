const std = @import("std");
const eql = @import("value.zig").eql;

pub const Stack = struct {
    allocator: std.mem.Allocator,
    data: std.ArrayListUnmanaged(u8), // chars
    len: std.ArrayListUnmanaged(usize), // string lengths
    root: std.json.Value,

    pub fn init(allocator: std.mem.Allocator, root_node: std.json.Value, capacity: usize) !Stack {
        // TODO allow to give an estimated depth and init with capacity
        return .{
            .allocator = allocator,
            .data = try std.ArrayListUnmanaged(u8).initCapacity(allocator, capacity),
            .len = try std.ArrayListUnmanaged(usize).initCapacity(allocator, capacity),
            .root = root_node,
        };
    }

    pub fn deinit(self: *Stack) void {
        self.data.deinit(self.allocator);
        self.len.deinit(self.allocator);
    }

    pub fn push(self: *Stack, items: []const u8) !void {
        try self.data.appendSlice(self.allocator, items);
        try self.len.append(self.allocator, items.len);
    }

    pub fn pop(self: *Stack) void {
        const last_len = self.len.pop();
        self.data.shrinkRetainingCapacity(self.data.items.len - last_len);
    }

    pub fn path(self: Stack, allocator: std.mem.Allocator) ![]const u8 {
        // account for # and / and items
        var length = 1 + self.len.items.len;
        for (self.len.items) |l| length += l;

        var path_str = try allocator.alloc(u8, length);

        path_str[0] = '#';

        var data_head: usize = 0;
        var path_head: usize = 1;
        for (self.len.items) |word_length| {
            const word = self.data.items[data_head .. data_head + word_length];
            data_head += word_length;

            path_str[path_head] = '/';
            @memcpy(path_str[path_head + 1 .. path_head + 1 + word_length], word);
            path_head += word_length + 1;
        }

        return path_str;
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
        const path = try stack.path(allocator);
        defer allocator.free(path);
        try std.testing.expectEqualStrings("#", path);

        const node = (try stack.value(path)).?;
        try std.testing.expect(eql(node, stack.root));
    }

    try stack.push("properties");
    {
        const path = try stack.path(allocator);
        defer allocator.free(path);
        try std.testing.expectEqualStrings("#/properties", path);

        const node = (try stack.value(path)).?;
        try std.testing.expect(eql(node, stack.root.object.get("properties").?));
    }

    try stack.push("address");
    {
        const path = try stack.path(allocator);
        defer allocator.free(path);
        try std.testing.expectEqualStrings("#/properties/address", path);

        const node = (try stack.value(path)).?;
        try std.testing.expect(eql(node, stack.root.object.get("properties").?.object.get("address").?));
    }

    try stack.push("required");
    {
        const path = try stack.path(allocator);
        defer allocator.free(path);
        try std.testing.expectEqualStrings("#/properties/address/required", path);

        const node = (try stack.value(path)).?;
        try std.testing.expect(eql(node, stack.root.object.get("properties").?.object.get("address").?.object.get("required").?));
    }

    try stack.push("1");
    {
        const path = try stack.path(allocator);
        defer allocator.free(path);
        try std.testing.expectEqualStrings("#/properties/address/required/1", path);

        const node = (try stack.value(path)).?;
        try std.testing.expect(eql(node, stack.root.object.get("properties").?.object.get("address").?.object.get("required").?.array.items[1]));
    }

    stack.pop();
    {
        const path = try stack.path(allocator);
        defer allocator.free(path);
        try std.testing.expectEqualStrings("#/properties/address/required", path);
    }

    stack.pop();
    {
        const path = try stack.path(allocator);
        defer allocator.free(path);
        try std.testing.expectEqualStrings("#/properties/address", path);
    }
}
