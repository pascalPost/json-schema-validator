const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;
const Regex = @import("regex.zig").Regex;
const checkNode = @import("schema.zig").check;

pub fn checks(node: std.json.ObjectMap, data: []const u8, stack: *Stack, collect_errors: ?*Errors) !bool {
    if (node.get("maxLength")) |value| {
        if (lengthCheck(.max, value, data) catch {
            std.debug.panic("schema error: value of key \"maxLength\" must be integer (found: {s})", .{@tagName(value)});
        }) {
            if (collect_errors) |errors| {
                const msg = try std.fmt.allocPrint(errors.arena.allocator(), "String length {d} is longer than maximum of {}", .{ data.len, value });
                try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
            } else return false;
        }
    }

    if (node.get("minLength")) |value| {
        if (lengthCheck(.min, value, data) catch {
            std.debug.panic("schema error: value of key \"minLength\" must be integer (found: {s})", .{@tagName(value)});
        }) {
            if (collect_errors) |errors| {
                const msg = try std.fmt.allocPrint(errors.arena.allocator(), "String length {d} is smaller than minimum of {}", .{ data.len, value });
                try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
            } else return false;
        }
    }

    if (node.get("pattern")) |pattern| {
        switch (pattern) {
            .string => |p| {
                const re = Regex.init(p);
                defer re.deinit();
                if (!re.match(data)) {
                    if (collect_errors) |errors| {
                        const msg = try std.fmt.allocPrint(errors.arena.allocator(), "String does not match pattern \"{}\"", .{pattern});
                        try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
                    } else return false;
                }
            },
            else => {
                std.debug.panic("schema error: value of key \"pattern\" must be string (found: {s})", .{@tagName(pattern)});
            },
        }
    }

    return if (collect_errors) |errors| errors.empty() else true;
}

fn lengthCheck(comptime check: enum { min, max }, value: std.json.Value, data: []const u8) !bool {
    const required: i64 = switch (value) {
        .integer => |i| i,
        .float => |f| blk: {
            const i = std.math.lossyCast(i64, f);
            if (@as(f64, @floatFromInt(i)) != f) return error.SchemaError;
            break :blk i;
        },
        .number_string => unreachable,
        else => return error.SchemaError,
    };

    const len = std.unicode.utf8CountCodepoints(data) catch {
        // TODO enhance error handling
        std.debug.panic("utf8 error", .{});
    };

    switch (check) {
        .max => return len > required,
        .min => return len < required,
    }
}
