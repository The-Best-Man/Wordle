//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

const wordle = @import("wordle.zig");

pub fn interactive(word_list: *std.ArrayList([5]u8)) !void {
    var stdIn = std.io.getStdIn().reader();

    var buffer: [1024]u8 = undefined;
    outer: while (true) : (std.debug.print("\u{001B}[3F\u{001B}[2K", .{})) {
        const len = try stdIn.read(&buffer);
        std.debug.assert(len > 11);
        const guess = buffer[0..5].*;
        std.debug.print("{s} {s}\n", .{ buffer[0..5], buffer[6..11] });
        const filter = init: {
            var val: [5]wordle.Value = undefined;
            for (buffer[6..11], 0..) |char, i| {
                val[i] = switch (char) {
                    'I' => .Incorrect,
                    'M' => .Misplaced,
                    'C' => .Correct,
                    else => continue :outer,
                };
            }

            break :init val;
        };

        wordle.eliminateWords(word_list, guess, filter);

        std.debug.print("{s}\n", .{word_list.items[0]});
    }
}

pub fn checkKeywords(word_list: *std.ArrayList([5]u8), allocator: std.mem.Allocator, num_threads: usize) !struct { [5]u8, usize } {
    const threads = try allocator.alloc(std.Thread, num_threads);
    var next_lock = std.Thread.Mutex{};
    var next_key: usize = 0;
    const list_size = word_list.items.len;

    // Somewhere in here, split into multiple threads.
    const average_loss: std.ArrayList(usize) = init: {
        var word_loss_list = try std.ArrayList(usize).initCapacity(allocator, list_size);
        _ = try word_loss_list.addManyAsSlice(list_size);

        for (threads) |*thread| {
            thread.* = try std.Thread.spawn(.{}, wordle.checkKeyword, .{
                word_list,
                &next_lock,
                &next_key,
                &word_loss_list,
            });
        }

        while (next_key < list_size) {
            std.debug.print("Running: {d}/{d}\n\u{001B}[1F", .{ next_key, list_size });
            std.Thread.sleep(1e9);
        }

        for (threads) |*thread| {
            thread.join();
        }

        break :init word_loss_list;
    };

    return init: {
        var cur: usize = 0;
        const arr = average_loss.items;
        for (0..list_size) |i| {
            if (arr[i] > arr[cur]) {
                cur = i;
            }
        }
        break :init .{ word_list.items[cur], cur };
    };
}
