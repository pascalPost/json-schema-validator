const std = @import("std");

/// eql checks the equality of two std.json.Value
pub fn eql(a: std.json.Value, b: std.json.Value) bool {

    // numeric types are equal if the values are equal
    const a_opt_float: ?f64 = switch (a) {
        .integer => |i| @floatFromInt(i),
        .float => |f| f,
        .number_string => unreachable,
        else => null,
    };

    if (a_opt_float) |a_float| {
        const b_float: f64 = switch (b) {
            .integer => |i| @floatFromInt(i),
            .float => |f| f,
            .number_string => unreachable,
            else => return false,
        };

        if (a_float == b_float) return true else return false;
    }

    const Tag = std.meta.Tag(std.json.Value);
    if (@as(Tag, a) != @as(Tag, b)) return false;

    return switch (a) {
        .null => true, // b is checked for null above.
        .bool => a.bool == b.bool,
        .integer => a.integer == b.integer,
        .float => a.float == b.float,
        .number_string => std.mem.eql(u8, a.number_string, b.number_string),
        .string => std.mem.eql(u8, a.string, b.string),
        .array => blk: {
            if (a.array.items.len != b.array.items.len) break :blk false;
            for (a.array.items, b.array.items) |item_1, item_2| {
                if (!eql(item_1, item_2)) break :blk false;
            }
            break :blk true;
        },
        .object => blk: {
            if (a.object.count() != b.object.count()) break :blk false;
            var it = a.object.iterator();
            while (it.next()) |entry| {
                const key = entry.key_ptr.*;
                const value = entry.value_ptr.*;
                if (b.object.get(key)) |other_value| {
                    if (!eql(value, other_value)) break :blk false;
                } else break :blk false;
            }

            break :blk true;
        },
    };
}
