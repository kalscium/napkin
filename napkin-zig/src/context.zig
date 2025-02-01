//! Functions for dealing with the context yaml file

const std = @import("std");
const root = @import("root.zig");
const yaml = @import("yaml");

/// Initialises a new empty context file
pub fn initContext(path: []const u8) !void {
    const format =
        \\---
        \\version: 
        ++ root.version ++
        \\
        \\napkins: [ ]
        \\...
    ;

    try root.configs.writeToFile(format, path);
}

/// Gets the path to the context file.
/// Caller owns returned string.
pub fn getPath(allocator: std.mem.Allocator) ![]const u8 {
    const napkin_home = try root.getHome(allocator);
    defer allocator.free(napkin_home);

    const home = std.mem.concat(allocator, u8, &.{ napkin_home, "/context.yml" });
    return home;
}

/// Opens and edits the context file
pub fn edit(allocator: std.mem.Allocator) !void {
    const path = try getPath(allocator);
    defer allocator.free(path);

    // lock the context file
    var lock = try root.lock.lock(allocator, path);
    defer lock.unlock();

    // initialise a context file if there isn't one there already
    if (!try root.pathExists(path))
        try initContext(path);

    // open the file and read it's contents
    var contents: []const u8 = try root.configs.readToString(allocator, path);
    defer allocator.free(contents); // looks like it'll double-free, but it won't

    while (true) {
        // have the user edit it's contents and replace it
        try root.tmp.editStr(allocator, &contents, "yml");
        
        // parse it
        var doc = yaml.Yaml.load(allocator, contents) catch |err| {
            // if there is an error, add it to the contents and then make the user re-edit
            try root.configs.annotateErr(allocator, &contents, err);
            continue;
        };
        defer doc.deinit();

        // check for empty docs
        if (doc.docs.items.len == 0 or doc.docs.items[0] == .empty) {
            try root.configs.annotateErr(allocator, &contents, error.EmptyConfigs);
            continue;
        }
        
        const map = doc.docs.items[0].map;

        // check for the dump flag
        if (map.get("dump")) |dump|
            if (dump.boolean)
                return error.UserDumpInterrupt;

        // check for fields
        if (!map.contains("version") or !map.contains("napkins")) {
            try root.configs.annotateErr(allocator, &contents, error.ConfigFieldMissing);
            continue;
        }
        if (map.get("napkins").? != .list) {
            try root.configs.annotateErr(allocator, &contents, error.ContextEntriesFieldNotList);
            continue;
        }

        break;
    }

    // write the changes to the context file
    try root.configs.writeToFile(contents, path);
}

/// Checks if the versions are compatible
pub fn checkVersion(allocator: std.mem.Allocator) !void {
    // get the context path
    const context_path = try getPath(allocator);
    defer allocator.free(context_path);

    // check if it exists or not, init if not
    if (!try root.pathExists(context_path))
        return try initContext(context_path);

    // get the context contents
    const contents = try root.configs.readToString(allocator, context_path);
    defer allocator.free(contents);

    // parse the contents
    var context = try yaml.Yaml.load(allocator, contents);
    defer context.deinit();

    // primative ik
    var version = context.docs.items[0].map.get("version").?.string;
    version = std.mem.trim(u8, version, " \n\t");
    if (!std.mem.eql(u8, version, root.version))
        return error.VersionMismatch;
}

/// Checks if a napkin exists or not
pub fn napkinExists(allocator: std.mem.Allocator, uid: []const u8) !bool {
    // get the context path
    const path = try getPath(allocator);
    defer allocator.free(path);

    // read the contents of the file
    const contents = try root.configs.readToString(allocator, path);
    defer allocator.free(contents);

    // parse the doc
    var doc = try yaml.Yaml.load(allocator, contents);
    defer doc.deinit();

    // get and check the doc's current napkin list
    const list = doc.docs.items[0].map.get("napkins").?;
    for (list.list) |item| {
        if (std.mem.eql(u8, item.string, uid))
            return true;
    }

    return false;
}

/// Adds a napkin to the napkin list in the context configs file
pub fn addNapkin(allocator: std.mem.Allocator, uid: []const u8) !void {
    // get the context path
    const path = try getPath(allocator);
    defer allocator.free(path);

    // read the contents of the file
    const contents = try root.configs.readToString(allocator, path);
    defer allocator.free(contents);

    // parse the doc
    var doc = try yaml.Yaml.load(allocator, contents);
    defer doc.deinit();

    // get the napkin list
    const list = doc.docs.items[0].map.getPtr("napkins").?;

    // update the doc's napkin list
    const new_list = try std.mem.concat(
        allocator,
        yaml.Value,
        &.{ list.list, &.{yaml.Value{ .string = uid }} }
    );
    list.* = yaml.Value{ .list = new_list };

    // write the updated context back to the context file
    var wfile = try std.fs.createFileAbsolute(path, .{});
    try doc.stringify(&wfile.writer());
    wfile.close();
}

