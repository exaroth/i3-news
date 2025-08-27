const std = @import("std");
const sqlite = @import("sqlite");

const Tuple = std.meta.Tuple;

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
    \\    WHERE datetime(items.pubDate, 'unixepoch') >= datetime('now', ?)
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

/// Result of retrieval of the article data from db.
pub const ArticleResult = Tuple(&.{
    []const u8,
    []const u8,
});

pub const Cache = struct {
    const Self = @This();

    cache_path: [:0]const u8,

    pub fn init(
        cache_path: [:0]const u8,
    ) !Cache {
        return Cache{ .cache_path = cache_path };
    }

    fn getDb(self: Self, write: bool, create: bool) !*sqlite.Db {
        var db = try sqlite.Db.init(.{
            .mode = sqlite.Db.Mode{ .File = self.cache_path },
            .open_flags = .{
                .write = write,
                .create = create,
            },
            .threading_mode = .MultiThread,
        });
        return &db;
    }

    pub fn normalizeCache(self: Self) !void {
        var db = try self.getDb(true, true);
        defer db.deinit();
        try db.exec(table_update_q, .{}, .{});
    }

    pub fn fetchArticle(
        self: Self,
        allocator: std.mem.Allocator,
        max_age: u16,
    ) !?ArticleResult {
        var db = try self.getDb(true, false);
        defer db.deinit();
        var stmt = try db.prepare(fetch_news_q);
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
};
