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

fn to_token(input: []const u8) !struct { token: ?Token, unparsed: []const u8 } {
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
            // return .{ .token = .{ .white_space = input[0..ws_length] }, .unparsed = input[ws_length..] };
            return .{ .token = null, .unparsed = input[ws_length..] };
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
        if (res.token) |token| try tokens.append(token);
        unparsed = res.unparsed;
    }

    try tokens.append(.end_of_file);

    return tokens;
}

const ValueTag = enum { object, string };

const Value = union(ValueTag) { object: std.StringArrayHashMap(Value), string: []const u8 };

// fn parse_member(tokens: []const Token, index: usize) struct { key: []const u8, value: Value, index: usize } {
//     var key : []const u8 = undefined;
//     if(index < tokens.len and tokens[index] == .white_space){
//         index += 1;
//     }
//
//     if(index < tokens.len and tokens[index] == .string) {
//         index += 1;
//         // set string
//     }
//
//        if(index < tokens.len and tokens[index] == .white_space){
//         index += 1;
//     }
//
//     parse_element();
// }
//
// fn parse_members() void {
//     parse_member();
//
//     if(index < tokens.len and tokens[index] == .comma){
//         parse_members();
//     }
// }
//
// fn parse_object(tokens: []const Token, index: usize) struct { value: ?Value, index: usize } {
//     if (index < tokens.len and tokens[index] != .brace_left) {
//         return false;
//     }
//     index += 1;
//
//     if (index < tokens.len and tokens[index] == .white_space) {
//         index += 1;
//     }
//
//     if (index < tokens.len and tokens[index] == .brace_right) {
//         return .{ null, index + 1 };
//     }
//
//     // optional
//     parse_members();
//
//     if (index < tokens.len and tokens[index] == .brace_right) {
//         return .{ null, index + 1 };
//     }
//
//     unreachable;
// }
//
// fn parse_value(tokens: []const Token, index: usize) Value {
//     switch (tokens[index]) {
//         .brace_left => {},
//         else => unreachable,
//     }
// }
//
// fn parse_element(tokens: []const Token, index: usize) struct { value: Value, index: usize } {
//     if (index < tokens.len and tokens[index] == .whitespace) {
//         index += 1;
//     }
//
//     const res = parse_value();
//
//     if (index < tokens.len and tokens[index] == .whitespace) {
//         index += 1;
//     }
//
//     return .{ .value = res.Value, .index = index };
// }
//
// /// parse the given tokens based on this JSON grammar: https://www.crockford.com/mckeeman.html
// fn parse(tokens: []const Token) Value {
//     const index: usize = 0;
//     const res = parse_element(tokens, index);
//     std.debug.assert(res.index == tokens.len);
// }

// fn parse(tokens: []const Token) Value {
//     var head : usize = 0;
//     while(head < tokens.len) : (head += 1){
//         switch (tokens[head]) {
//             .brace_left => {},
//             else => unreachable
//         }
//     }
// }

// fn parse_value(tokens: []const Token) ?Value {
//     const  head : usize = 0;
//     if(head >= tokens.len or tokens[head] != .string){
//         return null;
//     }
//
//     const key: []const u8 = tokens[head].string;
//
//     if(head >= tokens.len){
//         // error ?
//         return null;
//     }
//
//     const value : Value = switch (tokens[head]) {
//
//     };
//
//     return Value{ .object = };
// }
//
// fn parse_object(tokens: []const Token) ?Value {
//
// }

const log_parse = std.log.scoped(.parse);

fn parse_object(allocator: std.mem.Allocator, tokens: []const Token, start: usize) !?struct { value: Value, head: usize } {
    var head: usize = start;

    if (head >= tokens.len or tokens[head] != .brace_left) {
        return null;
    }

    var map = std.StringArrayHashMap(Value).init(allocator);

    head += 1;

    if (head < tokens.len and tokens[head] == .brace_right) {
        // early exit: empty object
        return .{ .value = .{ .object = map }, .head = head + 1 };
    }

    if (head >= tokens.len or tokens[head] != .string) {
        log_parse.err("object missing key at token {}", .{head});
        return error.objectMissingKey;
    }

    const key = tokens[head].string;

    head += 1;

    if (head >= tokens.len or tokens[head] != .colon) {
        return error.objectMissingColon;
    }

    head += 1;

    if (head >= tokens.len) {
        return error.objectMissingValue;
    }

    switch (tokens[head]) {
        .string => {
            // TODO check for an empty string key
            const str = tokens[head].string;
            const copy = try allocator.dupe(u8, str[1 .. str.len - 1]);

            try map.put(key[1 .. key.len - 1], .{ .string = copy });
        },
        else => unreachable,
    }

    head += 1;

    // TODO check for comma

    if (head >= tokens.len or tokens[head] != .brace_right) {
        return error.objectMissingClosingBrace;
    }

    return .{ .value = .{ .object = map }, .head = head + 1 };
}

fn parse(allocator: std.mem.Allocator, tokens: []const Token) !Value {
    const res = try parse_object(allocator, tokens, 0) orelse {
        log_parse.err("missing root object", .{});
        return error.rootObjectMissing;
    };

    if (res.head >= tokens.len or tokens[res.head] != .end_of_file) {
        return error.unexpectedContentLeft;
    }

    return res.value;
}

const Json = struct {
    allocator: std.mem.Allocator,
    data: Value,

    fn init(allocator: std.mem.Allocator, input: []const u8) !Json {
        const tokens = try tokenize(allocator, input);
        defer tokens.deinit();

        const json = try parse(allocator, tokens.items);

        return .{ .allocator = allocator, .data = json };
    }

    fn deinit(self: *Json) void {
        var iterator = self.data.object.iterator();
        while (iterator.next()) |entry| {
            switch (entry.value_ptr.*) {
                .string => |s| self.allocator.free(s),
                else => unreachable,
            }
        }
        self.data.object.deinit();
    }
};

// fn parse_json(allocator: std.mem.Allocator, input: []const u8) void {
//     const tokens = try tokenize(allocator, input);
//     defer tokens.deinit();
//
//     const json = try parse(allocator, tokens.items);
// }

test "empty object" {
    const data = "{  \n  }";

    const allocator = std.testing.allocator;

    var json = try Json.init(allocator, data);
    defer json.deinit();

    try std.testing.expect(json.data == .object);
    try std.testing.expect(json.data.object.count() == 0);
}

test "object with single key string pair" {
    const data =
        \\{
        \\  "firstName": "John"
        \\}
    ;

    const allocator = std.testing.allocator;

    var json = try Json.init(allocator, data);
    defer json.deinit();

    try std.testing.expect(json.data == .object);
    try std.testing.expect(json.data.object.get("firstName").? == .string);
    try std.testing.expect(std.mem.eql(u8, json.data.object.get("firstName").?.string, "John"));
}

test "object with two key string pairs" {
    const data =
        \\{
        \\  "firstName": "John",
        \\  "lastName": "Doe",
        \\}
    ;

    const allocator = std.testing.allocator;

    var json = try Json.init(allocator, data);
    defer json.deinit();

    try std.testing.expect(json.data == .object);
    try std.testing.expect(json.data.object.get("firstName").? == .string);
    try std.testing.expect(std.mem.eql(u8, json.data.object.get("firstName").?.string, "John"));
    try std.testing.expect(json.data.object.get("lastName").? == .string);
    try std.testing.expect(std.mem.eql(u8, json.data.object.get("lastName").?.string, "Doe"));
}