/// Prints the napkins in a context file in a pretty way
pub fn listNapkins(allocator: std.mem.Allocator) !void {
    try checkVersion(allocator);

    // get the context's contents
    const context_path = try getPath(allocator);
    defer allocator.free(context_path);
    const context_contents = try root.configs.readToString(allocator, context_path);
    defer allocator.free(context_contents);
    var doc = try yaml.Yaml.load(allocator, context_contents);
    defer doc.deinit();

    // get the list of napkins
    const napkins = doc.docs.items[0].map.get("napkins").?.list;

    // find the longest napkin uid
    var longest: usize = 0;
    for (napkins) |napkin| {
        const napkin_uid = napkin.string;
        if (napkin_uid.len > longest)
            longest = napkin_uid.len;
    }

    // print the napkins
    var stdout = std.io.getStdOut();
    for (napkins) |napkin| {
        // get the napkin's metadata
        const meta_path = try root.napkin.metaPath(allocator, napkin.string);
        defer allocator.free(meta_path);
        const meta_contents = try root.configs.readToString(allocator, meta_path);
        defer allocator.free(meta_contents);
        var metadata = try yaml.Yaml.load(allocator, meta_contents);
        defer metadata.deinit();

        // get the description
        const description = metadata.docs.items[0].map.get("description").?.string;

        // allocate the padding
        const padding = try allocator.alloc(u8, longest - napkin.string.len);
        defer allocator.free(padding);
        for (padding) |*char| {
            char.* = ' ';
        }

        // print the formatted string
        try std.fmt.format(stdout.writer(), "{s}{s} | {s}\n", .{
            napkin.string,
            padding,
            description,
        });
    }
}

/// Recursively returns a list (owned by the caller) of all the referenced files by the context
pub fn referencedFiles(allocator: std.mem.Allocator) ![]const []const u8 {
    // get the contents of the context.yml file
    const context_path = try getPath(allocator); // returned, do not dealloc
    const context_contents = try root.configs.readToString(allocator, context_path);
    defer allocator.free(context_contents);
    var context = try yaml.Yaml.load(allocator, context_contents);
    defer context.deinit();

    // get the list of napkins
    const napkins = context.docs.items[0].map.get("napkins").?.list;

    // get the list of paths
    var paths = std.ArrayList([]const u8).init(allocator);
    for (napkins) |napkin| {
        const napkin_paths = try root.napkin.referencedFiles(allocator, napkin.string);
        defer allocator.free(napkin_paths);
        try paths.appendSlice(napkin_paths);
    }

    // add the context file itself
    try paths.append(context_path);

    return paths.toOwnedSlice();
}

/// Exports the contents of a context file into a specified output directory
pub fn exportNapkins(allocator: std.mem.Allocator, out_path: []const u8, uids: []const []const u8) !void {
    // create the output directory if it doesn't exist already
    if (std.fs.cwd().access(out_path, .{})) {}
    else |err| switch (err) {
        error.FileNotFound => try std.fs.cwd().makeDir(out_path),
        else => return err,
    }

    // get the real path
    const abs_path = try std.fs.cwd().realpathAlloc(allocator, out_path);
    defer allocator.free(abs_path);

    // create the output directory if it doesn't exist already (abs)
    if (!try root.pathExists(abs_path))
        try std.fs.makeDirAbsolute(abs_path);

    // get the contents of the context.yml
    const context_path = try getPath(allocator);
    defer allocator.free(context_path);
    const context_contents = try root.configs.readToString(allocator, context_path);
    defer allocator.free(context_contents);
    var context = try yaml.Yaml.load(allocator, context_contents);
    defer context.deinit();

    // get the list of napkins
    const napkins = context.docs.items[0].map.get("napkins").?.list;

    // make sure all the provided uids are valid
    validate: for (uids) |uid| {
        for (napkins) |napkin|
            if (std.mem.eql(u8, uid, napkin.string))
                continue :validate;
        return error.NapkinNotFound;
    }

    // if none selected, then all selected
    var to_export = uids;
    if (uids.len == 0) {
        const all_uids = try allocator.alloc([]const u8, napkins.len);
        for (napkins, all_uids) |napkin, *uid|
            uid.* = napkin.string;
        to_export = all_uids;
    }
    defer if (uids.len == 0) allocator.free(to_export); // jesus

    // write to the files
    for (to_export) |napkin| {
        // get the latest edit id
        const id = try root.napkin.latest(allocator, napkin);
        defer allocator.free(id);

        // get the metadata
        const meta_path = try root.napkin.metaPath(allocator, napkin);
        defer allocator.free(meta_path);
        const meta_contents = try root.configs.readToString(allocator, meta_path);
        defer allocator.free(meta_contents);
        var metadata = try yaml.Yaml.load(allocator, meta_contents);
        defer metadata.deinit();

        // get the file extension
        const fext = metadata.docs.items[0].map.get("history").?.map.get(id).?.map.get("fext").?.string;

        // get the filename & final path
        const file_path = try std.fmt.allocPrint(allocator, "{s}/{s}.{s}", .{ abs_path, napkin, fext });
        defer allocator.free(file_path);
        std.debug.print("exporting napkin '{s}' to ", .{napkin});
        try std.fmt.format(std.io.getStdOut().writer(), "{s}\n", .{file_path});

        // get the contents
        const contents = try root.napkin.latestContents(allocator, napkin);
        defer allocator.free(contents);

        // write the contents to the final file
        try root.configs.writeToFile(contents, file_path);
    }
}

