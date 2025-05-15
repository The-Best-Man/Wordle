//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

fn readWords(allocator: std.mem.Allocator, file_name: []const u8) !std.ArrayList([5]u8) {
    var word_file = try std.fs.cwd().openFile(file_name, .{});
    defer word_file.close();

    var word_list = std.ArrayList([5]u8).init(allocator);

    var buffer: [128]u8 = undefined;
    var reader = word_file.reader();
    while (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |buf| {
        std.debug.assert(buf.len == 5);
        _ = try word_list.append(buf[0..5].*);
    }
    return word_list;
}

const threadArg = struct {};

fn checkKeyword(word_list: std.ArrayList([5]u8), keyword: [5]u8) usize {
    _ = word_list;
    _ = keyword;
    // Search through each part of the list

}

const CPL = "\u{001B}[nF";
const EL = "\u{001B}[nF";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    var word_list = try readWords(allocator, "words.txt"[0..]);

    const list_size = word_list.items.len;

    // Somewhere in here, split into multiple threads.
    const average_loss: std.ArrayList(usize) = init: {
        var word_loss_list = try std.ArrayList(usize).initCapacity(allocator, list_size);
        for (word_list.items, 0..) |key, i| {
            std.debug.print("Word: {d}/15025\n", .{i});
            std.debug.print("Keyword: {s}\n", .{key});
            var sum: usize = 0;
            for (word_list.items) |guess| {
                std.debug.print("Guess: {s}\n\u{001B}[1F", .{guess});
                var working_list = try word_list.clone();
                defer working_list.deinit();
                lib.eliminateWords(&working_list, guess, lib.compareGuess(guess, key));
                sum += list_size - working_list.items.len;
            }
            try word_loss_list.append(sum / list_size);
            std.debug.print("\u{001B}[2F", .{});
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
