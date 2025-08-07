const std = @import("std");
const utils = @import("utils.zig");
const cache = @import("cache.zig");
const settings = @import("settings.zig");

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
        true,
        true,
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

///Output i3 bar article
pub inline fn handleI3Blocks(config_id: []const u8) !void {
    const out_file = std.io.getStdOut().writer();
    const cfpath: []const u8, const config_exists: bool = try utils.getConfigDir(config_id);
    if (!config_exists) {
        try out_file.print("Config {s} does not exist\n", .{config_id});
        return;
    }
    const s = try std.fs.path.join(
        std.heap.page_allocator,
        &[_][]const u8{ cfpath, "config" },
    );
    var cfg = try settings.ConfigSettings.init(s);
    try cfg.read();

    const cache_path = try std.fs.path.join(
        std.heap.page_allocator,
        &[_][]const u8{ cfpath, cache_f_name },
    );
    const terminated = try std.heap.page_allocator.dupeZ(
        u8,
        cache_path,
    );
    const max_age = try cfg.maxArticlesAge();

    const c = try Cache.init(
        terminated,
        true,
        false,
    );

    const article = try c.fetch_article(max_age);

    if (article != null) {
        const title: [2048:0]u8, const url: [2048:0]u8 = article.?;
        try out_file.print("{s}\n", .{title});
        try out_file.print("{s}\n", .{url});
    } else {
        try out_file.print("News empty\n", .{});
        try out_file.print("\n", .{});
    }
    try out_file.print("{s}\n", .{
        cfg.i3BarColor(),
    });
}
