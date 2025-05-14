//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const Value = enum {
    Incorrect,
    Misplaced,
    Correct,
};

fn inWord(word: [5]u8, claimed: *[5]bool, ch: u8) bool {
    return for (word, claimed) |current, *is_claimed| {
        if (is_claimed.*) {
            continue;
        } else if (current == ch) {
            is_claimed.* = true;
            break true;
        }
    } else false;
}

fn compareGuess(guess: [5]u8, keyword: [5]u8) [5]Value {
    var output: [5]Value = undefined;
    var claim_list: [5]bool = undefined;

    // Check all values for correct placement first, This is important since a
    // letter can be correctly placed even if it is the same as another
    // character.
    for (guess, keyword, 0..) |first, second, i| {
        if (first == second) {
            output[i] = .Correct;
            claim_list[i] = true;
        } else {
            output[i] = .Incorrect;
        }
    }

    for (guess, 0..) |first, i| {
        if (output[i] == .Correct)
            continue
        else if (inWord(keyword, &claim_list, first)) {
            output[i] = .Misplaced;
        }
    }
    return output;
}

const testing = std.testing;

test "compareTest" {
    const tests = [_]struct { guess: [5]u8, keyword: [5]u8, expected: [5]Value }{
        .{ .guess = "CRANE".*, .keyword = "ABIDE".*, .expected = .{ .Incorrect, .Incorrect, .Misplaced, .Incorrect, .Correct } },
        .{ .guess = "WHERE".*, .keyword = "CRANE".*, .expected = .{ .Incorrect, .Incorrect, .Incorrect, .Misplaced, .Correct } },
        .{ .guess = "WEARS".*, .keyword = "CRANE".*, .expected = .{ .Incorrect, .Misplaced, .Correct, .Misplaced, .Incorrect } },
        .{ .guess = "SEERS".*, .keyword = "CRANE".*, .expected = .{ .Incorrect, .Misplaced, .Incorrect, .Misplaced, .Incorrect } },
    };

    for (tests) |tst| {
        try testing.expectEqualSlices(Value, &tst.expected, &compareGuess(tst.guess, tst.keyword));
    }
}

fn isValid(word: [5]u8, guess: [5]u8, filter: [5]Value) bool {
    const result = compareGuess(word, guess);

    for (word, result, 0..) |word_char, result_value, i| {
        if (result_value == .Incorrect)
            continue;
        if (result_value == .Misplaced) {
            for (guess, filter, 0..) |guess_char, filter_value, j| {
                if (guess_char == word_char) {
                    if (filter_value == .Incorrect) {
                        return false;
                    } else if (filter_value == .Correct and i != j) {
                        return false;
                    } else {
                        break;
                    }
                }
            }
        }
        if (result_value == .Correct) {
            if (filter[i] == .Incorrect or filter[i] == .Misplaced) {
                return false;
            }
        }
    }

    return true;
}

test "isValid" {
    const tests = [_]struct { word: [5]u8, guess: [5]u8, arr: [5]Value, expected: bool }{
        .{ .word = "WHACK".*, .guess = "CRANE".*, .arr = .{ .Incorrect, .Incorrect, .Misplaced, .Incorrect, .Correct }, .expected = false },
        .{ .word = "CRANE".*, .guess = "CRANE".*, .arr = .{ .Incorrect, .Incorrect, .Misplaced, .Incorrect, .Correct }, .expected = false },
        .{ .word = "EASES".*, .guess = "CRANE".*, .arr = .{ .Incorrect, .Incorrect, .Misplaced, .Incorrect, .Correct }, .expected = false },
        .{ .word = "PAXLE".*, .guess = "CRANE".*, .arr = .{ .Incorrect, .Incorrect, .Misplaced, .Incorrect, .Correct }, .expected = true },
        .{ .word = "CRNRE".*, .guess = "CRANE".*, .arr = .{ .Incorrect, .Incorrect, .Misplaced, .Incorrect, .Correct }, .expected = false },
        .{ .word = "CRANE".*, .guess = "EASES".*, .arr = .{ .Misplaced, .Correct, .Incorrect, .Incorrect, .Incorrect }, .expected = false },
        .{ .word = "CARES".*, .guess = "EASES".*, .arr = .{ .Incorrect, .Correct, .Incorrect, .Misplaced, .Correct }, .expected = false },
    };

    for (tests) |tst| {
        if (tst.expected != isValid(tst.word, tst.guess, tst.arr)) {
            std.debug.print("word: {s}, guess: {s}, expected: {s}\n", .{ tst.word, tst.guess, if (tst.expected) "true" else "false" });
            try testing.expect(false);
        }
    }
}

fn eliminateWords(word_list: *std.ArrayList([5]u8), guess: [5]u8, filter: [5]Value) void {
    var pos: u32 = 0;
    while (pos < word_list.items.len) {
        if (!isValid(word_list.items[pos], guess, filter)) {
            _ = word_list.orderedRemove(pos);
        } else {
            pos += 1;
        }
    }
}

test "eliminateWords" {
    var word_list = std.ArrayList([5]u8).init(testing.allocator);
    defer word_list.deinit();

    try word_list.appendSlice(&.{ "WHACK".*, "CRANE".*, "EASES".*, "PAXLE".*, "CRNRE".* });

    const expected_list = [_][5]u8{"PAXLE".*};
    eliminateWords(&word_list, "CRANE".*, [5]Value{ .Incorrect, .Incorrect, .Misplaced, .Incorrect, .Correct });

    try testing.expectEqual(word_list.items.len, expected_list.len);
    for (word_list.items, expected_list) |act, exp| {
        try testing.expectEqualSlices(u8, &act, &exp);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    var word_file = try std.fs.cwd().openFile("words.txt", .{});
    defer word_file.close();

    var word_list = std.ArrayList([5]u8).init(allocator);
    defer word_list.deinit();

    var buffer: [128]u8 = undefined;
    var reader = word_file.reader();
    while (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |buf| {
        std.debug.assert(buf.len == 5);
        _ = try word_list.append(buf[0..5].*);
    }

    const list_size = word_list.items.len;

    const average_loss: std.ArrayList(usize) = init: {
        var word_loss_list = try std.ArrayList(usize).initCapacity(allocator, list_size);
        for (word_list.items, 0..) |key, i| {
            std.debug.print("Word: {d}/15025\n\u{001B}[1F", .{i});
            var sum: usize = 0;
            for (word_list.items) |guess| {
                var working_list = try word_list.clone();
                eliminateWords(&working_list, guess, compareGuess(guess, key));
                sum += list_size - working_list.items.len;
            }
            try word_loss_list.append(sum / list_size);
        }

        break :init word_loss_list;
    };

    const best_pos: usize = init: {
        var cur: usize = 0;
        const arr = average_loss.items;
        for (0..list_size) |i| {
            if (arr[i] > arr[cur]) {
                cur = i;
            }
        }
        break :init cur;
    };

    try std.io.getStdOut().writer().print("Best opener: {s} word loss: {d}\n", .{ word_list.items[best_pos], average_loss.items[best_pos] });
}

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("hello_lib");
