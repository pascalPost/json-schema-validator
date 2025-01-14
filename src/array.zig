const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;
const checkNode = @import("schema.zig").checkSchema;

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
                    const msg = try std.fmt.allocPrint(errors.arena.allocator(), "Expected empty array", .{});
                    try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
                }
            },
            else => unreachable,
        }
    }
}
