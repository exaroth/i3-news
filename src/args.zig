const std = @import("std");
const argsParser = @import("args");

/// Command represents available commands
/// which can be invoked by i3-news along
/// with associated context.
pub const Command = union(enum) {
    /// Add new config
    add_config: []const u8,
    /// Remove existing config
    rm_config: []const u8,
    /// Edit config urls
    edit_config: []const u8,
    /// Output headlines for i3status
    output_i3status: [][]const u8,
    /// Output headlines for i3blocks
    output_i3blocks: []const u8,
    /// Output headlines for polybar
    output_polybar: []const u8,
    /// Waybar output
    output_waybar: []const u8,
    /// Plain output
    output_plain: []const u8,
    /// Fallback command
    get_url: []const u8,
    /// Fallback command
    none: void,
};

pub const CommandResult = std.meta.Tuple(&.{
    Command,
    bool,
});

pub const ErrorKind = union(enum) {
    /// When the argument itself is unknown
    unknown,

    /// When no configs were passed but expected
    no_configs_selected,

    /// Error for case when number of configs selected is invalid (i3blocks/polybar)
    invalid_config_num,

    /// When no output formats were specified
    no_outputs_specified,

    /// Error for case when user selected name of config with invalid characters
    invalid_config_name: []const u8,

    /// Error for case when user selected multiple output formats
    multiple_formats_selected,
};

/// This represents errors associated with argument processing.
const Error = struct {
    const Self = @This();

    kind: ErrorKind,

    /// Write error to stderr.
    pub fn write(self: Self) !void {
        const writer = std.io.getStdErr().writer();

        switch (self.kind) {
            .invalid_config_name => |val| try writer.print("Invalid characters in config name passed: {s}\n", .{val}),
            .multiple_formats_selected => try writer.writeAll("Multiple output formats selected. Please specify only one\n"),
            .no_outputs_specified => try writer.writeAll("No output formats were specified, use --help for full list\n"),
            .no_configs_selected => try writer.writeAll("At least one configuration has to be provided for output using -c argument\n"),
            .invalid_config_num => try writer.writeAll("This ouput option accepts at most 1 configuration\n"),
            .unknown => try writer.writeAll("Unhandled error when processing arguments\n"),
        }
    }
};

/// Raise custom errors related to argument processing.
pub fn raiseArgumentError(kind: ErrorKind) !void {
    const e = Error{ .kind = kind };
    try e.write();
    return error.InvalidArgument;
}

/// Represents array of configs for which we will output headlines for.
pub const ConfigArgs = struct {
    raw: []const u8,
    cfgs: std.ArrayList(ConfigArg),

    /// Load and parse configs into array.
    pub fn parse(input: []const u8) !ConfigArgs {
        var it = std.mem.splitSequence(u8, input, ",");
        var cfgs = std.ArrayList(ConfigArg).init(std.heap.page_allocator);
        while (it.next()) |raw_cfg| {
            const cfg = try ConfigArg.parse(raw_cfg);
            try cfgs.append(cfg);
        }
        const c = ConfigArgs{
            .raw = input,
            .cfgs = cfgs,
        };

        return c;
    }
};

const CONFIG_ALLOWED_CHARS = [_]u8{ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '_' };

/// Represents single config argument passed by the user.
pub const ConfigArg = struct {
    value: []const u8,

    fn checkCharactersValid(in: []const u8) bool {
        for (in) |char| {
            var found = false;
            for (CONFIG_ALLOWED_CHARS) |allowed| {
                if (char == allowed) {
                    found = true;
                    break;
                }
            }
            if (found == false) {
                return false;
            }
        }
        return true;
    }

    /// Parse command argument making sure no invalid chars
    /// are used in the name
    pub fn parse(input: []const u8) !ConfigArg {
        // check config name for invalid characters
        if (!checkCharactersValid(input)) {
            try raiseArgumentError(.{ .invalid_config_name = input });
        }
        return ConfigArg{ .value = input };
    }
};

