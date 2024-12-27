const std = @import("std");
const testing = std.testing;

pub const Stack = struct {
    data: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) Stack {
        return Stack{ .data = std.ArrayList(u8).init(allocator) };
    }

    pub fn deinit(self: Stack) void {
        self.data.deinit();
    }

    fn push(self: *Stack, p: []const u8) !void {
        try self.data.append(p);
    }

    fn pop(self: *Stack) void {
        _ = self.data.pop();
    }

    fn path(self: Stack) []const u8 {
        return self.data.items;
    }
};

// const SchemaErrorType = enum {
//     typeMismatch,
//     missingRequiredProperty,
//     notAllowedAdditionalProperty,
//     patternMismatch,
//     numberOutOfRange,
//     ArrayLengthViolation,
//     enumMismatch,
//     formatViolation,
//     invalidItemsInArray,
//     dependencyError,
//     StringLengthViolation,
//     OneOfViolation,
//     AnyOfViolation,
//     AllOfViolation,
// };
//
// fn get_error_message(errorTag: SchemaErrorType) []const u8 {
//     return switch (errorTag) {
//         .typeMismatch => "Expected type {s} but found {s}",
//         else => unreachable,
//     };
// }

const Error = struct {
    path: []const u8,
    msg: []const u8,
};

pub const Errors = std.ArrayList(Error);

fn createErrorTypeMismatch(allocator: std.mem.Allocator, path: []const u8, expected: []const u8, found: []const u8) !Error {
    const msg = try std.fmt.allocPrint(allocator, "Expected type {s} but found {s}", .{ expected, found });
    return .{ .path = path, .msg = msg };
}

fn createErrorTypeArrayMismatch(allocator: std.mem.Allocator, path: []const u8) Error {
    // // error message
    // var buffer: [1024:0]u8 = undefined;
    // var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // const allocator = fba.allocator();

    // var len: usize = 0;
    // for (t.array.items, 0..) |item, i| {
    //     _ = try allocator.dupe(u8, item.string);
    //     len += item.string.len;
    //     if (i < t.array.items.len - 1) {
    //         _ = try allocator.dupe(u8, ", ");
    //         len += 2;
    //     }
    // }

    // std.log.warn("non-compliant data given: data type did not match any of the required types (expected: [{s}], given: {s})", .{ buffer[0..len], @tagName(data) });

    _ = allocator;

    // return .{ .path = path, .msg = try std.fmt.allocPrint(allocator, "Expected type {s} but found {s}", .{ expected, found }) };
    return .{ .path = path, .msg = "" };
}

/// check the type of a single node. Set report to false if multiple types are to be checked.
fn checkSingleType(data: std.json.Value, type_name: []const u8, errors: ?*Errors, stack: Stack) !void {
    if (std.mem.eql(u8, type_name, "object")) {
        if (data != .object) {
            if (errors) |e| {
                try e.append(try createErrorTypeMismatch(e.allocator, stack.path(), "object", @tagName(data)));
            }
        }
        return;
    }

    if (std.mem.eql(u8, type_name, "string")) {
        if (data != .string) {
            if (errors) |e| {
                try e.append(try createErrorTypeMismatch(e.allocator, stack.path(), "string", @tagName(data)));
            }
        }
        return;
    }

    if (std.mem.eql(u8, type_name, "integer")) {
        // match any number with a zero fractional part
        switch (data) {
            .integer => {},
            .float => {
                // float with zero fractional part is an integer
                const int: i64 = @intFromFloat(data.float);
                const float: f64 = @floatFromInt(int);
                if (data.float != float) {
                    if (errors) |e| {
                        try e.append(try createErrorTypeMismatch(e.allocator, stack.path(), "integer", "float"));
                    }
                }
            },
            else => {
                if (errors) |e| {
                    try e.append(try createErrorTypeMismatch(e.allocator, stack.path(), "integer", @tagName(data)));
                }
            },
        }
        return;
    }

    if (std.mem.eql(u8, type_name, "number")) {
        if (data != .integer and data != .float) {
            if (errors) |e| {
                try e.append(try createErrorTypeMismatch(e.allocator, stack.path(), "number", @tagName(data)));
            }
        }
        return;
    }

    if (std.mem.eql(u8, type_name, "array")) {
        if (data != .array) {
            if (errors) |e| {
                try e.append(try createErrorTypeMismatch(e.allocator, stack.path(), "array", @tagName(data)));
            }
        }
        return;
    }

    if (std.mem.eql(u8, type_name, "boolean")) {
        if (data != .bool) {
            if (errors) |e| {
                try e.append(try createErrorTypeMismatch(e.allocator, stack.path(), "boolean", @tagName(data)));
            }
        }
        return;
    }

    if (std.mem.eql(u8, type_name, "null")) {
        if (data != .null) {
            if (errors) |e| {
                try e.append(try createErrorTypeMismatch(e.allocator, stack.path(), "null", @tagName(data)));
            }
        }
        return;
    }

    std.debug.panic("schema error: unknown schema type: {s}", .{type_name});
}

