//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

const wordle = @import("wordle.zig");

// TODO: Move these out of here. These should be implementation independent
// instead of in the implementation.
var stdIn = std.fs.File.stdin();
var stdErr = std.fs.File.stderr();
var stdOut = std.fs.File.stdout();

const HORIZONTAL_BORDER = "\u{2500}";
const TOP_LEFT_CORNER = "\u{250C}";
const TOP_RIGHT_CORNER = "\u{2510}";
const VERTICAL_BORDER = "\u{2502}";
const BOT_LEFT_CORNER = "\u{2514}";
const BOT_RIGHT_CORNER = "\u{2518}";

const Box = struct {
    width: u16,
    height: u16,
    x_pos: u16,
    y_pos: u16,

    pub fn drawBox(self: Box, writer: *std.Io.Writer) !void {
        try writer.print("{s}", .{TOP_LEFT_CORNER});
        for (0..self.width) |_| {
            try writer.print("{s}", .{HORIZONTAL_BORDER});
        }
        try writer.print("{s}\n", .{TOP_RIGHT_CORNER});
        for (0..self.height) |_| {
            try writer.print("{s}", .{VERTICAL_BORDER});
            for (0..self.width) |_| {
                try writer.print(" ", .{});
            }
            try writer.print("{s}\n", .{VERTICAL_BORDER});
        }
        try writer.print("{s}", .{BOT_LEFT_CORNER});
        for (0..self.width) |_| {
            try writer.print("{s}", .{HORIZONTAL_BORDER});
        }
        try writer.print("{s}", .{BOT_RIGHT_CORNER});
    }

    pub fn writeToBox(self: Box, msg: []u8, writer: *std.Io.Writer) !void {
        try moveToPos(self.x_pos, self.y_pos);
        const lines = msg.len / self.width;
        for (0..lines) |i| {
            try writer.print("{s}\n", .{msg[i]});
        }
    }
};

fn clearScreen(writer: *std.Io.Writer) !void {
    try writer.print("\u{001B}[2J", .{});
}

fn moveToPos(x_pos: u16, y_pos: u16, writer: *std.Io.Writer) !void {
    try writer.print("\u{001B}[{d};{d}H", .{ x_pos, y_pos });
}

fn drawScreen(writer: *std.Io.Writer) !void {
    try clearScreen();
    try moveToPos(1, 1);
    // try drawBox(10, 10);
    try moveToPos(2, 2);
    try writer.print("Hello,", .{});
    try moveToPos(3, 2);
    try writer.print("World!", .{});
    try moveToPos(12, 12);
    try writer.print("\n", .{});
}

pub fn interactive(word_list: *std.ArrayList([5]u8), writer: *std.Io.Writer) !void {
    // try drawScreen();

    var guess_list: [6]struct { [5]u8, [5]u8 } = undefined;
    var last_pos: u16 = 0;
    var buffer: [1024]u8 = undefined;
    outer: while (true) : (try writer.print("\u{001B}[{d}F\u{001B}[2K", .{2})) {
        const len = try stdIn.read(&buffer);
        if (len < 11) {
            try stdErr.print("Unable to parse input\n", .{});
            continue;
        }
        std.mem.copyForwards(u8, &guess_list[last_pos][0], buffer[0..5]);
        std.mem.copyForwards(u8, &guess_list[last_pos][1], buffer[6..11]);
        last_pos += 1;

        for (0..last_pos) |i| {
            try writer.print("{s} {s}\n", .{ guess_list[i][0], guess_list[i][1] });
        }

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

        // Check for all corrects
        for (filter) |val| {
            if (val != .Correct)
                break;
        } else {
            try writer.print("Correct word found: {s}\n", .{buffer[0..5]});
            return;
        }

        wordle.eliminateWords(word_list, buffer[0..5].*, filter);

        var pos: usize = 0;
        while (pos < 10 and word_list.items.len > pos) : (pos += 1) {
            try writer.print("{s}\n", .{word_list.items[pos]});
        }

        try writer.print("\u{001B}[{d}F", .{last_pos + pos});
    }
}

pub fn checkKeywords(word_list: *std.ArrayList([5]u8), allocator: std.mem.Allocator, writer) !struct { [5]u8, usize } {
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
            try stdOut.print("Running: {d}/{d}\n\u{001B}[1F", .{ next_key, list_size });
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
