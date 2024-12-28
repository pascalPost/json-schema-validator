const std = @import("std");
const Regex = @import("regex.zig").Regex;

const testing = std.testing;

// TODO enhance schema logging (schema error, schema warning)
// TODO enhance validation errors (compare to other implementations)

pub const Stack = struct {
    data: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) Stack {
        return Stack{ .data = std.ArrayList(u8).init(allocator) };
    }

    pub fn deinit(self: Stack) void {
        self.data.deinit();
    }

    fn push(self: *Stack, p: []const u8) !void {
        try self.data.appendSlice(p);
    }

    fn pop(self: *Stack) void {
        _ = self.data.pop();
    }

    fn path(self: Stack) []const u8 {
        return self.data.items;
    }
};

const Error = struct {
    path: []const u8,
    msg: []const u8,
};

pub const Errors = struct {
    arena: std.heap.ArenaAllocator,
    data: std.ArrayListUnmanaged(Error) = .{},

    pub fn init(allocator: std.mem.Allocator) Errors {
        return .{
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: Errors) void {
        self.arena.deinit();
    }

    fn append(self: *Errors, err: Error) !void {
        try self.data.append(self.arena.allocator(), err);
    }

    pub fn empty(self: Errors) bool {
        return self.data.items.len == 0;
    }
};

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
                const int: i64 = @intFromFloat(data.float);
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

// https://json-schema.org/implementers/interfaces#two-argument-validation
pub fn checkNode(node: std.json.ObjectMap, data: std.json.Value, stack: *Stack, errors: *Errors) !void {
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

    switch (data) {
        .object => {
            if (node.get("patternProperties")) |p| {
                std.debug.assert(p == .object);

                var pattern_it = p.object.iterator();
                while (pattern_it.next()) |entry| {
                    const pattern = entry.key_ptr.*;
                    const schema = entry.value_ptr.*;

                    std.debug.assert(schema == .object);

                    const regex = Regex.init(pattern);
                    defer regex.deinit();

                    var data_it = data.object.iterator();
                    while (data_it.next()) |data_entry| {
                        const key = data_entry.key_ptr.*;
                        const value = data_entry.value_ptr.*;

                        if (regex.match(key)) {
                            try stack.push(key);
                            try checkNode(schema.object, value, stack, errors);
                            stack.pop();
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
        },
        else => {},
    }
}

pub fn check(allocator: std.mem.Allocator, schema: []const u8, data: []const u8) !Errors {
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
