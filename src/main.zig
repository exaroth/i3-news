const std = @import("std");
const args = @import("./args.zig");

pub fn main() !u8 {
    const command = args.process_args() catch return 1;

    std.debug.print("Command called {any}\n", .{command});

    switch (command) {
        .add_config => |c_name| {
            std.debug.print("Adding config: {s}", .{c_name});
        },
        .rm_config => |c_name| {
            std.debug.print("removing config: {s}", .{c_name});
        },
        .output_i3bar => |c_name| {
            std.debug.print("outputting for i3bar: {s}", .{c_name});
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
