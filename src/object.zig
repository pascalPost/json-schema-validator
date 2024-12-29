const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;
const Regex = @import("regex.zig").Regex;
const checkNode = @import("schema.zig").checkNode;

pub fn checks(node: std.json.ObjectMap, data: std.json.Value, stack: *Stack, errors: *Errors) !void {
    if (node.get("patternProperties")) |p| {
        std.debug.assert(p == .object);

        var pattern_it = p.object.iterator();
        while (pattern_it.next()) |entry| {
            const pattern = entry.key_ptr.*;
            const schema = entry.value_ptr.*;

            const regex = Regex.init(pattern);
            defer regex.deinit();

            var data_it = data.object.iterator();
            while (data_it.next()) |data_entry| {
                const key = data_entry.key_ptr.*;
                const value = data_entry.value_ptr.*;

                if (regex.match(key)) {
                    switch (schema) {
                        .null => {},
                        .bool => |b| {
                            if (!b) {
                                try errors.append(.{ .path = stack.path(), .msg = "Invalid object (pattern property matching schema false)" });
                            }
                        },
                        .object => |obj| {
                            try stack.push(key);
                            try checkNode(obj, value, stack, errors);
                            stack.pop();
                        },
                        else => unreachable,
                    }
                }
            }
        }
    }

    if (node.get("properties")) |p| {
        std.debug.assert(p == .object);

        var it = p.object.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            try stack.push(key);
            if (data.object.get(key)) |d| {
                try checkNode(value.object, d, stack, errors);
            }
            stack.pop();
        }
    }
}
