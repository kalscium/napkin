//! Functions for handling the cli interface for napkin

const std = @import("std");

/// Possible errors from parsing commandline arguments
pub const Error = error{
    /// Unexpected argument to the cli
    UnexpectedArg,
    /// Expected an argument that wasn't found
    ExpectedArg,
    /// Expected an option that wasn't found
    ExpectedOption,
    /// Expected a command that wasn't found
    ExpectedCommand,
    /// When the command provided was not found or expected
    CommandNotFound,
    /// The the option provided is invalid (syntax-wise)
    InvalidOption,
    /// When the option provided was not found or expected
    OptionNotFound,
};

/// Metadata for possible errors
pub const ErrorMeta = ?[:0]const u8;

/// Parses for a command
pub fn parseCommand(comptime Cmd: type, arg: [:0]const u8) Error!Cmd {
    // create an if-else chain to find the correct command
    const type_info = @typeInfo(Cmd).Enum;
    inline for (type_info.fields) |field| {
        // make the field-name lowercase
        comptime var lowercase: [field.name.len]u8 = [_]u8{0} ** field.name.len;
        _ = comptime std.ascii.lowerString(&lowercase, field.name);
        const rt_lowercase = lowercase;

        // compare
        if (std.mem.eql(u8, arg, &rt_lowercase))
            return @field(Cmd, field.name);
    }

    // if none of them match
    return Error.CommandNotFound;
}

/// Parses for an option and returns the option-name
pub fn parseOption(arg: [:0]const u8) Error!?[:0]const u8 {
    // make sure the argument is long enough
    if (arg.len < 2) return error.InvalidOption;

    // check for the '-' and set the offset for the option
    if (arg[0] != '-') return null;
    var offset: usize = 1;

    // check if the option is a longer word
    if (arg[1] == '-') offset = 2;

    // make sure the option is valid (`-help` is invalid)
    if (arg.len - offset > 1 and offset != 2) return error.InvalidOption;

    // make sure the option is long enough
    if (arg.len - offset == 0) return error.InvalidOption;

    return arg[offset..];
}
