const std = @import("std");
const testing = std.testing;

// TODO : split into two steps
// 1) validate the given schema file
// 2) validate the given data based on the validated schema

fn check_object(node: std.json.ObjectMap, data: std.json.Value, report: bool) std.mem.Allocator.Error!bool {
    if (data != .object) {
        if (report) {
            std.log.err("data type mismatch encountered", .{});
        }
        return false;
    }

    // check properties
    if (node.get("properties")) |properties| {
        const prop_map = properties.object;

        if (properties != .object) {
            std.debug.panic("schema error: properties value must be object", .{});
        }

        // iterate over all data keys and see if they can be found in the properties
        var iterator = data.object.iterator();
        while (iterator.next()) |entry| {
            const schema_node = prop_map.get(entry.key_ptr.*) orelse {
                std.debug.panic("non-compliant data given: key {s} not in schema", .{entry.key_ptr.*});
            };

            if (schema_node != .object) {
                std.debug.panic("schema error: properties value must be object", .{});
            }

            if (!try check_node(schema_node.object, entry.value_ptr.*)) {
                return false;
            }
        }
    }

    return true;
}

fn check_integer(node: std.json.ObjectMap, data: std.json.Value, report: bool) bool {
    switch (data) {
        .integer => {},
        .float => {
            // float with zero fractional part is an integer
            const int: i64 = @intFromFloat(data.float);
            const float: f64 = @floatFromInt(int);
            if (data.float != float) {
                if (report) {
                    std.log.err("non-compliant data given: wrong data type detected (expected: {s}, given: {s})", .{ "integer", "float with non-zero fractional part" });
                }
                return false;
            }
        },
        else => {
            if (report) {
                std.log.err("non-compliant data given: wrong data type detected (expected: {s}, given: {s})", .{ "integer", @tagName(data) });
            }
            return false;
        },
    }

    // TODO do this only for debugging: this is only to check if all schema options are known and used.
    var iterator = node.iterator();
    while (iterator.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, "type")) continue;

        if (std.mem.eql(u8, entry.key_ptr.*, "description")) continue;

        if (std.mem.eql(u8, entry.key_ptr.*, "minimum")) {
            if (entry.value_ptr.* != .integer) {
                std.debug.panic("schema error: integer minimum not given as interger", .{});
            }

            if (data.integer < entry.value_ptr.integer) {
                std.debug.panic("non-compliant data given: value {} violates specified minimum {}", .{ data.integer, entry.value_ptr.integer });
            }

            continue;
        }

        std.debug.panic("schema error: unknown integer key: {s}", .{entry.key_ptr.*});
    }

    return true;
}

fn check_number(node: std.json.ObjectMap, data: std.json.Value, report: bool) bool {
    // perhaps merge this with the check_integer (?)
    switch (data) {
        .integer, .float => {},
        else => {
            if (report) {
                std.log.err("non-compliant data given: wrong data type detected (expected: {s}, given: {s})", .{ "integer", @tagName(data) });
            }
            return false;
        },
    }

    // TODO do this only for debugging: this is only to check if all schema options are known and used.
    var iterator = node.iterator();
    while (iterator.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, "type")) {
            std.debug.assert(std.mem.eql(u8, entry.value_ptr.string, "number"));
            continue;
        }

        if (std.mem.eql(u8, entry.key_ptr.*, "description")) continue;

        if (std.mem.eql(u8, entry.key_ptr.*, "minimum")) {
            if (entry.value_ptr.* != .integer) {
                std.debug.panic("schema error: integer minimum not given as interger", .{});
            }

            if (data.integer < entry.value_ptr.integer) {
                std.debug.panic("non-compliant data given: value {} violates specified minimum {}", .{ data.integer, entry.value_ptr.integer });
            }

            continue;
        }

        std.debug.panic("schema error: unknown integer key: {s}", .{entry.key_ptr.*});
    }

    return true;
}