// https://json-schema.org/implementers/interfaces#two-argument-validation
pub fn checkNode(node: std.json.ObjectMap, data: std.json.Value, stack: *Stack, errors: *Errors) !void {
    if (node.get("type")) |t| {
        switch (t) {
            .string => try checkSingleType(data, t.string, errors, stack.*),
            .array => {
                unreachable;
                // for (t.array.items) |item| {
                //     if (item != .string) {
                //         std.debug.panic("schema error: type key array values must be strings (found: {s})", .{@tagName(item)});
                //     }
                //
                //     try check_single_type(node, data, item.string, null)) return true;
                // }

                // // error message
                // var buffer: [1024:0]u8 = undefined;
                // var fba = std.heap.FixedBufferAllocator.init(&buffer);
                // const allocator = fba.allocator();
                //
                // var len: usize = 0;
                // for (t.array.items, 0..) |item, i| {
                //     _ = try allocator.dupe(u8, item.string);
                //     len += item.string.len;
                //     if (i < t.array.items.len - 1) {
                //         _ = try allocator.dupe(u8, ", ");
                //         len += 2;
                //     }
                // }
                //
                // std.log.warn("non-compliant data given: data type did not match any of the required types (expected: [{s}], given: {s})", .{ buffer[0..len], @tagName(data) });
            },
            else => {
                std.debug.panic("schema error: value of key \"type\" must be string or array (found: {s})", .{@tagName(t)});
            },
        }
    }
}

fn check(allocator: std.mem.Allocator, schema: []const u8, data: []const u8) !Errors {
    const schema_parsed = try std.json.parseFromSlice(std.json.Value, allocator, schema, .{});
    defer schema_parsed.deinit();

    const data_parsed = try std.json.parseFromSlice(std.json.Value, allocator, data, .{});
    defer data_parsed.deinit();

    std.debug.assert(schema_parsed.value == .object);
    std.debug.assert(data_parsed.value == .object);

    var stack = Stack.init(allocator);
    defer stack.deinit();

    var errors = Errors.init(allocator);

    try checkNode(schema_parsed.value.object, data_parsed.value, &stack, &errors);

    return errors;
}

// test "basic example" {
//     const schema =
//         \\{
//         \\  "$id": "https://example.com/person.schema.json",
//         \\  "$schema": "https://json-schema.org/draft/2020-12/schema",
//         \\  "title": "Person",
//         \\  "type": "object",
//         \\  "properties": {
//         \\    "firstName": {
//         \\      "type": "string",
//         \\      "description": "The person's first name."
//         \\    },
//         \\    "lastName": {
//         \\      "type": "string",
//         \\      "description": "The person's last name."
//         \\    },
//         \\    "age": {
//         \\      "description": "Age in years which must be equal to or greater than zero.",
//         \\      "type": "integer",
//         \\      "minimum": 0
//         \\    }
//         \\  }
//         \\}
//     ;
//
//     const data =
//         \\{
//         \\  "firstName": "John",
//         \\  "lastName": "Doe",
//         \\  "age": 21
//         \\}
//     ;
//
//     const errors = try check(std.testing.allocator, schema, data);
//     defer errors.deinit();
//
//     try std.testing.expect(errors.items.len == 0);
// }
//
// test "complex object with nested properties" {
//     const schema =
//         \\{
//         \\  "$id": "https://example.com/complex-object.schema.json",
//         \\  "$schema": "https://json-schema.org/draft/2020-12/schema",
//         \\  "title": "Complex Object",
//         \\  "type": "object",
//         \\  "properties": {
//         \\    "name": {
//         \\      "type": "string"
//         \\    },
//         \\    "age": {
//         \\      "type": "integer",
//         \\      "minimum": 0
//         \\    },
//         \\    "address": {
//         \\      "type": "object",
//         \\      "properties": {
//         \\        "street": {
//         \\          "type": "string"
//         \\        },
//         \\        "city": {
//         \\          "type": "string"
//         \\        },
//         \\        "state": {
//         \\          "type": "string"
//         \\        },
//         \\        "postalCode": {
//         \\          "type": "string",
//         \\          "pattern": "\\d{5}"
//         \\        }
//         \\      },
//         \\      "required": ["street", "city", "state", "postalCode"]
//         \\    },
//         \\    "hobbies": {
//         \\      "type": "array",
//         \\      "items": {
//         \\        "type": "string"
//         \\      }
//         \\    }
//         \\  },
//         \\  "required": ["name", "age"]
//         \\}
//     ;
//
//     const data =
//         \\{
//         \\  "name": "John Doe",
//         \\  "age": 25,
//         \\  "address": {
//         \\    "street": "123 Main St",
//         \\    "city": "New York",
//         \\    "state": "NY",
//         \\    "postalCode": "10001"
//         \\  },
//         \\  "hobbies": ["reading", "running"]
//         \\}
//     ;
//
//     const errors = try check(std.testing.allocator, schema, data);
//     defer errors.deinit();
//
//     try std.testing.expect(errors.items.len == 0);
// }

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
