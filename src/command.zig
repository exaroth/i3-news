const std = @import("std");
const sqlite = @import("sqlite");
const known_folders = @import("known-folders");
const Tuple = std.meta.Tuple;

const ChildProcess = std.process.Child;

const config_f_name = "config.yaml";
const urls_f_name = "urls";
const news_cache_f_name = "cache.db";
const default_editor = "vim";
const i3_config_dirname: []const u8 = "i3_news";

pub const known_folders_config = .{
    .xdg_on_mac = false,
};

const table_update_q =
    \\ALTER TABLE rss_item ADD COLUMN read_no integer DEFAULT 0;
;
const fetch_news_q =
    \\WITH query (id, feed, title, pub_date, read_no)
    \\AS (
    \\
    \\    SELECT items.id as item_id,
    \\        feed.title as feed_title,
    \\        items.title as item_title,
    \\        items.pubDate as pub_date,
    \\        items.read_no as read_no
    \\        FROM rss_item as items
    \\    JOIN rss_feed as feed on feed.rssurl = items.feedurl
    \\    WHERE datetime(items.pubDate, 'unixepoch') >= datetime('now', '-1000 hours')
    \\    AND items.unread=1
    \\    
    \\)
    \\UPDATE rss_item SET read_no=read_no+1
    \\WHERE rss_item.id IN (
    \\    SELECT id FROM query
    \\    WHERE query.read_no=(SELECT MIN(query.read_no) FROM query)
    \\    ORDER BY query.pub_date DESC
    \\    LIMIT 1
    \\)
    \\ RETURNING rss_item.id, rss_item.title, rss_item.url, rss_item.read_no;
;

/// Generate random string with given length.
fn genRandomString(comptime len: u8) [len]u8 {
    const rand = std.crypto.random;
    var result: [len]u8 = undefined;
    for (result, 0..) |_, index| {
        result[index] = rand.intRangeAtMost(u8, 97, 122);
    }
    return result;
}

/// Cleanup temp dir.
fn cleanupTemp(tmp_id: []const u8) void {
    var tmp_dir = std.fs.openDirAbsolute("/tmp", .{}) catch {
        return;
    };
    defer tmp_dir.close();
    tmp_dir.deleteTree(tmp_id) catch return;
    return;
}

/// Retrieve directory used for storing i3news configs.
fn getI3NewsDir() !std.fs.Dir {
    var config_dir = try known_folders.open(
        std.heap.page_allocator,
        known_folders.KnownFolder.local_configuration,
        std.fs.Dir.OpenOptions{ .access_sub_paths = true },
    ) orelse unreachable;
    defer config_dir.close();
    const dir = try config_dir.makeOpenPath(i3_config_dirname, .{});
    return dir;
}

/// Result of config retrieval containing
/// both the path and boolean indicating whether
/// config exists or not.
const configDirResult = Tuple(&.{
    []const u8,
    bool,
});

/// Retrieve directory containing particular config.
fn getConfigDir(config_name: []const u8) !configDirResult {
    var i3Dir = try getI3NewsDir();
    defer i3Dir.close();
    const i3NewsPath = try i3Dir.realpathAlloc(
        std.heap.page_allocator,
        ".",
    );
    const rel_path = try std.fmt.allocPrint(
        std.heap.page_allocator,
        "{s}/",
        .{config_name},
    );
    const paths = [_][]const u8{ i3NewsPath, rel_path };
    const full_path = try std.fs.path.join(
        std.heap.page_allocator,
        &paths,
    );

    _ = std.fs.openDirAbsolute(full_path, .{}) catch {
        return .{ full_path, false };
    };
    return .{ full_path, true };
}

/// Recursively copy contents of one directory to another.
fn copyDirContents(src: []const u8, dest: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("leak");
    const allocator = gpa.allocator();

    // In order to walk the directry, `iterate` must be set to true.
    var dir = try std.fs.openDirAbsolute(src, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        const src_path = try std.fs.path.resolve(
            std.heap.page_allocator,
            &[_][]const u8{ src, entry.basename },
        );
        const dest_path = try std.fs.path.resolve(
            std.heap.page_allocator,
            &[_][]const u8{ dest, entry.basename },
        );
        try std.fs.copyFileAbsolute(src_path, dest_path, .{});
    }
}

/// Create new config with given ID.
pub inline fn createConfig(config_name: []const u8) !void {
    const out_file = std.io.getStdOut().writer();
    const temp_id = genRandomString(24);
    const tmp_path = "/tmp/" ++ temp_id;
    const cfg_path: []const u8, const cfg_dir_exists: bool = try getConfigDir(config_name);
    if (cfg_dir_exists) {
        try out_file.print(
            "Config {s} already exists\n",
            .{config_name},
        );
        return;
    }

    try std.fs.makeDirAbsolute(tmp_path);
    defer cleanupTemp(&temp_id);

    try std.fs.makeDirAbsolute(cfg_path);

    const temp_urls_fpath = tmp_path ++ "/" ++ urls_f_name;
    const url_f = try std.fs.createFileAbsolute(
        temp_urls_fpath,
        .{ .read = true },
    );
    defer url_f.close();
    try url_f.writeAll("# Insert list of urls for RSS feeds to track here,\n# one per line.\n ");

    var v_process = ChildProcess.init(
        &[_][]const u8{ "vim", "-o", temp_urls_fpath, "+3" },
        std.heap.page_allocator,
    );
    try v_process.spawn();
    _ = try v_process.wait();

    try out_file.print(
        "Initializing news cache, please wait...\n",
        .{},
    );
    const temp_cache_fpath = tmp_path ++ "/" ++ news_cache_f_name;

    var n_process = ChildProcess.init(
        &[_][]const u8{ "newsboat", "-x", "reload", "-c", temp_cache_fpath, "-u", temp_urls_fpath },
        std.heap.page_allocator,
    );
    try n_process.spawn();
    _ = try n_process.wait();

    // Update cache with custom column that tracks display count.
    var db = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = temp_cache_fpath },
        .open_flags = .{
            .write = true,
            .create = true,
        },
        .threading_mode = .MultiThread,
    });

    try db.exec(table_update_q, .{}, .{});
    try copyDirContents(tmp_path, cfg_path);
    try out_file.print(
        "Configuration saved at {s}\n",
        .{cfg_path},
    );
}

/// Remove config with given id.
pub inline fn removeConfig(config_id: []const u8) !void {
    const out_file = std.io.getStdOut().writer();
    _, const config_exists: bool = try getConfigDir(config_id);
    if (!config_exists) {
        try out_file.print("Config {s} does not exists\n", .{config_id});
        return;
    }
    var i3NewsDir = try getI3NewsDir();
    defer i3NewsDir.close();
    try i3NewsDir.deleteTree(config_id);
    try out_file.print("Config {s} deleted\n", .{config_id});
    return;
}
