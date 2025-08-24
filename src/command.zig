const std = @import("std");
const utils = @import("utils.zig");
const cache = @import("cache.zig");
const settings = @import("settings.zig");

const Tuple = std.meta.Tuple;
const Cache = cache.Cache;
const urls_f_name = "urls";
const cache_f_name = "cache.db";
const settings_f_name = "config";
const ChildProcess = std.process.Child;

/// Create new config with given ID.
pub inline fn createConfig(config_name: []const u8) !void {
    const out_file = std.io.getStdOut().writer();
    const temp_id = utils.genRandomString(24);
    const tmp_path = "/tmp/" ++ temp_id;
    const cfg_path: []const u8, const cfg_dir_exists: bool = try utils.getConfigDir(config_name);
    if (cfg_dir_exists) {
        try out_file.print(
            "Config {s} already exists\n",
            .{config_name},
        );
        return;
    }

    try std.fs.makeDirAbsolute(tmp_path);
    defer utils.cleanupTemp(&temp_id);

    try std.fs.makeDirAbsolute(cfg_path);

    const temp_urls_fpath = tmp_path ++ "/" ++ urls_f_name;
    const url_f = try std.fs.createFileAbsolute(
        temp_urls_fpath,
        .{ .read = true },
    );
    defer url_f.close();
    try url_f.writeAll("# Insert list of urls for RSS feeds to track here,\n# one per line.\n ");
    try utils.openEditor(temp_urls_fpath);

    const temp_settings_fpath = tmp_path ++ "/" ++ settings_f_name;
    const settings_f = try std.fs.createFileAbsolute(
        temp_settings_fpath,
        .{ .read = true },
    );
    try settings_f.writeAll(settings.default_settings);

    try out_file.print(
        "Initializing news cache, please wait...\n",
        .{},
    );
    const temp_cache_fpath = tmp_path ++ "/" ++ cache_f_name;

    var n_process = ChildProcess.init(
        &[_][]const u8{ "newsboat", "-x", "reload", "-c", temp_cache_fpath, "-u", temp_urls_fpath },
        std.heap.page_allocator,
    );
    try n_process.spawn();
    _ = try n_process.wait();

    const c = try Cache.init(
        temp_cache_fpath,
    );
    try c.normalize_cache();

    try utils.copyDirContents(tmp_path, cfg_path);
    try out_file.print(
        "Configuration saved at {s}\n",
        .{cfg_path},
    );
}

/// Remove config with given id.
pub inline fn removeConfig(config_id: []const u8) !void {
    const out_file = std.io.getStdOut().writer();
    _, const config_exists: bool = try utils.getConfigDir(config_id);
    if (!config_exists) {
        try out_file.print("Config {s} does not exist\n", .{config_id});
        return;
    }
    var i3NewsDir = try utils.getI3NewsDir();
    defer i3NewsDir.close();
    try i3NewsDir.deleteTree(config_id);
    try out_file.print("Config {s} deleted\n", .{config_id});
    return;
}

pub inline fn editConfig(config_id: []const u8) !void {
    const out_file = std.io.getStdOut().writer();
    const cfpath: []const u8, const config_exists: bool = try utils.getConfigDir(config_id);
    if (!config_exists) {
        try out_file.print("Config {s} does not exist\n", .{config_id});
        return;
    }
    const p = [_][]const u8{ cfpath, urls_f_name };
    const full_path = try std.fs.path.join(
        std.heap.page_allocator,
        &p,
    );
    try utils.openEditor(full_path);
}

pub const Config = struct {
    const Self = @This();

    id: []const u8,
    cache: cache.Cache,
    settings: settings.ConfigSettings,

    pub fn init(config_id: []const u8) !Config {
        const cfpath: []const u8, const config_exists: bool = try utils.getConfigDir(config_id);
        if (!config_exists) {
            return error.ConfigDoesNotExist;
        }
        const s_path = try std.fs.path.join(
            std.heap.page_allocator,
            &[_][]const u8{ cfpath, "config" },
        );
        var s = try settings.ConfigSettings.init(s_path);
        try s.read();
        const c_path = try std.fs.path.joinZ(
            std.heap.page_allocator,
            &[_][]const u8{ cfpath, cache_f_name },
        );
        const c = try Cache.init(
            c_path,
        );
        return Config{
            .cache = c,
            .settings = s,
            .id = config_id,
        };
    }

    pub fn fetch_article(self: Self) !?Tuple(&.{
        [2048:0]u8,
        [2048:0]u8,
    }) {
        const max_age = try self.settings.maxArticlesAge();
        return try self.cache.fetch_article(max_age);
    }

    pub fn format(
        self: *const Config,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        return writer.print("Config for {s}", self.id);
    }
};

///Output i3 bar article
pub inline fn handleI3Blocks(config_id: []const u8) !void {
    const out_file = std.io.getStdOut().writer();
    const c = try Config.init(config_id);
    const article = try c.fetch_article();
    if (article != null) {
        const title: [2048:0]u8, const url: [2048:0]u8 = article.?;
        try out_file.print("{s}\n{s}\n", .{ title, url });
    } else {
        try out_file.print("News empty\nNews empty\n", .{});
    }
    try out_file.print("{s}\n", .{
        c.settings.i3BarColor(),
    });
}

// name, full_text, instance, color
const i3_status_payload = "[{{\"full_text\": \"{d}\", \"color\": \"#00FF00\"}},";
const I3StatusConfig = struct {
    name: []const u8,
    full_text: []const u8,
    instance: []const u8,
    color: []const u8,
};
///Output i3status articles
pub inline fn handleI3Status(config_ids: [][]const u8) !void {
    // const out_file = std.io.getStdOut().writer();
    var in_reader = std.io.getStdIn().reader();
    var buf: [4096]u8 = undefined;

    var read_no: u32 = 0;
    // var titles = std.ArrayList([]const u8);
    // std.debug.print("Debug: {any}\n", .{titles});
    while (true) {
        while (try in_reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            // Skip first 2 reads as these contain i3status version headers and initial bracket.
            if (read_no < 2) {
                read_no += 1;
                continue;
            }
            for (config_ids, 0..) |config_id, idx| {
                const c = try Config.init(config_id);
                const article = try c.fetch_article();
                if (article == null) {
                    continue;
                }
                const title: [2048:0]u8, _ = article.?;
                const i3sa = I3StatusConfig{
                    .name = "i3-news",
                    .full_text = &title,
                    .instance = try std.fmt.allocPrint(
                        std.heap.page_allocator,
                        "i3-news-{d}",
                        .{idx},
                    ),
                    .color = c.settings.i3BarColor(),
                };
                std.debug.print("Debug: {s}\n", .{i3sa.full_text});
                // var out = std.ArrayList(u8).init(std.heap.page_allocator);
                // try std.json.stringify(i3sa, .{}, out.writer());
                // std.debug.print("Debug: {s}\n", .{out.items});
            }

            // for (config_ids) |config_id| {}
            std.debug.print("STDIN: {s}\n", .{line});
            // parse json
            // for now remove first [ and insert parsed json in the beginning
            break;
        }
    }
}
