const std = @import("std");

// TODO add JSON-Schema-Test_Suite (https://github.com/json-schema-org/JSON-Schema-Test-Suite/tree/main) as submodule

test "read test suite" {
    const allocator = std.testing.allocator;

    var file = try std.fs.cwd().openFile("tests/JSON-Schema-Test-Suite/tests/draft7/type.json", .{});
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

        // section description

        const schema = case.object.get("schema").?;

        // section tests
        const tests = case.object.get("tests").?;

        try std.testing.expect(tests == .array);

        for (tests.array.items) |t| {
            try std.testing.expect(t == .object);
            std.debug.print("test: {s}\n", .{t.object.get("description").?.string});
        }
    }
}
