//! Functions for locking and unlocking crucial files

pub const std = @import("std");
pub const root = @import("root.zig");

pub const Lock = @This();
path: []const u8,
allocator: std.mem.Allocator,

/// Tries to lock a file, returning an error if it's already locked.
/// Returned lock is owned by the caller and must be freed with `unlock`
pub fn lock(allocator: std.mem.Allocator, path: []const u8) !Lock {
    // create the new path through concatination
    const lock_path = try std.mem.concat(allocator, u8, &.{ path, ".lock" });

    // check if it exists already
    if (try root.pathExists(lock_path))
        return error.FileAlreadyLocked;

    // create lock
    (try std.fs.createFileAbsolute(lock_path, .{})).close();
    return Lock{ .path = lock_path, .allocator = allocator };
}

/// Unlocks a file and free's it's internal path
pub fn unlock(self: *Lock) void {
    // try to delete the lock
    std.fs.deleteFileAbsolute(self.path) catch {};
    // free memory
    self.allocator.free(self.path);
}
