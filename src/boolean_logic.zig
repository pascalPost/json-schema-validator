const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;
const schema = @import("schema.zig");

pub fn checks(node: std.json.ObjectMap, data: std.json.Value, stack: *Stack, collect_errors: ?*Errors) !bool {
    if (node.get("allOf")) |allOf| {
        std.debug.assert(allOf == .array);

        try stack.pushPath("allOf");
        defer stack.pop();

        for (allOf.array.items, 0..) |item, idx| {
            try stack.pushIndex(idx);
            defer stack.pop();

            if (!try schema.checks(item, data, stack, null)) {
                if (collect_errors) |errors| {
                    const msg = try std.fmt.allocPrint(errors.arena.allocator(), "allOf invalid for item index {}.", .{idx});
                    try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
                } else return false;
            }
        }
    }

    return true;
}
