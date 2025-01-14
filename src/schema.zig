const std = @import("std");
pub const Stack = @import("stack.zig").Stack;
pub const Errors = @import("errors.zig").Errors;
const generic = @import("generic.zig");
const numeric = @import("numeric.zig");
const object = @import("object.zig");
const string = @import("string.zig");
const array = @import("array.zig");

const testing = std.testing;

const ErrorSet = error{} || std.mem.Allocator.Error || std.fmt.ParseIntError;

pub fn checkSchemaObject(schema: std.json.ObjectMap, data: std.json.Value, stack: *Stack, errors: *Errors) ErrorSet!void {
    try generic.checks(schema, data, stack, errors);

    switch (data) {
        .integer => |i| try numeric.checks(i64, schema, i, stack, errors),
        .float => |f| try numeric.checks(f64, schema, f, stack, errors),
        .number_string => unreachable,
        .string => |str| try string.checks(schema, str, stack, errors),
        .object => try object.checks(schema, data, stack, errors),
        .array => try array.checks(schema, data, stack, errors),
        else => {},
    }
}

pub fn checkSchema(schema: std.json.Value, data: std.json.Value, stack: *Stack, errors: *Errors) ErrorSet!void {
    switch (schema) {
        .bool => |b| {
            if (b == false and data != .null) {
                try errors.append(.{ .path = try stack.constructPath(errors.arena.allocator()), .msg = "false boolean schema expects empty data." });
            }
        },
        .object => |schema_object| {
            try checkSchemaObject(schema_object, data, stack, errors);
        },
        else => {
            std.debug.panic("Encountered invalid schema: A JSON Schema MUST be an object or a boolean.", .{});
        },
    }
}

pub fn check(allocator: std.mem.Allocator, schema: []const u8, data: []const u8) !Errors {
    const schema_parsed = try std.json.parseFromSlice(std.json.Value, allocator, schema, .{});
    defer schema_parsed.deinit();

    const data_parsed = try std.json.parseFromSlice(std.json.Value, allocator, data, .{});
    defer data_parsed.deinit();

    std.debug.assert(data_parsed.value == .object);

    const stack_capacity = 100;

    var stack = try Stack.init(allocator, schema_parsed.value, stack_capacity);
    defer stack.deinit();

    var errors = Errors.init(allocator);

    try checkSchema(schema_parsed.value, data_parsed.value, &stack, &errors);

    return errors;
}

test "basic example" {
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

    const errors = try check(std.testing.allocator, schema, data);
    defer errors.deinit();

    try std.testing.expect(errors.empty());
}

test "complex object with nested properties" {
    const schema =
        \\{
        \\  "$id": "https://example.com/complex-object.schema.json",
        \\  "$schema": "https://json-schema.org/draft/2020-12/schema",
        \\  "title": "Complex Object",
        \\  "type": "object",
        \\  "properties": {
        \\    "name": {
        \\      "type": "string"
        \\    },
        \\    "age": {
        \\      "type": "integer",
        \\      "minimum": 0
        \\    },
        \\    "address": {
        \\      "type": "object",
        \\      "properties": {
        \\        "street": {
        \\          "type": "string"
        \\        },
        \\        "city": {
        \\          "type": "string"
        \\        },
        \\        "state": {
        \\          "type": "string"
        \\        },
        \\        "postalCode": {
        \\          "type": "string",
        \\          "pattern": "\\d{5}"
        \\        }
        \\      },
        \\      "required": ["street", "city", "state", "postalCode"]
        \\    },
        \\    "hobbies": {
        \\      "type": "array",
        \\      "items": {
        \\        "type": "string"
        \\      }
        \\    }
        \\  },
        \\  "required": ["name", "age"]
        \\}
    ;

    const data =
        \\{
        \\  "name": "John Doe",
        \\  "age": 25,
        \\  "address": {
        \\    "street": "123 Main St",
        \\    "city": "New York",
        \\    "state": "NY",
        \\    "postalCode": "10001"
        \\  },
        \\  "hobbies": ["reading", "running"]
        \\}
    ;

    const errors = try check(std.testing.allocator, schema, data);
    defer errors.deinit();

    try std.testing.expect(errors.empty());
}

// test "error in array" {
//     const schema =
//         \\{
//         \\  "type": "object",
//         \\  "properties": {
//         \\    "people": {
//         \\      "type": "array",
//         \\      "items": {
//         \\        "type": "object",
//         \\        "properties": {
//         \\          "name": { "type": "string" },
//         \\          "age": { "type": "integer" }
//         \\        },
//         \\        "required": ["name", "age"]
//         \\      }
//         \\    }
//         \\  }
//         \\}
//     ;

//     const data =
//         \\{
//         \\  "people": [
//         \\    {
//         \\      "name": "John",
//         \\      "age": 30
//         \\    },
//         \\    {
//         \\      "name": "Jane",
//         \\      "age": "twenty-five"
//         \\    },
//         \\    {
//         \\      "name": "Doe",
//         \\      "age": 40
//         \\    }
//         \\  ]
//         \\}
//     ;

//     const errors = try check(std.testing.allocator, schema, data);
//     defer errors.deinit();

//     try std.testing.expect(errors.items.len == 1);
//     try std.testing.expect(std.mem.eql(u8, errors.items[0].msg, "Expected type integer but found string"));
//     try std.testing.expect(std.mem.eql(u8, errors.items[0].path, "/people/1/age"));
// }
