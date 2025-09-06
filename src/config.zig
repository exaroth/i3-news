const std = @import("std");
const cache = @import("cache.zig");
const settings = @import("settings.zig");
const utils = @import("utils.zig");
const sqlite = @import("sqlite");

const settings_f_name = "config";
const last_url_f_name = ".last.url";

const Tuple = std.meta.Tuple;

/// Config holds data and methods associtated
/// with particular configuration.
pub const Config = struct {
    const Self = @This();

    id: []const u8,
    path: []const u8,
    settings: settings.ConfigSettings,

    /// Initialize new config based on the config id.
    pub fn init(allocator: std.mem.Allocator, config_id: []const u8) !Config {
        const cfpath: []const u8, const config_exists: bool = try utils.getConfigDir(
            allocator,
            config_id,
        );
        if (!config_exists) {
            return error.ConfigDoesNotExist;
        }
        const s_path = try std.fs.path.join(
            allocator,
            &[_][]const u8{ cfpath, settings_f_name },
        );
        var s = try settings.ConfigSettings.init(s_path);
        try s.read(allocator);
        return Config{
            .settings = s,
            .id = config_id,
            .path = cfpath,
        };
    }

    /// Retrieve single article from cache.
    pub fn fetchArticle(
        self: Self,
        db: *sqlite.Db,
        allocator: std.mem.Allocator,
    ) !?Tuple(&.{
        []const u8,
        []const u8,
    }) {
        const max_age = try self.settings.maxArticleAge();
        return try cache.fetchArticle(
            db,
            allocator,
            max_age,
        );
    }

    /// Save url file with url to currently displayed article.
    pub fn saveUrlFile(
        self: Self,
        allocator: std.mem.Allocator,
        url: []const u8,
    ) !void {
        const cfpath: []const u8, const config_exists: bool = try utils.getConfigDir(
            allocator,
            self.id,
        );
        if (!config_exists) {
            return;
        }
        const s_path = try std.fs.path.join(
            allocator,
            &[_][]const u8{ cfpath, last_url_f_name },
        );

        const f = try std.fs.createFileAbsolute(
            s_path,
            .{ .read = true },
        );
        try f.writeAll(url);
        return;
    }

    pub fn saveUrlFileSafe(
        self: Self,
        allocator: std.mem.Allocator,
        url: []const u8,
    ) void {
        self.saveUrlFile(allocator, url) catch return;
    }

    pub fn readUrlFile(self: Self, allocator: std.mem.Allocator) ![]const u8 {
        const s_path = try std.fs.path.join(
            allocator,
            &[_][]const u8{ self.path, last_url_f_name },
        );
        var file = try std.fs.openFileAbsolute(s_path, .{});
        defer file.close();
        var buf_reader = std.io.bufferedReader(
            file.reader(),
        );
        var in_stream = buf_reader.reader();
        var buf: [1024]u8 = undefined;
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            return allocator.dupe(u8, line);
        }
        return "about:blank";
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
