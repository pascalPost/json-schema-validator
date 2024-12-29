const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;

fn checkMaximum(v: f64, e: f64) bool {
    return v > e;
}

fn checkMinimum(v: f64, e: f64) bool {
    return v < e;
}

fn checkExclusiveMaximum(v: f64, e: f64) bool {
    return v >= e;
}

fn checkExclusiveMinimum(v: f64, e: f64) bool {
    return v <= e;
}

const allChecks = [_]struct { name: []const u8, check: *const fn (f64, f64) bool }{
    .{ .name = "maximum", .check = checkMaximum },
    .{ .name = "minimum", .check = checkMinimum },
    .{ .name = "exclusiveMaximum", .check = checkExclusiveMaximum },
    .{ .name = "exclusiveMinimum", .check = checkExclusiveMinimum },
};

pub fn extremaChecks(node: std.json.ObjectMap, data_value: f64, stack: *Stack, errors: *Errors) !void {
    for (allChecks) |c| {
        if (node.get(c.name)) |value| {
            const extreme_value: f64 = switch (value) {
                .integer => |e_i| @floatFromInt(e_i),
                .float => |e_f| e_f,
                .number_string => unreachable,
                else => std.debug.panic("schema error: value of key \"{s}\" must be number (found: {s})", .{ c.name, @tagName(value) }),
            };

            if (c.check(data_value, extreme_value)) {
                const msg = try std.fmt.allocPrint(errors.arena.allocator(), "Exceeds {s} {} (found {})", .{ c.name, extreme_value, data_value });
                try errors.append(.{ .path = stack.path(), .msg = msg });
            }
        }
    }
}