fn check_type(node: std.json.ObjectMap, data: std.json.Value, type_name: []const u8, report: bool) !bool {
    if (std.mem.eql(u8, type_name, "object")) {
        return try check_object(node, data, report);
    }

    if (std.mem.eql(u8, type_name, "string")) {
        if (data != .string) {
            if (report) {
                std.log.err("non-compliant data given: wrong data type detected (expected: {s}, given: {s})", .{ "string", @tagName(data) });
            }
            return false;
        }
        return true;
    }

    if (std.mem.eql(u8, type_name, "integer")) {
        // match any number with a zero fractional part
        return check_integer(node, data, report);
    }

    if (std.mem.eql(u8, type_name, "number")) {
        return check_number(node, data, report);
    }

    if (std.mem.eql(u8, type_name, "array")) {
        if (data != .array) {
            if (report) {
                std.log.err("non-compliant data given: wrong data type detected (expected: {s}, given: {s})", .{ "array", @tagName(data) });
            }
            return false;
        }

        return true;
    }

    if (std.mem.eql(u8, type_name, "boolean")) {
        if (data != .bool) {
            if (report) {
                std.log.err("non-compliant data given: wrong data type detected (expected: {s}, given: {s})", .{ "boolean", @tagName(data) });
            }
            return false;
        }

        return true;
    }

    if (std.mem.eql(u8, type_name, "null")) {
        if (data != .null) {
            std.log.err("non-compliant data given: wrong data type detected (expected: {s}, given: {s})", .{ "null", @tagName(data) });
            return false;
        }

        return true;
    }

    std.debug.panic("unknown schema type: {s}", .{type_name});
}

// https://json-schema.org/implementers/interfaces#two-argument-validation
pub fn check_node(node: std.json.ObjectMap, data: std.json.Value) !bool {
    const node_type = node.get("type") orelse {
        std.debug.panic("schema error: missing type key for schema node", .{});
    };

    switch (node_type) {
        .string => return check_type(node, data, node_type.string, true),
        .array => {
            for (node_type.array.items) |item| {
                if (item != .string) {
                    std.debug.panic("schema error: type key array values must be strings (found: {s})", .{@tagName(item)});
                }

                if (try check_type(node, data, item.string, false)) return true;
            }

            // error message
            var buffer: [1024:0]u8 = undefined;
            var fba = std.heap.FixedBufferAllocator.init(&buffer);
            const allocator = fba.allocator();

            var len: usize = 0;
            for (node_type.array.items, 0..) |item, i| {
                _ = try allocator.dupe(u8, item.string);
                len += item.string.len;
                if (i < node_type.array.items.len - 1) {
                    _ = try allocator.dupe(u8, ", ");
                    len += 2;
                }
            }

            std.log.err("non-compliant data given: data type did not match any of the required types (expected: [{s}], given: {s})", .{ buffer[0..len], @tagName(data) });

            return false;
        },
        else => {
            std.debug.panic("schema error: value of key \"type\" must be string or array (found: {s})", .{@tagName(node_type)});
        },
    }

    return false;
}

pub const std_options = .{ .log_level = .info };

test "example" {
    const allocator = std.testing.allocator;

    const schema =
        \\{
        \\  "$id": "https://example.com/person.schema.json",
        \\  "$schema": "https://json-schema.org/draft/2020-12/schema",
        \\  "title": "Person",
        \\  "type": "object",
        \\  "properties": {
        \\    "firstName": {
        \\      "type": "string",
        \\      "description": "The person's first name."
        \\    },
        \\    "lastName": {
        \\      "type": "string",
        \\      "description": "The person's last name."
        \\    },
        \\    "age": {
        \\      "description": "Age in years which must be equal to or greater than zero.",
        \\      "type": "integer",
        \\      "minimum": 0
        \\    }
        \\  }
        \\}
    ;

    const data =
        \\{
        \\  "firstName": "John",
        \\  "lastName": "Doe",
        \\  "age": 21
        \\}
    ;

    const schema_parsed = try std.json.parseFromSlice(std.json.Value, allocator, schema, .{});
    defer schema_parsed.deinit();

    const data_parsed = try std.json.parseFromSlice(std.json.Value, allocator, data, .{});
    defer data_parsed.deinit();

    std.debug.assert(schema_parsed.value == .object);
    std.debug.assert(data_parsed.value == .object);

    try std.testing.expect(try check_node(schema_parsed.value.object, data_parsed.value));
}
