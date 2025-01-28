//! Functions for dealing with yaml configuration files

const std = @import("std");
const yaml = @import("yaml");

/// Annotates a string with an error by replacing it with the annotated version
pub fn annotateErr(
    allocator: std.mem.Allocator,
    string: *[]const u8,
    err: anyerror,
) !void {
    const new_string = try std.fmt.allocPrint(allocator, "### ERROR: {}\n{s}", .{err, string.*});
    allocator.free(string.*);
    string.* = new_string;
}

/// Reads a file to an allocated string that's owned by the caller
pub fn readToString(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    var file = try std.fs.openFileAbsolute(path, .{});
    const contents = try file.readToEndAlloc(allocator, 1024 * 1024 * 1024);
    file.close();
    return contents;
}

/// Writes to a file
pub fn writeToFile(bytes: []const u8, path: []const u8) !void {
    var file = try std.fs.createFileAbsolute(path, .{});
    try file.writeAll(bytes);
    file.close();
}
