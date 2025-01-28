//! Functions for managing individual napkin entries

const std = @import("std");
const root = @import("root.zig");
const yaml = @import("yaml");
const datetime = @import("datetime");

pub const template =
    \\---
    \\name: foo
    \\fileext: txt
    \\description: bar
    \\creation-date: {s}
    \\history:
    \\    {}:
    \\        fileext: txt
    \\        datetime: {s}
    \\...
;

/// Makes the user edit the meta-data until it's valid.
/// This returns the value through modifying the provided string.
/// The modified string is still owned by the caller.
pub fn editMetaStr(allocator: std.mem.Allocator, contents: *[]const u8) !void {
    loop: while (true) {
        // edit the string
        try root.tmp.editStr(allocator, contents, "yml");

        // parse it as yaml
        var doc = yaml.Yaml.load(allocator, contents.*) catch |err| {
            // if there is an error, add it to the contents and then make the user re-edit
            try root.configs.annotateErr(allocator, contents, err);
            continue;
        };
        defer doc.deinit();

        // check for empty docs
        if (doc.docs.items.len == 0 or doc.docs.items[0] == .empty) {
            try root.configs.annotateErr(allocator, contents, error.EmptyConfigs);
            continue;
        }

        const map = doc.docs.items[0].map;

        // check for the dump flag
        if (map.get("dump")) |dump|
            if (dump.boolean)
                return error.UserDumpInterrupt;

        // check for fields
        inline for (.{"name", "fileext", "description", "creation-date", "history"}) |field| {
            if (!map.contains(field)) {
                try root.configs.annotateErr(allocator, contents, error.MissingMetaConfigField);
                continue :loop;
            }
        }

        break;
    }
}

/// Returns the meta-data path of a napkin that's owned by the caller
pub fn metaPath(allocator: std.mem.Allocator, id: i128) ![]const u8 {
    const home_path = try root.getHome(allocator);
    defer allocator.free(home_path);
    const path = try std.fmt.allocPrint(allocator, "{s}/{}/meta.yml", .{ home_path, id });
    return path;
}

/// Makes the user edit the meta-data of a pre-existing napkin
pub fn editMeta(allocator: std.mem.Allocator, id: i128) !void {
    try root.context.checkVersion(allocator);

    // get the meta-data path
    const meta_path = try metaPath(allocator, id);
    defer allocator.free(meta_path);

    // check if the meta-data file exists or not
    if (!try root.pathExists(meta_path))
        return error.NapkinNotFound;
    
    // lock the metadata
    var lock = try root.lock.lock(allocator, meta_path);
    defer lock.unlock();

    // open the file and get it's contents
    var contents = try root.configs.readToString(allocator, meta_path);
    defer allocator.free(contents);

    // make the user edit it until it's valid
    try editMetaStr(allocator, &contents);

    // write the changes to the metadata file
    try root.configs.writeToFile(contents, meta_path);
}

/// Creates a new napkin and updates the context.yml
pub fn newNapkin(allocator: std.mem.Allocator) !void {
    // get the context.yml path
    const context_path = try root.context.getPath(allocator);
    defer allocator.free(context_path);

    // get the current time
    const now = datetime.datetime.Datetime.now();
    const now_timestamp = now.toTimestamp();
    const now_iso8601 = try now.formatISO8601(allocator, true);
    defer allocator.free(now_iso8601);

    try root.context.checkVersion(allocator);

    // lock context file
    var lock = try root.lock.lock(allocator, context_path);
    defer lock.unlock();

    // get the user-edited meta-data
    var metadata = try std.fmt.allocPrint(allocator, template, .{
        now_iso8601,
        now_timestamp,
        now_iso8601,
    });
    defer allocator.free(metadata);
    try editMetaStr(allocator, &metadata);

    // unlock for the addNapkin to work without errors
    lock.unlock();

    // add the napkin to context.yml (also handles napkins already existing)
    try root.context.addNapkin(allocator, now_timestamp);

    lock = try root.lock.lock(allocator, context_path); // to continue to lock after addNapkin

    // get the file extension from the yaml configs
    var doc = try yaml.Yaml.load(allocator, metadata);
    defer doc.deinit();
    const fileext = doc.docs.items[0].map.get("fileext").?.string;

    // get the paths
    const home_path = try root.getHome(allocator);
    defer allocator.free(home_path);
    const napkin_path = try std.fmt.allocPrint(allocator, "{s}/{}", .{ home_path, now_timestamp });
    defer allocator.free(napkin_path);
    const meta_path = try metaPath(allocator, now_timestamp);
    defer allocator.free(meta_path);
    const content_path = try std.fmt.allocPrint(allocator, "{s}/{}.{s}", .{ napkin_path, now_timestamp, fileext });
    defer allocator.free(content_path);
    
    // write everything to the napkin home
    try std.fs.makeDirAbsolute(napkin_path);
    try root.configs.writeToFile(metadata, meta_path);
    try root.configs.writeToFile("waiting for something to happen?\n", content_path);

    // write the result to stdout & stderr
    std.debug.print("initialised napkin id: ", .{});
    var stdout = std.io.getStdOut();
    try std.fmt.format(stdout.writer(), "{}\n", .{now_timestamp});
}

