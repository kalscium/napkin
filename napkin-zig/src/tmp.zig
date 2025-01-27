//! Functions for dealing with user-input through temporary files

const std = @import("std");
const root = @import("root.zig");

/// Edits a file with the default editor
pub fn edit(allocator: std.mem.Allocator, path: []const u8) !void {
    // get environmental variables
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    // get the editor
    const editor = env_map.get("EDITOR")
        orelse env_map.get("VISUAL")
        orelse return error.EditorEnvVarUnset;

    // edit the file with the editor (command)
    var child = std.process.Child.init(&.{ editor, path }, allocator);
    child.stdin = std.io.getStdIn();
    child.stdout = std.io.getStdOut();
    child.stderr = std.io.getStdErr();
    const res = try child.spawnAndWait();

    // check if the command failed or not
    if (res.Exited != 0)
        return error.EditorNonZeroExitCode;
}

/// Edits a string through a temporary file, string is still owned by the
/// caller
pub fn editStr(allocator: std.mem.Allocator, string: *[]const u8, ext: []const u8) !void {
    const new_string = try readTmp(allocator, string.*, ext);
    allocator.free(string.*);
    string.* = new_string;
}

/// Creates a temporary file with an initial string and file extension and
/// returns the edited result that's owned by the caller
pub fn readTmp(allocator: std.mem.Allocator, initial: []const u8, ext: []const u8) ![]const u8 {
    // generate a random number/id
    var rng = std.Random.DefaultPrng.init(0);
    const id = rng.random().int(usize);

    // get the tmp dir
    const tmp_dir = try std.mem.concat(allocator, u8, &.{ try root.getHome(allocator), "/tmp" });
    defer allocator.free(tmp_dir);

    // create the tmp dir if it doesn't exist already
    if (std.fs.accessAbsolute(tmp_dir, .{})) {}
    else |err| {
        if (err == error.FileNotFound) {
            try std.fs.makeDirAbsolute(tmp_dir);
        } else {
            return err;
        }
    }

    // create a file-path for the tmp file
    const file_path = try std.fmt.allocPrint(allocator, "{s}/{}.{s}", .{
        tmp_dir,
        id,
        ext,
    });
    defer allocator.free(file_path);

    // write the initial text to the file
    var wfile = try std.fs.createFileAbsolute(file_path, .{});
    try wfile.writeAll(initial);
    wfile.close();

    // open and edit the file with the editor before saving the content
    try edit(allocator, file_path);
    var rfile = try std.fs.openFileAbsolute(file_path, .{ .mode = .read_only });
    const contents = rfile.readToEndAlloc(allocator, 1024 * 1024 * 1024); // GiB max size

    // delete the file
    try std.fs.deleteFileAbsolute(file_path);

    return contents;
}