/// Backups up the contents of a context file into a specified output directory
pub fn backupNapkins(allocator: std.mem.Allocator, out_path: []const u8, uids: []const []const u8) !void {
    // create the output directory if it doesn't exist already
    if (std.fs.cwd().access(out_path, .{})) {}
    else |err| switch (err) {
        error.FileNotFound => try std.fs.cwd().makeDir(out_path),
        else => return err,
    }

    // get the real path
    const abs_path = try std.fs.cwd().realpathAlloc(allocator, out_path);
    defer allocator.free(abs_path);

    // create the output directory if it doesn't exist already (abs)
    if (!try root.pathExists(abs_path))
        try std.fs.makeDirAbsolute(abs_path);

    // get the contents of the context.yml
    const context_path = try getPath(allocator);
    defer allocator.free(context_path);
    const context_contents = try root.configs.readToString(allocator, context_path);
    defer allocator.free(context_contents);
    var context = try yaml.Yaml.load(allocator, context_contents);
    defer context.deinit();

    // get the list of napkins
    const napkins = context.docs.items[0].map.get("napkins").?.list;

    // make sure all the provided uids are valid
    validate: for (uids) |uid| {
        for (napkins) |napkin|
            if (std.mem.eql(u8, uid, napkin.string))
                continue :validate;
        return error.NapkinNotFound;
    }

    // if none selected, then all selected
    var to_export = uids;
    if (uids.len == 0) {
        const all_uids = try allocator.alloc([]const u8, napkins.len);
        for (napkins, all_uids) |napkin, *uid|
            uid.* = napkin.string;
        to_export = all_uids;
    }
    defer if (uids.len == 0) allocator.free(to_export); // jesus

    // get the base napkin-home path
    const home_path = try root.getHome(allocator);
    defer allocator.free(home_path);

    // create the napkins dir
    const napkins_path = try std.fmt.allocPrint(allocator, "{s}/napkins", .{abs_path});
    defer allocator.free(napkins_path);
    if (!try root.pathExists(napkins_path))
        try std.fs.makeDirAbsolute(napkins_path);

    // write to the files
    for (to_export) |napkin| {
        // get the referenced paths
        const paths = try root.napkin.referencedFiles(allocator, napkin);
        defer allocator.free(paths);

        // create the napin's path (if it doesn't exist already)
        const napkin_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ napkins_path, napkin });
        defer allocator.free(napkin_path);
        if (!try root.pathExists(napkin_path))
            try std.fs.makeDirAbsolute(napkin_path);

        for (paths) |path| {
            // trim and construct the final path
            const trimmed_path = path[home_path.len+1..];
            const file_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ abs_path, trimmed_path });
            defer allocator.free(file_path);
            std.debug.print("copying '{s}' to '{s}'\n", .{ path, file_path });
            try std.fs.copyFileAbsolute(path, file_path, .{});
        }
    }

    // write the context file too
    const context_trimmed = context_path[home_path.len+1..];
    const context_out = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ abs_path, context_trimmed });
    try std.fs.copyFileAbsolute(context_path, context_out, .{});
}