/// This is representation of all available arguments available
/// to the user when invoking i3-news.
pub const Options = struct {
    /// Config names passed
    configs: ?ConfigArgs = null,
    /// Will trigger streaming output for i3status
    i3status: bool = false,
    /// Will trigger status output for i3blocks
    i3blocks: bool = false,
    /// Polybar output
    polybar: bool = false,
    /// Waybar output
    waybar: bool = false,
    /// Trigger creator allowing user to add new config
    @"add-config": ?ConfigArg = null,
    /// Remove existing config
    @"rm-config": ?ConfigArg = null,
    /// Edit config urls
    @"edit-config": ?ConfigArg = null,
    /// Retrieve url for the article
    @"get-url": bool = false,
    /// Plain mode
    plain: bool = false,
    /// Print debug
    debug: bool = false,
    /// Print help
    help: bool = false,

    /// Get number of output opts set.
    fn outOptNum(self: Options) u8 {
        var result: u8 = 0;
        var temp: u1 = 0;
        temp = @bitCast(self.i3blocks);
        result += temp;
        temp = @bitCast(self.i3status);
        result += temp;
        temp = @bitCast(self.polybar);
        result += temp;
        temp = @bitCast(self.waybar);
        result += temp;
        temp = @bitCast(self.plain);
        result += temp;
        return result;
    }

    pub const shorthands = .{
        .s = "i3status",
        .b = "i3blocks",
        .p = "polybar",
        .w = "waybar",
        .c = "configs",
        .h = "help",
        .a = "add-config",
        .r = "rm-config",
        .e = "edit-config",
    };

    pub const meta = .{
        .option_docs = .{
            .@"add-config" = "Add new i3-news configuration",
            .@"rm-config" = "Remove existing configuration",
            .@"edit-config" = "Edit urls for given configuration",
            .i3status = "I3status output",
            .i3blocks = "I3blocks output",
            .polybar = "Polybar output",
            .waybar = "Waybar output",
            .plain = "Plain output",
            .configs = "Snippet configuration or configurations to use",
            .@"get-url" = "Retrieve url for currently displayed headline",
            .debug = "Print debug info",
            .help = "Print help",
        },
    };
};

/// Process arguments passed by the user, if arguments are correct
/// return Command along with all context required for further processing.
pub inline fn processArgs() !CommandResult {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const argsAllocator = gpa.allocator();

    const parsed = try argsParser.parseForCurrentProcess(
        Options,
        argsAllocator,
        .print,
    );
    defer parsed.deinit();
    const opts = parsed.options;
    if (opts.help) {
        try argsParser.printHelp(Options, "i3news", std.io.getStdOut().writer());
    }
    if (opts.@"add-config" != null) {
        return .{
            Command{ .add_config = try argsAllocator.dupeZ(u8, opts.@"add-config".?.value) },
            opts.debug,
        };
    }
    if (opts.@"rm-config" != null) {
        return .{
            Command{ .rm_config = try argsAllocator.dupeZ(u8, opts.@"rm-config".?.value) },
            opts.debug,
        };
    }
    if (opts.@"edit-config" != null) {
        return .{
            Command{ .edit_config = try argsAllocator.dupeZ(u8, opts.@"edit-config".?.value) },
            opts.debug,
        };
    }

    if (opts.configs == null) {
        try raiseArgumentError(.no_configs_selected);
    }
    const cfgs = opts.configs.?.cfgs;

    if (opts.@"get-url") {
        if (cfgs.items.len > 1) {
            try raiseArgumentError(.invalid_config_num);
        }
        return .{
            Command{ .get_url = try argsAllocator.dupeZ(u8, cfgs.items[0].value) },
            opts.debug,
        };
    }
    const opts_num = opts.outOptNum();
    if (opts_num == 0) {
        try raiseArgumentError(.no_outputs_specified);
    }
    if (opts_num > 1) {
        try raiseArgumentError(.multiple_formats_selected);
    }
    if (opts.i3status) {
        if (cfgs.items.len == 0 or cfgs.items.len > 10) {
            try raiseArgumentError(.invalid_config_num);
        }
        const tc = try argsAllocator.alloc([]const u8, cfgs.items.len);
        for (cfgs.items, 0..) |c, idx| {
            tc[idx] = try argsAllocator.dupeZ(u8, c.value);
        }
        return .{
            Command{ .output_i3status = tc },
            opts.debug,
        };
    }
    if (cfgs.items.len > 1) {
        try raiseArgumentError(.invalid_config_num);
    }
    if (opts.i3blocks) {
        return .{
            Command{ .output_i3blocks = try argsAllocator.dupeZ(u8, cfgs.items[0].value) },
            opts.debug,
        };
    }
    if (opts.polybar) {
        return .{
            Command{ .output_polybar = try argsAllocator.dupeZ(u8, cfgs.items[0].value) },
            opts.debug,
        };
    }
    if (opts.waybar) {
        return .{
            Command{ .output_waybar = try argsAllocator.dupeZ(u8, cfgs.items[0].value) },
            opts.debug,
        };
    }
    if (opts.plain) {
        return .{
            Command{ .output_plain = try argsAllocator.dupeZ(u8, cfgs.items[0].value) },
            opts.debug,
        };
    }
    return .{
        Command.none,
        opts.debug,
    };
}
