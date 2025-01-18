const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;
const schema = @import("schema.zig");

pub fn checks(node: std.json.ObjectMap, data: std.json.Value, stack: *Stack, errors: *Errors) !void {
    if (node.get("allOf")) |allOf| {
        std.debug.assert(allOf == .array);

        try stack.pushPath("allOf");

        for (allOf.array.items, 0..) |item, idx| {
            try stack.pushIndex(idx);
            try schema.checks(item, data, stack, errors);
            stack.pop();
        }

        stack.pop();
    }
}
