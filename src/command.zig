const sqlite = @import("sqlite");
const std = @import("std");
const known_folders = @import("known-folders");

const ChildProcess = std.process.Child;

const config_f_name = "config.yaml";
const urls_f_name = "urls";
const news_cache_f_name = "cache.db";
const default_editor = "vim";

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

fn cleanupTemp(tmp_path: []const u8) void {
    std.fs.deleteDirAbsolute(tmp_path) catch {};
}

pub fn createConfig(config_name: []const u8) !void {
    const tmp_path = "/tmp/" ++ genRandomString(24);
    try std.fs.makeDirAbsolute(tmp_path);
    errdefer cleanupTemp(tmp_path);

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

    std.debug.print("Initializing news cache, please wait...\n", .{});
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
    var config_path = try known_folders.open(std.heap.page_allocator, known_folders.KnownFolder.local_configuration, std.fs.Dir.OpenOptions{ .access_sub_paths = true }) orelse unreachable;

    std.debug.print("Debug: {any}", .{config_path});
    std.debug.print("Debug: {s}", .{config_name});
    defer config_path.close();
    const d = try config_path.makeOpenPath("i3_news", std.fs.Dir.OpenOptions{ .access_sub_paths = true });
    std.debug.print("Debug: {any}", .{d});
    // const d_s = try d.stat(); // ignore unused
    // std.debug.print("Debug: {any}", .{d_s});
    // check if config already exists
    // check if main config file exists and directory structure
    cleanupTemp(tmp_path);
    // create config file
}
