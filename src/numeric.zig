const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;

pub fn checks(comptime T: type, node: std.json.ObjectMap, data_value: T, stack: *Stack, collect_errors: ?*Errors) !bool {
    const value: f64 = switch (T) {
        i64 => @floatFromInt(data_value),
        f64 => data_value,
        else => @compileError("unknown type."),
    };

    const valid = try checkExtrema(node, value, stack, collect_errors);
    if (!valid and collect_errors == null) return false;

    return try checkMultipleOf(node, value, stack, collect_errors) and valid;
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

fn checkExtrema(node: std.json.ObjectMap, data_value: f64, stack: *Stack, collect_errors: ?*Errors) !bool {
    var valid = true;
    for (allChecks) |c| {
        if (node.get(c.name)) |value| {
            const extreme_value: f64 = switch (value) {
                .integer => |e_i| @floatFromInt(e_i),
                .float => |e_f| e_f,
                .number_string => unreachable,
                else => std.debug.panic("schema error: value of key \"{s}\" must be number (found: {s})", .{ c.name, @tagName(value) }),
            };

            valid = !c.check(data_value, extreme_value) and valid;

            if (!valid) {
                if (collect_errors) |errors| {
                    const msg = try std.fmt.allocPrint(errors.arena.allocator(), "Exceeds {s} {} (found {})", .{ c.name, extreme_value, data_value });
                    try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
                } else return false;
            }
        }
    }

    return valid;
}

fn isMultipleOf(n: f64, m: f64) bool {
    const res = n / m;
    return @as(f64, @floatFromInt(std.math.lossyCast(i64, res))) == res;
}

fn checkMultipleOf(node: std.json.ObjectMap, data_value: f64, stack: *Stack, collect_errors: ?*Errors) !bool {
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
            if (collect_errors) |errors| {
                const msg = try std.fmt.allocPrint(errors.arena.allocator(), "Not a multiple of {} (found {})", .{ multiple_value, data_value });
                try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
            } else return false;
        }
    }

    return true;
}

pub fn floatToInteger(float: f64) ?i64 {
    const int: i64 = std.math.lossyCast(i64, float);
    const f: f64 = @floatFromInt(int);
    if (float != f) return null;
    return int;
}
