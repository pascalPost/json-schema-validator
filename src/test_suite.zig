const std = @import("std");
const jsonSchema = @import("schema.zig");

pub const std_options = struct {
    pub const log_level = .err;
};

fn runTest(expected: bool, actual: bool, file: []const u8, case_name: []const u8, test_name: []const u8, mode: []const u8, schema: std.json.Value, data: std.json.Value) !void {
    if (expected != actual) {
        const schema_str = try std.json.stringifyAlloc(std.testing.allocator, schema, .{});
        defer std.testing.allocator.free(schema_str);

        const data_str = try std.json.stringifyAlloc(std.testing.allocator, data, .{});
        defer std.testing.allocator.free(data_str);

        std.debug.print(
            \\
            \\file: {s}
            \\case: {s}
            \\test: {s}
            \\mode: {s}
            \\============== schema: ===============
            \\{s}
            \\=============== data: ================
            \\{s}
            \\============= expected: ==============
            \\{}
            \\============== actual: ===============
            \\{}
            \\======================================
        , .{ file, case_name, test_name, mode, schema_str, data_str, expected, actual });
        return error.failedTest;
    }
}

test "run test suite" {
    const files = [_][]const u8{
        "type.json",
        "const.json",
        "exclusiveMaximum.json",
        "exclusiveMinimum.json",
        "maximum.json",
        "minimum.json",
        "multipleOf.json",
        "patternProperties.json",
        "additionalProperties.json",
        "maxProperties.json",
        "minProperties.json",
        "maxLength.json",
        "minLength.json",
        "pattern.json",
        "additionalItems.json",
        "required.json",
        "items.json",
        "maxItems.json",
        "minItems.json",
        "properties.json",
        "enum.json",
        "uniqueItems.json",
        "anyOf.json",
        "boolean_schema.json",
        "oneOf.json",
        "allOf.json",
        "not.json",
        "if-then-else.json",
        // "ref.json",
        // "WIP.json",
    };
    const allocator = std.testing.allocator;
    var file_path_buf: [100]u8 = undefined;
    const base_path = "JSON-Schema-Test-Suite/tests/draft7";

    for (files) |file_name| {
        const file_path = try std.fmt.bufPrint(file_path_buf[0..], "{s}/{s}", .{ base_path, file_name });
        var file = try std.fs.cwd().openFile(file_path, .{});
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

                var stack = try jsonSchema.Stack.init(allocator, schema, 10);
                defer stack.deinit();

                {
                    const valid = try jsonSchema.checks(schema, data, &stack, null);
                    try runTest(expected, valid, file_path, case_name, test_name, "early return", schema, data);
                }

                {
                    var errors = jsonSchema.Errors.init(allocator);
                    defer errors.deinit();
                    const valid = try jsonSchema.checks(schema, data, &stack, &errors);
                    try runTest(expected, valid, file_path, case_name, test_name, "collect all errors", schema, data);
                    try std.testing.expectEqual(valid, errors.empty());
                }
            }
        }
    }
}
