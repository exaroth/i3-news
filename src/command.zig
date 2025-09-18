const std = @import("std");
const utils = @import("utils.zig");
const cache = @import("cache.zig");
const settings = @import("settings.zig");
const config = @import("config.zig");
const sqlite = @import("sqlite");

const urls_f_name = "urls";
const settings_f_name = "config";

const Tuple = std.meta.Tuple;
/// Create new config with given ID.
pub fn createConfig(config_name: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const out_file = std.io.getStdOut().writer();

    const cfg_path: []const u8, const cfg_dir_exists: bool = try utils.getConfigDir(
        allocator,
        config_name,
    );
    if (cfg_dir_exists) {
        try out_file.print(
            "Config {s} already exists\n",
            .{config_name},
        );
        return;
    }

    const temp_id = utils.genRandomString(24);
    const tmp_path = "/tmp/" ++ temp_id;
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
    try utils.openEditor(allocator, temp_urls_fpath);

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
    const temp_cache_fpath = tmp_path ++ "/" ++ cache.cache_f_name;

    try utils.newsboatReload(
        allocator,
        temp_cache_fpath,
        temp_urls_fpath,
    );
    var db = try cache.getDb(
        temp_cache_fpath,
        true,
        true,
    );
    try cache.normalizeCache(&db);

    try utils.copyDirContents(allocator, tmp_path, cfg_path);
    try out_file.print(
        "Configuration saved at {s}\n",
        .{cfg_path},
    );
}

/// Remove config with given id.
pub fn removeConfig(config_id: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const out_file = std.io.getStdOut().writer();
    _, const config_exists: bool = try utils.getConfigDir(
        allocator,
        config_id,
    );
    if (!config_exists) {
        try out_file.print("Config {s} does not exist\n", .{config_id});
        return;
    }
    var i3NewsDir = try utils.getI3NewsDir(allocator);
    defer i3NewsDir.close();
    try i3NewsDir.deleteTree(config_id);
    try out_file.print("Config {s} deleted\n", .{config_id});
    return;
}

/// Edit existing config urls file.
pub fn editConfig(config_id: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const out_file = std.io.getStdOut().writer();
    const cfpath: []const u8, const config_exists: bool = try utils.getConfigDir(
        allocator,
        config_id,
    );
    if (!config_exists) {
        try out_file.print("Config {s} does not exist\n", .{config_id});
        return;
    }
    const p = [_][]const u8{ cfpath, urls_f_name };
    const u_p = try std.fs.path.join(
        allocator,
        &p,
    );
    const c = [_][]const u8{ cfpath, cache.cache_f_name };
    const u_c = try std.fs.path.join(
        allocator,
        &c,
    );
    try utils.openEditor(allocator, u_p);
    try out_file.print(
        "Updating news cache, please wait...\n",
        .{},
    );
    try utils.newsboatReload(allocator, u_c, u_p);
}

fn getArticleForConfig(
    allocator: std.mem.Allocator,
    c: *config.Config,
    random: bool,
    latest: bool,
) !?Tuple(&.{
    []const u8,
    []const u8,
}) {
    var db = try cache.getDbForConfig(
        c.id,
        allocator,
        true,
        false,
    );
    defer db.deinit();
    errdefer c.saveUrlFileSafe(allocator, "about:blank\n");
    const article = try c.fetchArticle(
        &db,
        allocator,
        random,
        latest,
    );
    if (article != null) {
        _, const url: []const u8 = article.?;
        try c.saveUrlFile(allocator, url);
    } else {
        try c.saveUrlFile(allocator, "about:blank\n");
    }
    return article;
}

///Output i3bar article
pub fn handleI3Blocks(config_id: []const u8, random: bool, latest: bool) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const out_file = std.io.getStdOut().writer();
    var c = try config.Config.init(
        allocator,
        config_id,
    );
    const article = try getArticleForConfig(allocator, &c, random, latest);
    if (article != null) {
        const title: []const u8, _ = article.?;
        try out_file.print("{s}\n{s}\n", .{ title, config_id });
    } else {
        try out_file.print("News empty\nNews empty\n", .{});
    }
    try out_file.print("{s}\n", .{
        c.settings.outputColor(),
    });
}

const I3StatusConfig = struct {
    name: []const u8,
    full_text: []const u8,
    instance: []const u8,
    color: []const u8,
};

