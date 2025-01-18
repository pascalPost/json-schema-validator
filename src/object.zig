const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Errors = @import("errors.zig").Errors;
const Regex = @import("regex.zig").Regex;
const schema = @import("schema.zig");

fn checkMinOrMaxProperties(comptime check: enum { min, max }, min_or_max_properties: std.json.Value, data: std.json.Value, stack: *Stack, errors: *Errors) !void {
    const required: i64 = switch (min_or_max_properties) {
        .integer => |i| i,
        .float => |f| blk: {
            const cast: i64 = @intFromFloat(f);
            std.debug.assert(f == @as(f64, @floatFromInt(cast))); // check for integer value
            break :blk cast;
        },
        .number_string => unreachable,
        else => unreachable, // TODO add schema error
    };

    // must be a non-negative integer
    std.debug.assert(required >= 0);

    switch (check) {
        .min => {
            if (data.object.count() < required) {
                const msg = try std.fmt.allocPrint(errors.arena.allocator(), "Object has {d} properties, more than maximum of {d}", .{ data.object.count(), required });
                try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
            }
        },
        .max => {
            if (data.object.count() > required) {
                const msg = try std.fmt.allocPrint(errors.arena.allocator(), "Object has {d} properties, lenn than minimum of {d}", .{ data.object.count(), required });
                try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
            }
        },
    }
}

pub fn checks(node: std.json.ObjectMap, data: std.json.Value, stack: *Stack, errors: *Errors) !void {
    std.debug.assert(data == .object);

    if (node.get("maxProperties")) |maxProperties| try checkMinOrMaxProperties(.max, maxProperties, data, stack, errors);
    if (node.get("minProperties")) |minProperties| try checkMinOrMaxProperties(.min, minProperties, data, stack, errors);

    if (node.get("properties")) |properties| {
        std.debug.assert(properties == .object);

        var it = properties.object.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            try stack.pushPath("properties");
            if (data.object.get(key)) |d| {
                try schema.checks(value, d, stack, errors);
            }
            stack.pop();
        }
    }

    if (node.get("patternProperties")) |patternProperties| {
        std.debug.assert(patternProperties == .object);

        var pattern_it = patternProperties.object.iterator();
        while (pattern_it.next()) |entry| {
            const pattern = entry.key_ptr.*;
            const schema_val = entry.value_ptr.*;

            const regex = Regex.init(pattern);
            defer regex.deinit();

            var data_it = data.object.iterator();
            while (data_it.next()) |data_entry| {
                const key = data_entry.key_ptr.*;
                const value = data_entry.value_ptr.*;

                if (regex.match(key)) {
                    switch (schema_val) {
                        .null => {},
                        .bool => |b| {
                            if (!b) {
                                try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = "Invalid object (pattern property matching schema false)" });
                            }
                        },
                        .object => |obj| {
                            try stack.pushPath("patternProperties");
                            try schema.checksFromObject(obj, value, stack, errors);
                            stack.pop();
                        },
                        else => unreachable,
                    }
                }
            }
        }
    }

    if (node.get("additionalProperties")) |additionalProperties| {
        var data_it = data.object.iterator();
        data_loop: while (data_it.next()) |data_entry| {
            const key = data_entry.key_ptr.*;
            const value = data_entry.value_ptr.*;

            // check if data matches any entry in propeties
            if (node.get("properties")) |properties| {
                if (properties.object.contains(key)) continue;
            }

            // check if data matches any pattern in patternProperties
            if (node.get("patternProperties")) |patternProperties| {
                var pattern_it = patternProperties.object.iterator();
                while (pattern_it.next()) |entry| {
                    const pattern = entry.key_ptr.*;
                    const regex = Regex.init(pattern);
                    defer regex.deinit();

                    if (regex.match(key)) continue :data_loop;
                }
            }

            switch (additionalProperties) {
                .null => {},
                .bool => |b| {
                    if (!b) {
                        try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = "Invalid object (additional properties not allowed)" });
                    }
                },
                .object => |obj| {
                    try stack.pushPath("additionalProperties");
                    try schema.checksFromObject(obj, value, stack, errors);
                    stack.pop();
                },
                else => unreachable,
            }
        }
    }

    if (node.get("required")) |required| {
        std.debug.assert(required == .array);

        for (required.array.items) |element| {
            std.debug.assert(element == .string);
            // should also be unique, but we do not check this.

            if (!data.object.contains(element.string)) {
                const msg = try std.fmt.allocPrint(errors.arena.allocator(), "Object is missing the required property {s}", .{element.string});
                try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = msg });
            }
        }
    }
}
