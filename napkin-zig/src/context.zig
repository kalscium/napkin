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

    var file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();
    try file.writeAll(format);
}

/// Gets the path to the context file.
/// Caller owns returned string.
pub fn contextPath(allocator: std.mem.Allocator) ![]const u8 {
    const napkin_home = try root.getHome(allocator);
    defer allocator.free(napkin_home);

    const home = std.mem.concat(allocator, u8, &.{ napkin_home, "/context.yml" });
    return home;
}

/// Opens and edits the context file
pub fn openContext(allocator: std.mem.Allocator) !void {
    const path = try contextPath(allocator);
    defer allocator.free(path);

    // lock the context file
    var lock = try root.lock.lock(allocator, path);
    defer lock.unlock();

    // initialise a context file if there isn't one there already
    if (!try root.pathExists(path))
        try initContext(path);

    // open the file and read it's contents
    var file = try std.fs.openFileAbsolute(path, .{});
    var contents: []const u8 = try file.readToEndAlloc(allocator, 1024 * 1024 * 1024);
    file.close();
    defer allocator.free(contents); // looks like it'll double-free, but it won't

    while (true) {
        // have the user edit it's contents and replace it
        try root.tmp.editStr(allocator, &contents, ".yml");
        
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
    file = try std.fs.createFileAbsolute(path, .{});
    try file.writeAll(contents);
    file.close();
}
