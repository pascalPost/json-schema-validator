const std = @import("std");
const testing = std.testing;

fn check_object(node: std.json.ObjectMap, data: std.json.Value) bool {
    if (data != .object) {
        std.debug.panic("data type mismatch encountered", .{});
    }

    // check properties
    const properties = node.get("properties") orelse {
        std.debug.panic("schema error: missing properties of object", .{});
    };

    if (properties != .object) {
        std.debug.panic("schema error: properties value must be object", .{});
    }

    const prop_map = properties.object;

    // iterate over all data keys and see if they can be found in the properties
    var iterator = data.object.iterator();
    while (iterator.next()) |entry| {
        const schema_node = prop_map.get(entry.key_ptr.*) orelse {
            std.debug.panic("non-compliant data given: key {s} not in schema", .{entry.key_ptr.*});
        };

        if (schema_node != .object) {
            std.debug.panic("schema error: properties value must be object", .{});
        }

        if (!check_node(schema_node.object, entry.value_ptr.*)) {
            return false;
        }
    }

    return true;
}

fn check_integer(node: std.json.ObjectMap, data: std.json.Value) bool {
    switch (data) {
        .integer => {},
        .float => {
            // float with zero fractional part is an integer
            const int: i64 = @intFromFloat(data.float);
            const float: f64 = @floatFromInt(int);
            if (data.float != float) {
                std.log.err("non-compliant data given: wrong data type detected (expected: {s}, given: {s})", .{ "integer", "float with non-zero fractional part" });
                return false;
            }
        },
        else => {
            std.log.err("non-compliant data given: wrong data type detected (expected: {s}, given: {s})", .{ "integer", @tagName(data) });
            return false;
        },
    }

    // TODO do this only for debugging: this is only to check if all schema options are known and used.
    var iterator = node.iterator();
    while (iterator.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, "type")) {
            std.debug.assert(std.mem.eql(u8, entry.value_ptr.string, "integer"));
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

// https://json-schema.org/implementers/interfaces#two-argument-validation
pub fn check_node(node: std.json.ObjectMap, data: std.json.Value) bool {
    const node_type = node.get("type") orelse {
        std.debug.panic("missing type key for schema node", .{});
    };

    std.debug.assert(node_type == .string);

    if (std.mem.eql(u8, node_type.string, "object")) {
        return check_object(node, data);
    }

    if (std.mem.eql(u8, node_type.string, "string")) {
        if (data != .string) {
            std.debug.panic("non-compliant data given: wrong data type detected (expected: {s}, given: {s})", .{ "string", @tagName(data) });
        }
        return true;
    }

    if (std.mem.eql(u8, node_type.string, "integer")) {
        // match any number with a zero fractional part
        return check_integer(node, data);
    }

    std.debug.panic("unknown schema type: {s}", .{node_type.string});

    return false;
}

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

    try std.testing.expect(check_node(schema_parsed.value.object, data_parsed.value));
}
