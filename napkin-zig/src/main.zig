const std = @import("std");
const root = @import("napkin");
const cli = root.cli;

pub fn main() !void {
    if (runCli()) {}
    else |err| switch (err) {
        // make user-dump interrupts exit more gracefully
        error.UserDumpInterrupt => {
            std.debug.print("user dump interrupt\n", .{});
            std.process.exit(0);
        },
        else => return err,
    }
}

/// Parses and runs the cli
fn runCli() !void {
    // allocator setup
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // get cli args
    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    // CLI PARSING

    // parse for '--help' or if there are no args
    if (args.len < 2) return printHelp();
    if (try cli.parseOption(args[1])) |option| {
        if (std.mem.eql(u8, option, "help") or std.mem.eql(u8, option, "h")) {
            return printHelp();
        }
    }

    // parse for '--version'
    if (try cli.parseOption(args[1])) |option| {
        if (std.mem.eql(u8, option, "version") or std.mem.eql(u8, option, "V")) {
            std.debug.print("napkin {s}\n", .{root.version});
            return;
        }
    }

    // test command
    if (std.mem.eql(u8, args[1], "test")) {
        std.debug.print("hello, world!\n", .{});
        // var value: []const u8 = "";
        // try root.napkin.editMetaStr(allocator, &value);
        try root.context.addNapkin(allocator, 128);
        return;
    }

    // context command
    if (std.mem.eql(u8, args[1], "context")) {
        try root.context.edit(allocator);
        return;
    }

    // new command
    if (std.mem.eql(u8, args[1], "new")) {
        try root.napkin.newNapkin(allocator);
        return;
    }

    // if it hasn't returned by now, then there are invalid arguments
    if (try cli.parseOption(args[1])) |_|
        return cli.Error.OptionNotFound
    else
        return cli.Error.CommandNotFound;
}

/// Prints a help message
fn printHelp() void {
    const help =
        \\Usage: napkin [options] [command] [command options]
        \\Commands:
        \\  test                    | A mere testing command.
        \\  list                    | Lists the napkins in a pretty format.
        \\  clean                   | Removes files from the napkin home that aren't referenced (locks too).
        \\  context                 | Opens and edits the context file.
        \\  new                     | Creates a new napkin and updates `context.yml`.
        \\  meta <uid>              | Edits the meta-data of a pre-existing napkin.
        \\  edit <uid>              | CoW edits the contents of a pre-existing napkin.
        \\  backup <path> -u <uids> | Exports the napkins of the specified uids (all if none are provided) as a tarball.
        \\  export <path> -u <uids> | Exports the napkins of the specified uids (all if none provided) as text files.
        \\  import (-b)? <path>     | Blindly imports the napkins stored in a tarball, taking the side of either the backup (when the 'b' flag is enabled) or the pre-existing napkin home.
        \\Options:
        \\  -h, --help    prints this help message
        \\  -V, --version prints the version
        \\
    ;
    std.debug.print(help, .{});
}
