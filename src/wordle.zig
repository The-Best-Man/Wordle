pub const Value = enum {
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

pub fn compareGuess(guess: [5]u8, keyword: [5]u8) [5]Value {
    var output: [5]Value = undefined;
    var claim_list: [5]bool = undefined;

    // Check all values for correct placement first, This is important since a
    // letter can be correctly placed even if it is the same as another
    // character.
    for (guess, keyword, 0..) |guess_char, key_char, i| {
        if (guess_char == key_char) {
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

fn findChar(word: [5]u8, ch: u8) []usize {
    var pos: u16 = 0;
    var positions: [5]usize = undefined;
    for (word, 0..) |word_char, i| {
        if (word_char == ch) {
            positions[pos] = i;
            pos += 1;
        }
    }
    return positions[0..pos];
}

///
/// Check if the word is valid given the previous guess and the resultant value
/// set.
///
/// This acts if the guess is the keyword and the word is the guess.
/// If a character is misplaced, and that character is incorrect in the guess,
/// then the word is invalid. If the character is correct in the guess but they
/// are not in the same place, then the word is invalid.
/// If the character is correct but is misplaced in the or incorrect in the guess,
/// then the word is invalid
///
/// @param word The word that is being examined
/// @param guess The word that was used as the guess
/// @param filter The result of using the guess
///
/// @return whether the word is still valid
///
fn isValid(word: [5]u8, guess: [5]u8, filter: [5]Value) bool {
    for (word, guess, filter) |word_char, guess_char, filter_value| {
        switch (filter_value) {
            .Correct => {
                if (word_char != guess_char) return false;
            },
            .Incorrect => {
                // Find the number of misplaced characters of the guess that
                // are the same as this incorrect character, If the word has
                // more than the amount of misplaced, then it is invalid.
                const positions = findChar(guess, guess_char);
                const num_misplaced = init: {
                    var num: u16 = 0;
                    for (positions) |pos| {
                        if (filter[pos] == .Misplaced) num += 1;
                    }
                    break :init num;
                };

                if (findChar(word, guess_char).len > num_misplaced) return false;
            },
            .Misplaced => {
                if (word_char == guess_char or findChar(word, guess_char).len == 0) return false;
            },
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
        .{ .word = "xxvii".*, .guess = "songs".*, .arr = .{ .Incorrect, .Correct, .Correct, .Correct, .Incorrect }, .expected = false },
        .{ .word = "eager".*, .guess = "wager".*, .arr = .{ .Incorrect, .Correct, .Correct, .Correct, .Correct }, .expected = true },
    };

    for (tests) |tst| {
        if (tst.expected != isValid(tst.word, tst.guess, tst.arr)) {
            std.debug.print("word: {s}, guess: {s}, expected: {s}\n", .{ tst.word, tst.guess, if (tst.expected) "true" else "false" });
            try testing.expect(false);
        }
    }
}

///
/// Filter out the words that are no longer valid guesses.
///
/// @param word_list The list of words
/// @param guess The previous guess
/// @pram filter The result of using that guess
///
pub fn eliminateWords(word_list: *std.ArrayList([5]u8), guess: [5]u8, filter: [5]Value) void {
    var pos: u32 = 0;
    while (pos < word_list.items.len) {
        if (!isValid(word_list.items[pos], guess, filter)) {
            _ = word_list.swapRemove(pos);
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

fn nextKeyword(next_lock: *std.Thread.Mutex, next_key: *usize, last_key: usize) ?usize {
    next_lock.lock();
    defer {
        next_key.* += 1;
        next_lock.unlock();
    }
    if (next_key.* < last_key) {
        return next_key.*;
    } else {
        return null;
    }
}

pub fn checkKeyword(word_list: *std.ArrayList([5]u8), next_lock: *std.Thread.Mutex, next_key: *usize, result_list: *std.ArrayList(usize)) !void {
    // Search through each part of the list

    const last_key = word_list.items.len;

    while (nextKeyword(next_lock, next_key, last_key)) |key| {
        const keyword = word_list.items[key];
        var sum: usize = 0;
        for (word_list.items) |guess| {
            var working_list = try word_list.clone();
            defer working_list.deinit();
            eliminateWords(&working_list, guess, compareGuess(guess, keyword));
            sum += word_list.items.len - working_list.items.len;
        }
        result_list.items[key] = sum / last_key;
    }
}

const std = @import("std");
const testing = std.testing;
