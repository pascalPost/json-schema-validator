const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;
const checkNode = @import("schema.zig").checkSchema;
const numeric = @import("numeric.zig");
const eql = @import("value.zig").eql;

pub fn checks(node: std.json.ObjectMap, data: std.json.Value, stack: *Stack, errors: *Errors) !void {
    std.debug.assert(data == .array); // otherwise we could just return

    if (node.get("items")) |items| {
        switch (items) {
            .object => {
                for (data.array.items, 0..) |item, index| {
                    try stack.pushIndex(index);
                    try checkNode(items, item, stack, errors);
                    stack.pop();
                }
            },
            .array => |array| {
                const len = @min(array.items.len, data.array.items.len);

                try stack.pushPath("items");
                defer stack.pop();

                for (0..len) |index| {
                    const schema = array.items[index];
                    const item = data.array.items[index];

                    try stack.pushIndex(index);
                    try checkNode(schema, item, stack, errors);
                    stack.pop();
                }
            },
            .bool => |b| {
                if (b == true) return;

                if (data.array.items.len != 0) {
                    try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = "Expected empty array" });
                }
            },
            else => unreachable,
        }
    }

    if (node.get("additionalItems")) |additionalItems| {
        if (node.get("items")) |items| {
            switch (items) {
                .array => |array| {
                    if (data.array.items.len > array.items.len) {
                        for (array.items.len..data.array.items.len) |index| {
                            try stack.pushIndex(index);
                            try checkNode(additionalItems, data.array.items[index], stack, errors);
                            stack.pop();
                        }
                    }
                },
                else => {},
            }
        }
    }

    if (node.get("maxItems")) |maxItems| {
        const count = switch (maxItems) {
            .integer => |i| i,
            .float => |f| numeric.floatToInteger(f).?,
            else => unreachable,
        };

        std.debug.assert(count > 0);

        if (data.array.items.len > count) {
            const msg = try std.fmt.allocPrint(errors.arena.allocator(), "Array (items: {}) exceeds maxItems {}", .{ data.array.items.len, count });
            try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
        }
    }

    if (node.get("minItems")) |minItems| {
        const count = switch (minItems) {
            .integer => |i| i,
            .float => |f| numeric.floatToInteger(f).?,
            else => unreachable,
        };

        std.debug.assert(count > 0);

        if (data.array.items.len < count) {
            const msg = try std.fmt.allocPrint(errors.arena.allocator(), "Array (items: {}) less than minItems {}", .{ data.array.items.len, count });
            try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
        }
    }

    if (node.get("uniqueItems")) |uniqueItems| blk: {
        std.debug.assert(uniqueItems == .bool);
        if (uniqueItems.bool == false or data.array.items.len == 0) break :blk;

        // NOTE for now we use a brute force check; a check based on a hash table
        // might be more efficient for large arrays.

        const items = data.array.items;

        var head: usize = 0;
        while (head < items.len - 1) : (head += 1) {
            const item = items[head];
            for (head + 1..items.len) |index| {
                if (eql(item, items[index])) {
                    const msg = try std.fmt.allocPrint(errors.arena.allocator(), "Array contains non-unique items ({} and {}) ", .{ head, index });
                    try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
                }
            }
        }
    }
}
