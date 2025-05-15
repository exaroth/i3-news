const std = @import("std");
const args = @import("./args.zig");
const command = @import("./command.zig");

pub fn main() !u8 {
    const c = args.process_args() catch return 1;

    std.debug.print("Command called {any}\n", .{c});

    switch (c) {
        .add_config => |c_name| {
            // std.debug.print("Adding config: {s}", .{c_name});
            try command.createConfig(c_name);
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

    // var stmt = try db.prepare(fetch_news_q);
    // defer stmt.deinit();
    // const allocator = std.heap.page_allocator; // Use a suitable allocator
    // std.debug.print("Debug: 1", .{});
    // _ = try stmt.all([]const u8, allocator, .{}, .{});
    // std.debug.print("Debug: 1", .{});
    // std.debug.print("Debug: {d}", .{names.len});
    // for (names) |name| {
    //     std.log.debug("name: {s}", .{name});
    // }

    return 0;
}
