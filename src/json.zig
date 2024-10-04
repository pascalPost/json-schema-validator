const std = @import("std");

// https://www.crockford.com/mckeeman.html

const TokenTag = enum { brace_left, brace_right, colon, comma, string, number, white_space, end_of_file };

const Token = union(TokenTag) {
    brace_left: []const u8,
    brace_right: []const u8,
    colon: []const u8,
    comma: []const u8,
    string: []const u8,
    number: []const u8,
    white_space: []const u8,
    end_of_file,
};

fn to_token(input: []const u8) !struct { token: Token, unparsed: []const u8 } {
    std.debug.assert(input.len > 0);
    switch (input[0]) {
        '{' => return .{ .token = .{ .brace_left = input[0..1] }, .unparsed = input[1..] },
        '}' => return .{ .token = .{ .brace_right = input[0..1] }, .unparsed = input[1..] },
        ':' => return .{ .token = .{ .colon = input[0..1] }, .unparsed = input[1..] },
        ',' => return .{ .token = .{ .comma = input[0..1] }, .unparsed = input[1..] },
        '0'...'9' => {
            // number
            var number_len: usize = 1;
            while (number_len < input.len) : (number_len += 1) {
                switch (input[number_len]) {
                    '0'...'9' => {},
                    else => break,
                }
            }
            return .{ .token = .{ .number = input[0..number_len] }, .unparsed = input[number_len..] };
        },
        ' ', '\n' => {
            // parse until next non whitespace character is found
            var ws_length: usize = 1;
            while (ws_length < input.len) : (ws_length += 1) {
                switch (input[ws_length]) {
                    ' ', '\n' => {},
                    else => break,
                }
            }
            return .{ .token = .{ .white_space = input[0..ws_length] }, .unparsed = input[ws_length..] };
        },
        '"' => {
            // parse string until the next " is found
            // easiest thing to do is to keep the string data as a slice of the data.
            // This necessitates to keep the data in memory. Other option would be to save the range and
            // another reference to the data...

            var string_length: usize = 1;
            while (string_length < input.len) : (string_length += 1) {
                if (input[string_length] == '"') {
                    return .{ .token = .{ .string = input[0 .. string_length + 1] }, .unparsed = input[string_length + 1 ..] };
                }
            }

            return error.unterminatedString;
        },
        else => return error.unknownCharacter,
    }
}

fn tokenize(allocator: std.mem.Allocator, input: []const u8) !std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator);

    var unparsed = input;

    while (unparsed.len > 0) {
        const res = try to_token(unparsed);
        try tokens.append(res.token);
        unparsed = res.unparsed;
    }

    try tokens.append(.end_of_file);

    return tokens;
}

const ValueTag = enum { object };

const Value = union(ValueTag) { object: []const Element };

const Element = struct { key: []const u8, value: Value };

fn parse_member() void {
    //ws string ws ':' element
}

fn parse_object() void {}

fn parse_element(tokens: []const Token) []const Element

fn parse(tokens: []const Token) !void {
    switch (tokens[0]) {
        .brace_left => {
            // object
        },
        else => unreachable,
    }
}

test "json example" {
    const data =
        \\{
        \\  "firstName": "John",
        \\  "lastName": "Doe",
        \\  "age": 21
        \\}
    ;

    const allocator = std.testing.allocator;
    // var tokens = std.ArrayList(Token).init(allocator);
    // defer tokens.deinit();

    const tokens = try tokenize(allocator, data);
    defer tokens.deinit();

    try std.testing.expect(tokens.items[0] == .brace_left);
    try std.testing.expect(tokens.items[1] == .white_space);
    try std.testing.expect(tokens.items[2] == .string);

    // const json = parse_json(data);

    // try std.testing.expectEqual("John", json["firstName"]);
}
