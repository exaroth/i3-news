const std = @import("std");
const args = @import("./args.zig");
const command = @import("./command.zig");

pub fn main() !u8 {
    const c = args.process_args() catch return 1;

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
        .output_i3bar => |c_name| {
            try command.handleI3Blocks(c_name);
        },
        .output_polybar => |c_name| {
            std.debug.print("outputting for polybar: {s}", .{c_name});
        },
        .output_i3status => |c_names| {
            std.debug.print("outputting for i3status: {any}", .{c_names});
        },
        .none => {
            std.debug.print("Error - no command received", .{});
            return 1;
        },
    }

    return 0;
}
