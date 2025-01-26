const std = @import("std");
const Stack = @import("stack.zig").Stack;

const BaseUriMap = struct {
    arena: std.heap.ArenaAllocator,
    map: std.StringHashMap([]const u8),

    fn init(allocator: std.mem.Allocator, schema: std.json.Value, stack: *Stack) !BaseUriMap {
        var arena = std.heap.ArenaAllocator.init(allocator);
        var base_uri_map = std.StringHashMap([]const u8).init(allocator);
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

    fn addFromSchema(allocator: std.mem.Allocator, root: std.json.Value, uri_base: ?std.Uri, stack: *Stack, base_uri_map: *std.StringHashMap([]const u8)) !void {
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

                    const uri_str = try std.fmt.allocPrint(allocator, "{}", .{uri});
                    const path = try stack.constructPath(allocator);

                    try base_uri_map.put(uri_str, path);

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

    var stack = try Stack.init(allocator, schema_parsed.value, 10);
    defer stack.deinit();

    var base_uri_map = try BaseUriMap.init(allocator, schema_parsed.value, &stack);
    defer base_uri_map.deinit();

    try std.testing.expectEqualStrings("#", base_uri_map.map.get("http://example.com/root.json").?);
    try std.testing.expectEqualStrings("#/definitions/A", base_uri_map.map.get("http://example.com/root.json#foo").?);
    try std.testing.expectEqualStrings("#/definitions/B", base_uri_map.map.get("http://example.com/other.json").?);
    try std.testing.expectEqualStrings("#/definitions/B/definitions/X", base_uri_map.map.get("http://example.com/other.json#bar").?);
    try std.testing.expectEqualStrings("#/definitions/B/definitions/Y", base_uri_map.map.get("http://example.com/t/inner.json").?);
    try std.testing.expectEqualStrings("#/definitions/C", base_uri_map.map.get("urn:uuid:ee564b8a-7a87-4125-8c96-e9f123d6766f").?);
}
