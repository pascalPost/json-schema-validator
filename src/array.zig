const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;
const checkNode = @import("schema.zig").checkNode;

pub fn checks(node: std.json.ObjectMap, data: std.json.Value, stack: *Stack, errors: *Errors) !void {
    std.debug.assert(data == .array); // otherwise we could just return

    if (node.get("items")) |items| {
        switch (items) {
            .object => |object| {
                for (data.array.items, 0..) |item, index| {
                    try stack.pushIndex(index);
                    try checkNode(object, item, stack, errors);
                    stack.pop();
                }
            },
            .array => {
                unreachable;
            },
            else => unreachable,
        }
    }
}
