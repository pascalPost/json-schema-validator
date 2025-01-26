const std = @import("std");
const Stack = @import("stack.zig").Stack;

// test "uri" {
//     const base = try std.Uri.parse("http://localhost:1234/sibling_id/base/");
//     var mem: [1000]u8 = undefined;
//     var buf: []u8 = mem[0..];
//     const res = try std.Uri.resolve_inplace(base, "foo.json", &buf);

//     std.debug.print("{}", .{res});
// }

test "schema identification examples" {
    const schema =
        \\{
        \\    "$id": "http://example.com/root.json",
        \\    "definitions": {
        \\        "A": { "$id": "#foo" },
        \\        "B": {
        \\            "$id": "other.json",
        \\            "definitions": {
        \\                "X": { "$id": "#bar" },
        \\                "Y": { "$id": "t/inner.json" }
        \\            }
        \\        },
        \\        "C": {
        \\            "$id": "urn:uuid:ee564b8a-7a87-4125-8c96-e9f123d6766f"
        \\        }
        \\    }
        \\}
    ;

    const allocator = std.testing.allocator;
    const schema_parsed = try std.json.parseFromSlice(std.json.Value, allocator, schema, .{});
    defer schema_parsed.deinit();

    // TODO add a stack to capture current path
    var stack = try Stack.init(allocator, schema_parsed.value, 10);
    defer stack.deinit();

    // traverse tree and find all id instances
    std.debug.print("Collecting all ids:\n", .{});
    var mem: [1000]u8 = undefined;
    var buf: []u8 = mem[0..];
    try findAllIdInSchema(allocator, schema_parsed.value, null, &buf, &stack);
}

fn findAllIdInSchema(allocator: std.mem.Allocator, root: std.json.Value, uri_base: ?std.Uri, buf: *[]u8, stack: *Stack) !void {
    switch (root) {
        .bool, .string, .number_string, .float, .integer, .null => {},
        .object => |object| {
            const base = if (object.get("$id")) |id| blk: {
                const id_str = switch (id) {
                    .string => |s| s,
                    else => {
                        std.debug.print("$id must be of type string (encountered {s}).", .{@tagName(id)});
                        unreachable;
                    },
                };

                std.debug.print("path: {s}\n", .{try stack.constructPath(allocator)});
                std.debug.print("$id: {s}\n", .{id_str});

                if (std.Uri.parse(id_str)) |abs_uri| {
                    std.debug.print("abs uri: {}\n", .{abs_uri});
                    break :blk abs_uri;
                } else |_| {}

                // uri is relative: construct uri with uri base
                if (uri_base == null) std.debug.panic("encountered relative uri w/o uri base.", .{});
                if (std.Uri.resolve_inplace(uri_base.?, id_str, buf)) |uri| {
                    std.debug.print("uri: {}\n", .{uri});
                    break :blk uri;
                } else |err| {
                    std.debug.panic("Error in constructing uri with base {} and relative part {s} (error: {})", .{ uri_base.?, id_str, err });
                }
            } else uri_base;

            var it = object.iterator();
            while (it.next()) |entry| {
                const key = entry.key_ptr.*;
                const value = entry.value_ptr.*;

                try stack.pushPath(key);
                defer stack.pop();

                try findAllIdInSchema(allocator, value, base, buf, stack);
            }
        },
        .array => |array| {
            for (array.items, 0..) |value, index| {
                try stack.pushIndex(index);
                defer stack.pop();
                try findAllIdInSchema(allocator, value, uri_base, buf, stack);
            }
        },
    }
}

// test "schema" {
//     const schema =
//         \\{
//         \\    "$id": "http://localhost:1234/sibling_id/base/",
//         \\    "definitions": {
//         \\        "foo": {
//         \\            "$id": "http://localhost:1234/sibling_id/foo.json",
//         \\            "type": "string"
//         \\        },
//         \\        "base_foo": {
//         \\            "$comment": "this canonical uri is http://localhost:1234/sibling_id/base/foo.json",
//         \\            "$id": "foo.json",
//         \\            "type": "number"
//         \\        }
//         \\    },
//         \\    "allOf": [
//         \\        {
//         \\            "$comment": "$ref resolves to http://localhost:1234/sibling_id/base/foo.json, not http://localhost:1234/sibling_id/foo.json",
//         \\            "$id": "http://localhost:1234/sibling_id/",
//         \\            "$ref": "foo.json"
//         \\        }
//         \\    ]
//         \\}
//     ;

//     // http://localhost:1234/sibling_id/base/ -> #
//     //
// }
