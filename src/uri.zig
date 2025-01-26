const std = @import("std");
const Stack = @import("stack.zig").Stack;

const BaseUriMap = struct {
    arena: std.heap.ArenaAllocator,
    map: UriHashMap,

    fn init(allocator: std.mem.Allocator, schema: std.json.Value, stack: *Stack) !BaseUriMap {
        var arena = std.heap.ArenaAllocator.init(allocator);
        var base_uri_map = UriHashMap.init(allocator);
        try addFromSchema(arena.allocator(), schema, null, stack, &base_uri_map);
        stack.clearRetainCapacity();
        return .{
            .arena = arena,
            .map = base_uri_map,
        };
    }

    fn deinit(self: *BaseUriMap) void {
        self.arena.deinit();
        self.map.deinit();
    }

    fn addFromSchema(allocator: std.mem.Allocator, root: std.json.Value, uri_base: ?std.Uri, stack: *Stack, base_uri_map: *UriHashMap) !void {
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

                    const uri = uri_blk: {
                        if (std.Uri.parse(id_str)) |abs_uri| {
                            break :uri_blk abs_uri;
                        } else |_| {}

                        // uri is relative: construct uri with uri base
                        if (uri_base == null) std.debug.panic("encountered relative uri w/o uri base.", .{});

                        const resolved_uri_buf_size = 1000;
                        var buf = try allocator.alloc(u8, resolved_uri_buf_size);
                        if (std.Uri.resolve_inplace(uri_base.?, id_str, &buf)) |uri| {
                            allocator.free(buf);
                            break :uri_blk uri;
                        } else |err| {
                            std.debug.panic("Error in constructing uri with base {} and relative part {s} (error: {})", .{ uri_base.?, id_str, err });
                        }
                    };

                    const path = try stack.constructPath(allocator);

                    try base_uri_map.put(uri, path);

                    break :blk uri;
                } else uri_base;

                var it = object.iterator();
                while (it.next()) |entry| {
                    const key = entry.key_ptr.*;
                    const value = entry.value_ptr.*;

                    try stack.pushPath(key);
                    defer stack.pop();

                    try addFromSchema(allocator, value, base, stack, base_uri_map);
                }
            },
            .array => |array| {
                for (array.items, 0..) |value, index| {
                    try stack.pushIndex(index);
                    defer stack.pop();
                    try addFromSchema(allocator, value, uri_base, stack, base_uri_map);
                }
            },
        }
    }
};

const UriHashMap = std.HashMap(std.Uri, []const u8, UriContext, std.hash_map.default_max_load_percentage);

const UriContext = struct {
    pub fn hash(self: UriContext, uri: std.Uri) u64 {
        _ = self;

        var hasher = std.hash.Wyhash.init(0);
        hasher.update(uri.scheme);
        if (uri.user) |component| switch (component) {
            .raw, .percent_encoded => |string| hasher.update(string),
        };
        if (uri.password) |component| switch (component) {
            .raw, .percent_encoded => |string| hasher.update(string),
        };
        if (uri.host) |component| switch (component) {
            .raw, .percent_encoded => |string| hasher.update(string),
        };
        if (uri.port) |port| hasher.update(&std.mem.toBytes(port));
        switch (uri.path) {
            .raw, .percent_encoded => |string| hasher.update(string),
        }
        if (uri.query) |component| switch (component) {
            .raw, .percent_encoded => |string| hasher.update(string),
        };
        if (uri.fragment) |component| switch (component) {
            .raw, .percent_encoded => |string| hasher.update(string),
        };
        return hasher.final();
    }

    pub fn eql(self: UriContext, a: std.Uri, b: std.Uri) bool {
        _ = self;
        return std.meta.eql(a, b);
    }
};

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

    var base_uri_map = try BaseUriMap.init(allocator, schema_parsed.value, &stack);
    defer base_uri_map.deinit();

    var it = base_uri_map.map.iterator();
    while (it.next()) |entry| {
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;
        std.debug.print("{} : {s}\n", .{ key, value });
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
