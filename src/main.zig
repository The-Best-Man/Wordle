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

const ThreadArg = struct {
    word_list: *const std.ArrayList([5]u8),
    next_key: *const usize,
    next_lock: *const std.Thread.Mutex,
    result_list: *const std.ArrayList(usize),
};

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

fn checkKeyword(word_list: *std.ArrayList([5]u8), next_lock: *std.Thread.Mutex, next_key: *usize, result_list: *std.ArrayList(usize)) !void {
    // Search through each part of the list

    const last_key = word_list.items.len;

    while (nextKeyword(next_lock, next_key, last_key)) |key| {
        const keyword = word_list.items[key];
        var sum: usize = 0;
        for (word_list.items) |guess| {
            var working_list = try word_list.clone();
            defer working_list.deinit();
            lib.eliminateWords(&working_list, guess, lib.compareGuess(guess, keyword));
            sum += word_list.items.len - working_list.items.len;
        }
        result_list.items[key] = sum / last_key;
    }
}

const CPL = "\u{001B}[nF";
const EL = "\u{001B}[nF";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);

    if (args.len != 2) {
        std.process.exit(1);
    }

    var word_list = try readWords(allocator, "words.txt"[0..]);

    // try lib.interactive(&word_list);

    const list_size = word_list.items.len;

    const num_thread = try std.fmt.parseInt(usize, args[1], 10);

    const threads = try allocator.alloc(std.Thread, num_thread);
    var next_lock = std.Thread.Mutex{};
    var next_key: usize = 0;

    // Somewhere in here, split into multiple threads.
    const average_loss: std.ArrayList(usize) = init: {
        var word_loss_list = try std.ArrayList(usize).initCapacity(allocator, list_size);
        _ = try word_loss_list.addManyAsSlice(list_size);

        for (threads) |*thread| {
            thread.* = try std.Thread.spawn(.{}, checkKeyword, .{
                &word_list,
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
