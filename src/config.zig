const std = @import("std");

const ConfigSettings = struct {
    const Self = @This();

    raw: []const u8,
    contents: std.AutoHashMap,

    fn open(path: []const u8) !ConfigSettings {

    }

    fn read(self: ConfigSettings) !void {

    }

    fn getString(self: ConfigSettings) ![]const u8 {

    }

    fn getInt(self: ConfigSettings) !u32 {

    }
};
