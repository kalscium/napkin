//! Functions for dealing with yaml configuration files

const std = @import("std");

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
