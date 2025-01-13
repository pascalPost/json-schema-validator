const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;
const checkNode = @import("schema.zig").checkNode;
const eql = @import("value.zig").eql;

pub fn checks(node: std.json.ObjectMap, data: std.json.Value, stack: *Stack, errors: *Errors) !void {
    if (node.get("$ref")) |ref| {
        std.debug.assert(ref == .string);
        const ref_path = ref.string;

        std.debug.print("link: {s}\n", .{ref.string});

        // check the given ref
        if (ref_path[0] == '#') {
            // handle absolute path
            const node_ref = stack.root.object;

            try stack.push("$ref");

            try checkNode(node_ref, data, stack, errors);

            stack.pop();

            return;
        } else {
            std.debug.panic("unhandled reference type: {s}\n", .{ref_path});
        }
    }

    if (node.get("type")) |t| {
        switch (t) {
            .string => {
                if (!checkType(data, t.string)) {
                    const msg = try std.fmt.allocPrint(errors.arena.allocator(), "Expected type {s} but found {s}", .{ t.string, @tagName(data) });
                    try errors.append(.{ .path = try stack.path(errors.arena.allocator()), .msg = msg });
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
                try errors.append(.{ .path = try stack.path(errors.arena.allocator()), .msg = msg });
            },
            else => {
                std.debug.panic("schema error: value of key \"type\" must be string or array (found: {s})", .{@tagName(t)});
            },
        }
    }

    if (node.get("enum")) |n| {
        switch (n) {
            .array => |a| {
                if (a.items.len == 0) {
                    const path = try stack.path(errors.arena.allocator());
                    std.log.warn("schema warning: the enum array should have at lease one elmenet, but found 0 ({s}).", .{path});
                }
                // NOTE: we do not check that elements are unique
                if (!checkEnum(data, a.items)) try addEnumError(errors, try stack.path(errors.arena.allocator()), data, n);
            },
            else => std.debug.panic("schema error: value of key \"enum\" must be array (found: {s})", .{@tagName(n)}),
        }
    }

    if (node.get("const")) |n| {
        if (!eql(data, n)) try errors.append(.{ .path = try stack.path(errors.arena.allocator()), .msg = "Value does not match const definition" });
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
