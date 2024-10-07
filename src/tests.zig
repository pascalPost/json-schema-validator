const std = @import("std");
const jsonSchema = @import("schema.zig");

// TODO add JSON-Schema-Test_Suite (https://github.com/json-schema-org/JSON-Schema-Test-Suite/tree/main) as submodule

test "read test suite" {
    const allocator = std.testing.allocator;

    var file = try std.fs.cwd().openFile("JSON-Schema-Test-Suite/tests/draft7/type.json", .{});
    defer file.close();

    // Read the entire file content into memory
    const json_data = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(json_data);

    // Parse the JSON content
    const root = try std.json.parseFromSlice(std.json.Value, allocator, json_data, .{});
    defer root.deinit();

    try std.testing.expect(root.value == .array);

    for (root.value.array.items) |case| {
        try std.testing.expect(case == .object);

        // description
        std.debug.print("case: {s}\n", .{case.object.get("description").?.string});

        const schema = case.object.get("schema").?;

        // tests
        const tests = case.object.get("tests").?;

        try std.testing.expect(tests == .array);

        for (tests.array.items) |t| {
            try std.testing.expect(t == .object);
            std.debug.print("test: {s}\n", .{t.object.get("description").?.string});

            const data = t.object.get("data").?;

            const expected = t.object.get("valid").?.bool;

            const actual = jsonSchema.check_node(schema.object, data);

            try std.testing.expectEqual(expected, actual);
        }
    }
}
