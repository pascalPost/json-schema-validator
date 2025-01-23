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

    if (node.get("anyOf")) |anyOf| {
        std.debug.assert(anyOf == .array);

        try stack.pushPath("anyOf");
        defer stack.pop();

        var valid = false;
        for (anyOf.array.items, 0..) |item, idx| {
            try stack.pushIndex(idx);
            defer stack.pop();

            if (try schema.checks(item, data, stack, null)) {
                valid = true;
                break;
            }
        }

        if (!valid) {
            if (collect_errors) |errors| {
                try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = "None of anyOf valid." });
            } else return false;
        }
    }

    if (node.get("oneOf")) |oneOf| {
        std.debug.assert(oneOf == .array);

        try stack.pushPath("oneOf");
        defer stack.pop();

        var valid_idx: ?usize = null;
        for (oneOf.array.items, 0..) |item, idx| {
            try stack.pushIndex(idx);
            defer stack.pop();

            if (try schema.checks(item, data, stack, null)) {
                if (valid_idx) |first_valid_idx| {
                    if (collect_errors) |errors| {
                        const msg = try std.fmt.allocPrint(errors.arena.allocator(), "oneOf valid for more than one schemas: stopped checking after valid schemas ({}, {}).", .{ first_valid_idx, idx });
                        try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
                    } else return false;
                }

                valid_idx = idx;
            }
        }

        if (valid_idx == null) {
            if (collect_errors) |errors| {
                try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = "None of oneOf valid." });
            } else return false;
        }
    }

    if (node.get("not")) |not| {
        std.debug.assert(not == .object or not == .bool);

        try stack.pushPath("not");
        defer stack.pop();

        if (try schema.checks(not, data, stack, null)) {
            if (collect_errors) |errors| {
                try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = "Failed required unsuccessfull validation against schema specified as \"not\"." });
            } else return false;
        }
    }

    return if (collect_errors) |errors| errors.empty() else true;
}
