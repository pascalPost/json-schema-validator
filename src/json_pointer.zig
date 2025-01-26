const std = @import("std");

pub const Error = error{
    InvalidPointerSyntax,
};

/// decode escaped characters in given path (see https://datatracker.ietf.org/doc/html/rfc6901#section-4)
pub const PathDecoderUnmanaged = struct {
    buffer: std.ArrayListUnmanaged(u8),

    pub fn initCapacity(allocator: std.mem.Allocator, path_len_capacity: usize) !PathDecoderUnmanaged {
        return .{
            .buffer = try std.ArrayListUnmanaged(u8).initCapacity(allocator, path_len_capacity),
        };
    }

    pub fn deinit(self: *PathDecoderUnmanaged, allocator: std.mem.Allocator) void {
        self.buffer.deinit(allocator);
    }

    /// decode ~0 to ~ and ~1 to /; if not present self.buffer.items.len == 0
    fn decodeSlashTilde(self: *PathDecoderUnmanaged, allocator: std.mem.Allocator, path: []const u8) !void {
        var head: usize = 0;
        while (std.mem.indexOfScalarPos(u8, path, head, '~')) |idx| {
            if (idx >= path.len - 1 or (path[idx + 1] != '0' and path[idx + 1] != '1')) {
                // error condition for a JSON Pointer
                // https://datatracker.ietf.org/doc/html/rfc6901#section-3
                return Error.InvalidPointerSyntax;
            }

            try self.buffer.appendSlice(allocator, path[head..idx]);

            const c: u8 = if (path[idx + 1] == '0') '~' else '/';
            try self.buffer.append(allocator, c);
            head = idx + 2;
        }

        try self.buffer.appendSlice(allocator, path[head..]);
    }

    fn percentDecoding(self: *PathDecoderUnmanaged, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
        if (self.buffer.items.len > 0) {
            return std.Uri.percentDecodeInPlace(self.buffer.items);
        }

        var needs_decoding = false;
        var input_index = path.len;
        while (input_index > 0) {
            if (input_index >= 3) {
                const maybe_percent_encoded = path[input_index - 3 ..][0..3];
                if (maybe_percent_encoded[0] == '%') {
                    if (std.fmt.parseInt(u8, maybe_percent_encoded[1..], 16)) |_| {
                        needs_decoding = true;
                        break;
                    } else |_| {}
                }
            }
            input_index -= 1;
        }

        if (needs_decoding) {
            try self.buffer.appendSlice(allocator, path);
            // NOTE can be made more efficient by not searching the whole path again
            // and start with the input_index from above
            return std.Uri.percentDecodeInPlace(self.buffer.items);
        }

        return path;
    }

    pub fn decode(self: *PathDecoderUnmanaged, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
        self.buffer.clearRetainingCapacity();
        try self.decodeSlashTilde(allocator, path);
        return try self.percentDecoding(allocator, path);
    }
};

pub fn schemaURI(schema: std.json.Value) ?[]const u8 {
    switch (schema) {
        .object => |object| {
            if (object.get("$id")) |id| {
                switch (id) {
                    .string => |string| return string,
                    else => return null,
                }
            }
        },
        else => {},
    }
    return null;
}

test "path decoding" {
    const allocator = std.testing.allocator;
    var decoder = try PathDecoderUnmanaged.initCapacity(allocator, 1000);
    defer decoder.deinit(allocator);

    try std.testing.expectError(Error.InvalidPointerSyntax, decoder.decode(allocator, "~"));
    try std.testing.expectError(Error.InvalidPointerSyntax, decoder.decode(allocator, "invalid~"));
    try std.testing.expectError(Error.InvalidPointerSyntax, decoder.decode(allocator, "invalid~path"));
    try std.testing.expectError(Error.InvalidPointerSyntax, decoder.decode(allocator, "~3"));

    try std.testing.expectEqualStrings("tilde~field", try decoder.decode(allocator, "tilde~0field"));
    try std.testing.expectEqualStrings("slash/field", try decoder.decode(allocator, "slash~1field"));
    try std.testing.expectEqualStrings("percent%field", try decoder.decode(allocator, "percent%25field"));
    try std.testing.expectEqualStrings("slash/percent%field", try decoder.decode(allocator, "slash~1percent%25field"));
}
