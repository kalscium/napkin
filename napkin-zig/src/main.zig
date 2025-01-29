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
        return;
    }

    // context command
    if (std.mem.eql(u8, args[1], "context")) {
        try root.context.edit(allocator);
        return;
    }

    // new command
    if (std.mem.eql(u8, args[1], "new")) {
        // get the uid & file extension
        if (args.len < 4) {
            printHelp();
            return error.ExpectedArgument;
        }

        const uid = args[2];
        const fext = args[3];

        try root.napkin.newNapkin(allocator, uid, fext);
        return;
    }

    // meta command
    if (std.mem.eql(u8, args[1], "meta")) {
        // get the id
        if (args.len < 3) {
            printHelp();
            return error.ExpectedArgument;
        }

        const id = args[2];

        try root.napkin.editMeta(allocator, id);
        return;
    }

    // edit command
    if (std.mem.eql(u8, args[1], "edit")) {
        // get the id
        if (args.len < 3) {
            printHelp();
            return error.ExpectedArgument;
        }

        const id = args[2];

        try root.napkin.edit(allocator, id);
        return;
    }

    // latest command
    if (std.mem.eql(u8, args[1], "latest")) {
        // get the id
        if (args.len < 3) {
            printHelp();
            return error.ExpectedArgument;
        }

        const uid = args[2];

        // get the contents
        const latest = try root.napkin.latestContents(allocator, uid);
        defer allocator.free(latest);

        // print details
        std.debug.print("<<< CONTENTS OF {s} >>>\n", .{uid});

        // print the contents
        var stdout = std.io.getStdOut();
        try std.fmt.format(stdout.writer(), "{s}", .{latest});
        return;
    }

    if (std.mem.eql(u8, args[1], "list")) {
        // print a quick header
        std.debug.print("<<< NAPKINS >>>\n", .{});

        // print the rest of the napkins
        try root.context.listNapkins(allocator);

        return;
    }

    if (std.mem.eql(u8, args[1], "export")) {
        if (args.len < 3) {
            printHelp();
            return error.ExpectedArgument;
        }

        // get the output path
        const output_path = args[2];

        var uids: []const []const u8 = &.{};

        // check for user-provided uids
        if (args.len > 4)
        if (try root.cli.parseOption(args[3])) |option| {
            if (!std.mem.eql(u8, option, "u") and !std.mem.eql(u8, option, "uids"))
                return error.UnexpectedOption;

            uids = args[4..];
        };

        // export the napkins
        try root.context.exportNapkins(allocator, output_path, uids);

        return;
    }

    if (std.mem.eql(u8, args[1], "clean")) {
        // get all the referenced paths
        const referenced = try root.context.referencedFiles(allocator);
        defer allocator.free(referenced);

        // get all the paths
        const home_path = try root.getHome(allocator);
        defer allocator.free(home_path);
        const all = try root.dirFiles(allocator, home_path);
        defer allocator.free(all);

        // remove the differences
        rm: for (all) |path| {
            const abs_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ home_path, path });
            defer allocator.free(abs_path);

            for (referenced) |reference| {
                if (std.mem.eql(u8, reference, abs_path))
                    continue :rm;
            }

            std.debug.print("deleting unreferenced file: {s}\n", .{abs_path});
            try std.fs.deleteFileAbsolute(abs_path);
        }

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
        \\  new  <uid> <fext>       | Creates a new napkin with the specified uid and file extension and updates `context.yml`.
        \\  meta <uid>              | Edits the meta-data of a pre-existing napkin.
    	\\  latest <uid>            | prints the latest version/edit of of a napkin.
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
