const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;
const schema = @import("schema.zig");

pub fn checks(node: std.json.ObjectMap, data: std.json.Value, stack: *Stack, collect_errors: ?*Errors) !bool {
    if (node.get("if")) |if_schema| {
        if (try schema.checks(if_schema, data, stack, null)) {
            if (node.get("then")) |then_schema| {
                if (!try schema.checks(then_schema, data, stack, null)) {
                    if (collect_errors) |errors| {
                        try stack.pushPath("then");
                        defer stack.pop();
                        try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = "Invalid for \"then\" condition." });
                    } else return false;
                }
            }
        } else {
            if (node.get("else")) |else_schema| {
                if (!try schema.checks(else_schema, data, stack, null)) {
                    if (collect_errors) |errors| {
                        try stack.pushPath("else");
                        defer stack.pop();
                        try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = "Invalid for \"else\" condition" });
                    } else return false;
                }
            }
        }
    }

    return true;
}
