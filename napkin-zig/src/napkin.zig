//! Functions for managing individual napkin entries

const std = @import("std");
const root = @import("root.zig");
const yaml = @import("yaml");
const datetime = @import("datetime");

pub const template =
    \\---
    \\filename: foo.bar
    \\name: bar
    \\description: foobar
    \\creation-date: {s}
    \\history:
    \\  {}:
    \\    date: {s}
    \\...
;

/// Gets the file extension of the provided filename
fn getExtension(filename: []const u8) []const u8 {
    var split = std.mem.splitScalar(u8, filename, '.');
    var current = split.first();
    while (split.next()) |scurrent| {
        current = scurrent;
    }
    return current;
}

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
        inline for (.{"filename", "name", "description", "creation-date", "history"}) |field| {
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
    var rfile = try std.fs.openFileAbsolute(meta_path, .{});
    var contents = try rfile.readToEndAlloc(allocator, 1024 * 1024 * 1024);
    defer allocator.free(contents);
    rfile.close();

    // make the user edit it until it's valid
    try editMetaStr(allocator, &contents);

    // write the changes to the metadata file
    var wfile = try std.fs.createFileAbsolute(meta_path, .{});
    try wfile.writeAll(contents);
    wfile.close();
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

    // lock context file
    var lock = try root.lock.lock(allocator, context_path);

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

    // get the file extension from the yaml configs
    var doc = try yaml.Yaml.load(allocator, metadata);
    defer doc.deinit();
    const filename = doc.docs.items[0].map.get("filename").?.string;
    const fileext = getExtension(filename);

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
    var fmeta = try std.fs.createFileAbsolute(meta_path, .{});
    try fmeta.writeAll(metadata);
    fmeta.close();
    var fcontent = try std.fs.createFileAbsolute(content_path, .{});
    try fcontent.writeAll("waiting for something to happen?\n");
    fcontent.close();
}
