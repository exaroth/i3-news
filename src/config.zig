const std = @import("std");
const cache = @import("cache.zig");
const settings = @import("settings.zig");
const utils = @import("utils.zig");

pub const cache_f_name = "cache.db";

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
            &[_][]const u8{ cfpath, "config" },
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
        const max_age = try self.settings.maxArticlesAge();
        return try self.cache.fetch_article(max_age);
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
