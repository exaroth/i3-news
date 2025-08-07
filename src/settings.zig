const std = @import("std");

pub const default_settings =
    \\# I3 News configuration
    \\# =====================
    \\# Set amount of time in the past to display
    \\# articles for
    \\max-article-age 24
    \\# Color of the i3bar snippet display
    \\i3-bar-color #959692
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

    pub fn read(self: *Self) !void {
        var file = try std.fs.openFileAbsolute(self.path, .{});
        defer file.close();
        var arrl = std.ArrayList([]const u8).init(std.heap.page_allocator);
        defer arrl.deinit();
        var cmap = std.StringHashMap([]const u8).init(std.heap.page_allocator);
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
                try std.heap.page_allocator.dupe(u8, k),
                try std.heap.page_allocator.dupe(u8, v),
            );
        }
        self.raw = arrl.allocatedSlice();
        self.contents = cmap;
    }

    pub fn maxArticlesAge(self: Self) !usize {
        const age = self.contents.?.get("max-article-age");
        if (age == null) {
            return 24;
        }
        return try std.fmt.parseInt(usize, age.?, 10);
    }

    pub fn i3BarColor(self: Self) []const u8 {
        const color = self.contents.?.get("i3-bar-color");
        if (color == null) {
            return "#959696";
        }
        return color.?;
    }
};

pub const Line = std.meta.Tuple(&.{ []const u8, []const u8 });

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
