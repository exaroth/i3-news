const std = @import("std");
const sqlite = @import("sqlite");
const utils = @import("utils.zig");

pub const cache_f_name = "cache.db";
const Tuple = std.meta.Tuple;

const table_normalize_q =
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
    \\    WHERE datetime(items.pubDate, 'unixepoch') >= datetime('now', ?)
    \\    AND items.unread=1
    \\    
    \\)
    \\UPDATE rss_item SET read_no=read_no+1
    \\WHERE rss_item.id IN (
    \\    SELECT id FROM query
    \\    WHERE query.read_no=(SELECT MIN(query.read_no) FROM query)
    \\    ORDER BY RANDOM()
    \\    LIMIT 1
    \\)
    \\ RETURNING rss_item.id, rss_item.title, rss_item.url, rss_item.read_no;
;

const table_mark_read_q =
    \\UPDATE rss_item SET unread=0 WHERE url = ?;
;

pub fn getDb(cache_path: [:0]const u8, write: bool, create: bool) !sqlite.Db {
    const db = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = cache_path },
        .open_flags = .{
            .write = write,
            .create = create,
        },
        .threading_mode = .MultiThread,
    });
    return db;
}

pub fn getDbForConfig(
    config_id: []const u8,
    allocator: std.mem.Allocator,
    write: bool,
    create: bool,
) !sqlite.Db {
    const cfpath: []const u8, const config_exists: bool = try utils.getConfigDir(
        allocator,
        config_id,
    );
    if (!config_exists) {
        return error.InvalidDb;
    }
    const c_path = try std.fs.path.joinZ(
        allocator,
        &[_][]const u8{ cfpath, cache_f_name },
    );
    return try getDb(
        c_path,
        write,
        create,
    );
}

pub fn normalizeCache(db: *sqlite.Db) !void {
    defer db.deinit();
    try db.exec(table_normalize_q, .{}, .{});
}

/// Result of retrieval of the article data from db.
pub const ArticleResult = Tuple(&.{
    []const u8,
    []const u8,
});

pub fn fetchArticle(
    db: *sqlite.Db,
    allocator: std.mem.Allocator,
    max_age: u16,
) !?ArticleResult {
    var diags = sqlite.Diagnostics{};
    var stmt = db.prepareWithDiags(
        fetch_news_q,
        .{ .diags = &diags },
    ) catch |err| {
        std.log.err("unable to prepare statement, got error {}. diagnostics: {s}", .{ err, diags });
        return err;
    };
    defer stmt.deinit();
    const t = try std.fmt.allocPrint(
        allocator,
        "-{d} hours",
        .{max_age},
    );
    const row = try stmt.oneAlloc(
        struct {
            id: usize,
            title: []const u8,
            url: []const u8,
            read_no: usize,
        },
        allocator,
        .{},
        .{ .t = t },
    );
    if (row) |r| {
        const title = try allocator.dupe(u8, r.title);
        const url = try allocator.dupe(u8, r.url);
        return .{ title, url };
    }
    return null;
}

pub fn markArticleRead(db: *sqlite.Db, url: []const u8) !void {
    var stmt = try db.prepare(table_mark_read_q);
    defer stmt.deinit();
    try stmt.exec(.{}, .{ .url = url });
}
