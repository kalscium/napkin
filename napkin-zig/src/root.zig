const std = @import("std");
const datetime = @import("datetime");

pub const cli = @import("cli.zig");
pub const tmp = @import("tmp.zig");
pub const context = @import("context.zig");
pub const napkin = @import("napkin.zig");
pub const configs = @import("configs.zig");
pub const lock = @import("lock.zig");

/// The version of napkin
pub const version = "0.0.0";

/// Gets the napkin home-directory path as an allocated string that is owned
/// by the caller
pub fn getHome(allocator: std.mem.Allocator) ![]const u8 {
    // get env map
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    // get the user-home
    const user_home = env_map.get("HOME") orelse return error.HomeEnvVarUnset;

    // construct and allocate the napkin home
    const home = try std.mem.concat(allocator, u8, &.{ user_home, "/.napkin" });

    // if the directory doesn't exist, then create it
    if (!try pathExists(home)) {
        try std.fs.makeDirAbsolute(home);
    }

    // return the home directory
    return home;
}

/// Checks if a file or dir exists or not
pub fn pathExists(path: []const u8) !bool {
    if (std.fs.accessAbsolute(path, .{}))
        return true
    else |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    }
}
