const std = @import("std");

pub const default_settings =
    \\# I3 News configuration
    \\# =====================
    \\# Amount of time in the past (in hours) to display
    \\# news for
    \\max-article-age 24
    \\# Output color (hex)
    \\output-color #959692
    \\# Defines how often news will change when using i3-news with i3status
    \\# (in seconds)
    \\refresh-interval 10
    \\
;
pub const ConfigSettings = struct {
    const Self = @This();

    path: []const u8,
    raw: ?[][]const u8,
    contents: ?std.StringHashMap([]const u8),

    pub fn init(path: []const u8) !ConfigSettings {
        return ConfigSettings{
            .path = path,
            .raw = null,
            .contents = null,
        };
    }

    pub fn read(self: *Self, allocator: std.mem.Allocator) !void {
        var file = try std.fs.openFileAbsolute(self.path, .{});
        defer file.close();
        var arrl = std.ArrayList([]const u8).init(allocator);
        defer arrl.deinit();
        var cmap = std.StringHashMap([]const u8).init(allocator);
        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var buf: [2048]u8 = undefined;
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            const l = process_line(line);
            if (l == null) {
                continue;
            }
            try arrl.append(line);
            const k, const v = l.?;
            try cmap.put(
                try allocator.dupe(u8, k),
                try allocator.dupe(u8, v),
            );
        }
        self.raw = arrl.allocatedSlice();
        self.contents = cmap;
    }

    pub inline fn max_article_age(self: Self) !u16 {
        const age = self.contents.?.get("max-article-age");
        if (age == null) {
            return 24;
        }
        return try std.fmt.parseInt(u16, age.?, 10);
    }

    pub inline fn output_color(self: Self) []const u8 {
        const color = self.contents.?.get("output-color");
        if (color == null) {
            return "#959696";
        }
        return color.?;
    }

    pub inline fn refresh_interval(self: Self) !u64 {
        const interval = self.contents.?.get("refresh-interval");
        if (interval == null) {
            return 10;
        }
        return try std.fmt.parseInt(u64, interval.?, 10);
    }
};

pub const Line = std.meta.Tuple(&.{ []const u8, []const u8 });

/// Process single settings line
fn process_line(line: []u8) ?Line {
    if (std.mem.startsWith(u8, line, "#")) {
        return null;
    }
    const lline = std.mem.trim(u8, line, " ");
    if (lline.len == 0) {
        return null;
    }
    var parts = std.mem.splitSequence(u8, lline, " ");
    const k = parts.first();
    var v = parts.rest();
    if (v.len == 0) {
        // TODO err
        return null;
    }
    v = std.mem.trim(u8, v, " ");
    if (std.mem.startsWith(u8, v, "\"") and std.mem.endsWith(u8, v, "\"")) {
        v = std.mem.trim(u8, v, "\"");
    }
    if (std.mem.startsWith(u8, v, "\'") and std.mem.endsWith(u8, v, "\'")) {
        v = std.mem.trim(u8, v, "\'");
    }
    return .{ k, v };
}
