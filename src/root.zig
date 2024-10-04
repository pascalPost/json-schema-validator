const std = @import("std");
const testing = std.testing;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
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
    
    const schema_parsed = try std.json.parseFromSlice(std.json.Value, allocator, schema, .{});
    defer schema_parsed.deinit();

    schema_parsed.value

    const root = schema_parsed.value;


    const data =
        \\{
        \\  "firstName": "John",
        \\  "lastName": "Doe",
        \\  "age": 21
        \\}
    ;
}
