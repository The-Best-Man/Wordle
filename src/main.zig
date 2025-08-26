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

const CPL = "\u{001B}[nF";
const EL = "\u{001B}[nF";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();
    var word_list = try readWords(allocator, "words.txt"[0..]);

    try lib.interactive(&word_list);

    // const args = try std.process.argsAlloc(allocator);
    //
    // if (args.len != 2) {
    //     std.process.exit(1);
    // }
    // const num_threads = try std.fmt.parseInt(usize, args[1], 10);
    //
    //
    // // try lib.interactive(&word_list);
    // const best_word, const loss = try lib.checkKeywords(&word_list, allocator, num_threads);
    // try std.io.getStdOut().writer().print("Best opener: {s} word loss: {d}\n", .{ best_word, loss });
}

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("hello_lib");
