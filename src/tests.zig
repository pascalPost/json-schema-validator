const std = @import("std");
const jsonSchema = @import("schema.zig");

pub const std_options = struct {
    pub const log_level = .err;
};

fn run_test(expected: bool, actual: bool, case_name: []const u8, test_name: []const u8, schema: std.json.Value, data: std.json.Value) !void {
    if (expected != actual) {
        const schema_str = try std.json.stringifyAlloc(std.testing.allocator, schema, .{});
        defer std.testing.allocator.free(schema_str);

        const data_str = try std.json.stringifyAlloc(std.testing.allocator, data, .{});
        defer std.testing.allocator.free(data_str);

        std.debug.print(
            \\case: {s}
            \\test: {s}
            \\============== schema: ===============
            \\{s}
            \\=============== data: ================
            \\{s}
            \\============= expected: ==============
            \\{}
            \\============== actual: ===============
            \\{}
            \\======================================
        , .{ case_name, test_name, schema_str, data_str, expected, actual });
        return error.failedTest;
    }
}

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

    for (root.value.array.items) |case| {
        const case_name = case.object.get("description").?.string;
        const schema = case.object.get("schema").?;
        const tests = case.object.get("tests").?;

        for (tests.array.items) |t| {
            const test_name = t.object.get("description").?.string;
            const data = t.object.get("data").?;
            const expected = t.object.get("valid").?.bool;

            var stack = jsonSchema.Stack.init(allocator);
            defer stack.deinit();

            var errors = jsonSchema.Errors.init(allocator);
            defer errors.deinit();

            try jsonSchema.check_node(schema.object, data, &stack, &errors);

            const actual = errors.items.len > 0;

            try run_test(expected, actual, case_name, test_name, schema, data);
        }
    }
}
