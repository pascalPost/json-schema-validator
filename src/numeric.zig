const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;

pub fn checks(comptime T: type, node: std.json.ObjectMap, data_value: T, stack: *Stack, errors: *Errors) !void {
    const value: f64 = switch (T) {
        i64 => @floatFromInt(data_value),
        f64 => data_value,
        else => @compileError("unknown type."),
    };

    try checkExtrema(node, value, stack, errors);
    try checkMultipleOf(node, value, stack, errors);
}

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

fn checkExtrema(node: std.json.ObjectMap, data_value: f64, stack: *Stack, errors: *Errors) !void {
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
                try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
            }
        }
    }
}

fn isMultipleOf(n: f64, m: f64) bool {
    const res = n / m;
    return @as(f64, @floatFromInt(std.math.lossyCast(i64, res))) == res;
}

fn checkMultipleOf(node: std.json.ObjectMap, data_value: f64, stack: *Stack, errors: *Errors) !void {
    if (node.get("multipleOf")) |value| {
        const multiple_value: f64 = switch (value) {
            .integer => |e_i| @floatFromInt(e_i),
            .float => |e_f| e_f,
            .number_string => unreachable,
            else => std.debug.panic("schema error: value of key \"multipleOf\" must be number (found: {s})", .{@tagName(value)}),
        };

        if (multiple_value <= 0) {
            std.debug.panic("schema error: value of key \"multipleOf\" must be greater than 0", .{});
        }

        if (!isMultipleOf(data_value, multiple_value)) {
            const msg = try std.fmt.allocPrint(errors.arena.allocator(), "Not a multiple of {} (found {})", .{ multiple_value, data_value });
            try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
        }
    }
}