/// Returns the latest version of a napkin's contents, owned by the caller
pub fn latestContents(allocator: std.mem.Allocator, nid: i128) ![]const u8 {
    // get the path to the napkin metadata
    const meta_path = try metaPath(allocator, nid);
    defer allocator.free(meta_path);

    // check if it exists or not
    if (!try root.pathExists(meta_path))
        return error.NapkinNotFound;

    // read the contents of the metadata
    const meta_str = try root.configs.readToString(allocator, meta_path);
    defer allocator.free(meta_str);

    // parse the contents of the metadata
    var metadata = try yaml.Yaml.load(allocator, meta_str);
    defer metadata.deinit();

    // get the latest (largest) napkin id and it's file extension
    const napkins = metadata.docs.items[0].map.get("history").?.map.keys();
    var id: i128 = 0;
    var fileext: []const u8 = undefined;
    for (napkins) |napkin| {
        const val = try std.fmt.parseInt(i128, napkin, 0);
        if (val > id) {
            id = val;
            fileext = metadata
                .docs
                .items[0]
                .map
                .get("history").?
                .map
                .get(napkin).?
                .map
                .get("fileext").?
                .string;
        }
    }

    // construct the path
    const home_path = try root.getHome(allocator);
    defer allocator.free(home_path);
    const content_path = try std.fmt.allocPrint(allocator, "{s}/{}/{}.{s}", .{ home_path, nid, id, fileext });
    defer allocator.free(content_path);

    // read the contents of it
    const contents = try root.configs.readToString(allocator, content_path);
    return contents;
}

/// Makes the user CoW edit a napkin's content while automatically updating it's meta.yml
pub fn edit(allocator: std.mem.Allocator, id: i128) !void {
    try root.context.checkVersion(allocator);

    // get the meta & home paths
    const meta_path = try metaPath(allocator, id);
    defer allocator.free(meta_path);
    const home_path = try root.getHome(allocator);
    defer allocator.free(home_path);

    // check if the meta-data file exists or not
    if (!try root.pathExists(meta_path))
        return error.NapkinNotFound;

    // aquire a lock on the metadata
    var lock = try root.lock.lock(allocator, meta_path);
    defer lock.unlock();

    // open the meta-data file
    const meta_str = try root.configs.readToString(allocator, meta_path);
    defer allocator.free(meta_str);
    var metadata = try yaml.Yaml.load(allocator, meta_str);
    defer metadata.deinit();

    // get the file extension
    const fileext = metadata.docs.items[0].map.get("fileext").?.string;

    // get the latest contents
    const contents = try latestContents(allocator, id);
    defer allocator.free(contents);

    // get the time
    const time = datetime.datetime.Datetime.now();
    const timestamp = time.toTimestamp();
    const timestamp_iso8601 = try time.formatISO8601(allocator, true);
    defer allocator.free(timestamp_iso8601);

    // create the new contents file with the extension
    const new_content_path = try std.fmt.allocPrint(allocator, "{s}/{}/{}.{s}", .{ home_path, id, timestamp, fileext });
    defer allocator.free(new_content_path);
    try root.configs.writeToFile(contents, new_content_path);

    // have the user edit the contents
    try root.tmp.edit(allocator, new_content_path);

    // update the metadata (done through string formatting due to strange
    // errors with the array_hash_map)
    const format =
        \\{s}
        \\    {}:
        \\        fileext: {s}
        \\        datetime: {s}
        \\...
    ;
    var new_meta = try std.fmt.allocPrint(allocator, format, .{
        std.mem.trimRight(u8, meta_str, " \n\t."), // bit hacky, but works
        timestamp,
        fileext,
        timestamp_iso8601,
    });
    defer allocator.free(new_meta);
    
    // have the user edit the new metadata
    try editMetaStr(allocator, &new_meta);

    // write the final metadata to the meta-data path
    try root.configs.writeToFile(new_meta, meta_path);
}
