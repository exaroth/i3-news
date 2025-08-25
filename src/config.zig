const std = @import("std");
const cache = @import("cache.zig");
const settings = @import("settings.zig");
const utils = @import("utils.zig");

pub const cache_f_name = "cache.db";
const settings_f_name = "config";
const last_url_f_name = ".last.url";

const Tuple = std.meta.Tuple;

pub const Config = struct {
    const Self = @This();

    id: []const u8,
    cache: cache.Cache,
    settings: settings.ConfigSettings,

    pub fn init(config_id: []const u8) !Config {
        const cfpath: []const u8, const config_exists: bool = try utils.getConfigDir(config_id);
        if (!config_exists) {
            return error.ConfigDoesNotExist;
        }
        const s_path = try std.fs.path.join(
            std.heap.page_allocator,
            &[_][]const u8{ cfpath, settings_f_name },
        );
        var s = try settings.ConfigSettings.init(s_path);
        try s.read();
        const c_path = try std.fs.path.joinZ(
            std.heap.page_allocator,
            &[_][]const u8{ cfpath, cache_f_name },
        );
        const c = try cache.Cache.init(
            c_path,
        );
        return Config{
            .cache = c,
            .settings = s,
            .id = config_id,
        };
    }

    pub fn fetch_article(self: Self) !?Tuple(&.{
        []const u8,
        []const u8,
    }) {
        const max_age = try self.settings.max_article_age();
        return try self.cache.fetch_article(max_age);
    }

    pub fn save_url_file(self: Self, url: []const u8) !void {
        const cfpath: []const u8, const config_exists: bool = try utils.getConfigDir(self.id);
        if (!config_exists) {
            return;
        }
        const s_path = try std.fs.path.join(
            std.heap.page_allocator,
            &[_][]const u8{ cfpath, last_url_f_name },
        );

        const f = try std.fs.createFileAbsolute(
            s_path,
            .{ .read = true },
        );
        try f.writeAll(url);
        return;
    }

    pub fn save_url_file_safe(self: Self, url: []const u8) void {
        self.save_url_file(url) catch return;
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
