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
    [2048:0]u8,
    [2048:0]u8,
});

pub const Cache = struct {
    const Self = @This();

    db: *sqlite.Db,

    pub fn init(
        cache_path: [:0]const u8,
        write: bool,
        create: bool,
    ) !Cache {
        var c = try sqlite.Db.init(.{
            .mode = sqlite.Db.Mode{ .File = cache_path },
            .open_flags = .{
                .write = write,
                .create = create,
            },
            .threading_mode = .MultiThread,
        });
        return Cache{ .db = &c };
    }

    pub fn normalize_cache(self: Self) !void {
        try self.db.exec(table_update_q, .{}, .{});
    }

    pub fn fetch_article(self: Self, max_age: usize) !?ArticleResult {
        var stmt = try self.db.prepare(fetch_news_q);
        defer stmt.deinit();
        const t = try std.fmt.allocPrint(
            std.heap.page_allocator,
            "-{d} hours",
            .{max_age},
        );
        const row = try stmt.one(
            struct {
                id: usize,
                title: [2048:0]u8,
                url: [2048:0]u8,
                read_no: usize,
            },
            .{},
            .{ .t = t },
        );
        if (row) |r| {
            return .{ r.title, r.url };
        }
        return null;
    }
};