///Output i3status articles
pub fn handleI3Status(config_ids: [][]const u8, random: bool, latest: bool) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const out_file = std.io.getStdOut().writer();
    var in_reader = std.io.getStdIn().reader();
    var buf: [4096]u8 = undefined;

    const c_cache = try allocator.alloc(
        ?std.meta.Tuple(&.{
            u64,
            []const u8,
        }),
        config_ids.len,
    );
    @memset(c_cache, null);

    const c_s = try allocator.alloc(
        config.Config,
        config_ids.len,
    );
    const c_d = try allocator.alloc(
        sqlite.Db,
        config_ids.len,
    );
    for (config_ids, 0..) |config_id, idx| {
        const c = try config.Config.init(
            allocator,
            config_id,
        );
        const db = try cache.getDbForConfig(
            config_id,
            allocator,
            true,
            false,
        );
        c_s[idx] = c;
        c_d[idx] = db;
    }

    for (config_ids, 0..) |config_id, idx| {
        const c = try config.Config.init(
            allocator,
            config_id,
        );
        c_s[idx] = c;
    }

    var timer = try std.time.Timer.start();
    var read_no: u8 = 0;
    while (true) {
        while (try in_reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            // Skip first 2 reads as these contain i3status version
            // headers and initial bracket.(kw)
            if (read_no < 2) {
                read_no += 1;
                try out_file.print("{s}\n", .{line});
                continue;
            }
            var c_list = try allocator.alloc(
                []const u8,
                config_ids.len,
            );
            defer allocator.free(c_list);
            for (config_ids, 0..) |_, idx| {
                var c = c_s[idx];
                if (c_cache[idx]) |cached| {
                    const t_set: u64, const article: []const u8 = cached;
                    const c_set = try c.settings.refreshInterval();
                    if (t_set / std.time.ms_per_s < c_set) {
                        c_list[idx] = article;
                        const t_u = t_set + (timer.read() / std.time.ns_per_ms);
                        c_cache[idx] = .{ t_u, article };
                        continue;
                    }
                }
                const article = try c.fetchArticle(
                    &c_d[idx],
                    allocator,
                    random,
                    latest,
                );
                var title: []const u8 = "";
                if (article != null) {
                    title, _ = article.?;
                }
                const i3sa = I3StatusConfig{
                    .name = "i3-news",
                    .full_text = title,
                    .instance = try std.fmt.allocPrint(
                        allocator,
                        "i3-news-{d}",
                        .{idx},
                    ),
                    .color = c.settings.outputColor(),
                };
                var out = std.ArrayList(u8).init(allocator);
                defer out.deinit();
                try std.json.stringify(
                    i3sa,
                    .{},
                    out.writer(),
                );
                const article_d = try allocator.dupe(u8, out.items);

                c_cache[idx] = .{ 0, article_d };
                c_list[idx] = article_d;
            }

            var line_strip: []const u8 = try allocator.dupe(u8, line);
            var has_prefix = false;

            if (line.len < 3) continue;
            if (std.mem.eql(u8, line[0..1], ",")) {
                line_strip = std.mem.trimLeft(u8, line_strip, ",");
                has_prefix = true;
            }
            line_strip = std.mem.trimLeft(u8, line_strip, "[");
            const c_joined = try std.mem.join(
                allocator,
                ",",
                c_list,
            );
            var result = try std.fmt.allocPrint(
                allocator,
                "[{s},{s}",
                .{ c_joined, line_strip },
            );
            if (has_prefix) {
                result = try std.fmt.allocPrint(
                    allocator,
                    ",{s}",
                    .{result},
                );
            }
            timer.reset();
            try out_file.print("{s}\n", .{result});
        }
    }
}

// Polybar handler.
pub fn handlePolybar(config_id: []const u8, random: bool, latest: bool) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const out_file = std.io.getStdOut().writer();
    var c = try config.Config.init(allocator, config_id);
    const article = try getArticleForConfig(allocator, &c, random, latest);
    var title: []const u8 = "News empty";
    if (article != null) {
        title, _ = article.?;
    }

    try out_file.print(
        "%{{F{s}}}{s}%{{F-}}\n",
        .{ c.settings.outputColor(), title },
    );
    return;
}

const waybarPayload = struct {
    text: []const u8,
    class: []const u8,
};

pub fn handleWaybar(config_id: []const u8, random: bool, latest: bool) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const out_file = std.io.getStdOut().writer();
    var c = try config.Config.init(allocator, config_id);
    const article = try getArticleForConfig(allocator, &c, random, latest);
    var title: []const u8 = "News empty";
    if (article != null) {
        title, _ = article.?;
    }
    const payload = waybarPayload{
        .text = title,
        .class = config_id,
    };
    const payload_s = try std.json.stringifyAlloc(
        allocator,
        payload,
        .{},
    );
    defer allocator.free(payload_s);

    try out_file.print("{s}\n", .{payload_s});
    return;
}

pub fn handlePlainOutput(config_id: []const u8, random: bool, latest: bool) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const out_file = std.io.getStdOut().writer();
    var c = try config.Config.init(allocator, config_id);
    const article = try getArticleForConfig(allocator, &c, random, latest);
    var title: []const u8 = "News empty";
    if (article != null) {
        title, _ = article.?;
    }
    try out_file.print("{s}\n", .{title});
    return;
}

/// Retrieve url for currently displayed config (Polybar/Waybar only).
pub fn getUrlForConfig(config_id: []const u8) !void {
    const out_file = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var db = try cache.getDbForConfig(
        config_id,
        allocator,
        true,
        false,
    );
    defer db.deinit();
    const c = try config.Config.init(allocator, config_id);
    const url = try c.readUrlFile(allocator);
    if (c.settings.markAsReadOnOpen()) {
        try cache.markArticleRead(&db, url);
    }
    try out_file.print("{s}\n", .{url});
    return;
}
