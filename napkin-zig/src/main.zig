const std = @import("std");
const root = @import("napkin");
const cli = root.cli;

pub fn main() !void {
    try runCli();
}

/// Parses and runs the cli
fn runCli() !void {
    // allocator setup
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // get cli args
    const args = try std.process.argsAlloc(allocator);

    // CLI PARSING

    // parse for '--help' or if there are no args
    if (args.len < 2) return printHelp();
    if (try cli.parseOption(args[1])) |option| {
        if (std.mem.eql(u8, option, "help") or std.mem.eql(u8, option, "h")) {
            return printHelp();
        }
    }
}

/// Prints a help message
fn printHelp() void {
    std.debug.print("replace this with a help message\n", .{});
}
