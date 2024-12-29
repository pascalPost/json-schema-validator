const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;

pub fn checks(node: std.json.ObjectMap, data: std.json.Value, stack: *Stack, errors: *Errors) !void {
    if (node.get("type")) |t| {
        switch (t) {
            .string => {
                if (!checkType(data, t.string)) {
                    const msg = try std.fmt.allocPrint(errors.arena.allocator(), "Expected type {s} but found {s}", .{ t.string, @tagName(data) });
                    try errors.append(.{ .path = stack.path(), .msg = msg });
                }
            },
            .array => blk: {
                for (t.array.items) |item| {
                    if (item != .string) std.debug.panic("schema error: type key array values must be strings (found: {s})", .{@tagName(item)});
                    if (checkType(data, item.string)) break :blk;
                }

                // error message
                var buffer: [1024:0]u8 = undefined;
                var fba = std.heap.FixedBufferAllocator.init(&buffer);
                const allocator = fba.allocator();
                var len: usize = 0;
                for (t.array.items, 0..) |item, i| {
                    _ = try allocator.dupe(u8, item.string);
                    len += item.string.len;
                    if (i < t.array.items.len - 1) {
                        _ = try allocator.dupe(u8, ", ");
                        len += 2;
                    }
                }
                const msg = try std.fmt.allocPrint(errors.arena.allocator(), "Expected one of types [{s}] but found {s}", .{ buffer[0..len], @tagName(data) });
                try errors.append(.{ .path = stack.path(), .msg = msg });
            },
            else => {
                std.debug.panic("schema error: value of key \"type\" must be string or array (found: {s})", .{@tagName(t)});
            },
        }
    }

    if (node.get("enum")) |n| {
        switch (n) {
            .array => |a| {
                if (a.items.len == 0) std.log.warn("schema warning: the enum array should have at lease one elmenet, but found 0 ({s}).", .{stack.path()});
                // NOTE: we do not check that elements are unique
                if (!checkEnum(data, a.items)) try addEnumError(errors, stack.path(), data, n);
            },
            else => std.debug.panic("schema error: value of key \"enum\" must be array (found: {s})", .{@tagName(n)}),
        }
    }
}

fn checkType(data: std.json.Value, type_name: []const u8) bool {
    if (std.mem.eql(u8, type_name, "object")) {
        if (data == .object) return true else return false;
    }

    if (std.mem.eql(u8, type_name, "string")) {
        if (data == .string) return true else return false;
    }

    if (std.mem.eql(u8, type_name, "integer")) {
        // match any number with a zero fractional part
        switch (data) {
            .integer => return true,
            .float => {
                // float with zero fractional part is an integer
                const int: i64 = std.math.lossyCast(i64, data.float);
                const float: f64 = @floatFromInt(int);
                if (data.float == float) return true else return false;
            },
            else => return false,
        }
    }

    if (std.mem.eql(u8, type_name, "number")) {
        if (data == .integer or data == .float) return true else return false;
    }

    if (std.mem.eql(u8, type_name, "array")) {
        if (data == .array) return true else return false;
    }

    if (std.mem.eql(u8, type_name, "boolean")) {
        if (data == .bool) return true else return false;
    }

    if (std.mem.eql(u8, type_name, "null")) {
        if (data == .null) return true else return false;
    }

    std.debug.panic("schema error: unknown schema type: {s}", .{type_name});
}

fn checkEnum(data: std.json.Value, required_values: []const std.json.Value) bool {
    for (required_values) |value| {
        if (eql(data, value)) return true;
    }
    return false;
}

fn addEnumError(errors: *Errors, path: []const u8, invalid_value: std.json.Value, allowed_values: std.json.Value) !void {
    std.debug.assert(allowed_values == .array);

    var msg = std.ArrayList(u8).init(errors.arena.allocator());
    defer msg.deinit();

    const writer = msg.writer();
    try writer.writeAll("instance value (");
    try std.json.stringify(invalid_value, .{}, writer);
    try writer.writeAll(") not found in enum (possible values: ");
    try std.json.stringify(allowed_values, .{}, writer);
    try writer.writeAll(")");
    try errors.append(.{ .path = path, .msg = try msg.toOwnedSlice() });
}

/// eql checks the equality of two std.json.Value
fn eql(a: std.json.Value, b: std.json.Value) bool {
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
