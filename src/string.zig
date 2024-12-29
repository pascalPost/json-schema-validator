const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;
const Regex = @import("regex.zig").Regex;
const checkNode = @import("schema.zig").checkNode;

pub fn checks(node: std.json.ObjectMap, data: []const u8, stack: *Stack, errors: *Errors) !void {
    if (node.get("maxLength")) |value| {
        const maxLength: i64 = switch (value) {
            .integer => |i| i,
            .float => |f| blk: {
                const i = std.math.lossyCast(i64, f);
                if (@as(f64, @floatFromInt(i)) != f) {
                    std.debug.panic("schema error: value of key \"maxLength\" must be integer (found: {s})", .{@tagName(value)});
                }
                break :blk i;
            },
            .number_string => unreachable,
            else => std.debug.panic("schema error: value of key \"maxLength\" must be integer (found: {s})", .{@tagName(value)}),
        };

        const len = std.unicode.utf8CountCodepoints(data) catch {
            // TODO enhance error handling
            std.debug.panic("utf8 error", .{});
        };

        if (len > maxLength) {
            const msg = try std.fmt.allocPrint(errors.arena.allocator(), "String length {d} is longer than maximum of {d}", .{ data.len, maxLength });
            try errors.append(.{ .path = stack.path(), .msg = msg });
        }
    }
}
