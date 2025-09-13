const std = @import("std");
const cli_args = @import("./args.zig");
const command = @import("./command.zig");

pub const std_options: std.Options = .{
    .logFn = logFn,
    .log_level = .debug,
};

var log_level = std.log.Level.err;

fn logFn(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@intFromEnum(message_level) <= @intFromEnum(log_level)) {
        std.log.defaultLog(
            message_level,
            scope,
            format,
            args,
        );
    }
}

pub fn main() !u8 {
    const err_file = std.io.getStdErr().writer();
    const c: cli_args.Command, const debug: bool = cli_args.processArgs() catch return 1;
    if (debug) {
        log_level = std.log.Level.debug;
    }

    handleCommand(c) catch |err| {
        if (debug) {
            return err;
        } else {
            switch (err) {
                error.ConfigDoesNotExist => {
                    try err_file.print(
                        "Invalid configuration name\n",
                        .{},
                    );
                },
                else => {
                    try err_file.print(
                        "Error occured: {}, use --debug to see more info.\n",
                        .{err},
                    );
                },
            }
        }
        return 1;
    };

    return 0;
}

/// Handle particular command based on the cli arg.
fn handleCommand(c: cli_args.Command) !void {
    switch (c) {
        .add_config => |c_name| {
            try command.createConfig(c_name);
        },
        .rm_config => |c_name| {
            try command.removeConfig(c_name);
        },
        .edit_config => |c_name| {
            try command.editConfig(c_name);
        },
        .output_i3blocks => |params| {
            try command.handleI3Blocks(
                params.config_id,
                params.random,
                params.latest,
            );
        },
        .output_polybar => |params| {
            try command.handlePolybar(
                params.config_id,
                params.random,
                params.latest,
            );
        },
        .output_i3status => |params| {
            try command.handleI3Status(
                params.config_ids,
                params.random,
                params.latest,
            );
        },
        .output_waybar => |params| {
            try command.handleWaybar(
                params.config_id,
                params.random,
                params.latest,
            );
        },
        .output_plain => |params| {
            try command.handlePlainOutput(
                params.config_id,
                params.random,
                params.latest,
            );
        },
        .get_url => |c_name| {
            try command.getUrlForConfig(c_name);
        },
        .none => {
            return error.NoCommandReceived;
        },
    }
}
