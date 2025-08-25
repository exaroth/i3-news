const std = @import("std");
const known_folders = @import("known-folders");

const i3_config_dirname: []const u8 = "i3_news";
const Tuple = std.meta.Tuple;

pub const known_folders_config = .{
    .xdg_on_mac = false,
};

/// Generate random string with given length.
pub inline fn genRandomString(comptime len: u8) [len]u8 {
    const rand = std.crypto.random;
    var result: [len]u8 = undefined;
    for (result, 0..) |_, index| {
        result[index] = rand.intRangeAtMost(u8, 97, 122);
    }
    return result;
}

/// Open file using default editor.
pub fn openEditor(fpath: []const u8) !void {
    var v_process = std.process.Child.init(
        &[_][]const u8{ "vim", "-o", fpath, "+3" },
        std.heap.page_allocator,
    );
    try v_process.spawn();
    _ = try v_process.wait();
}

/// Retrieve directory used for storing i3news configs.
pub fn getI3NewsDir() !std.fs.Dir {
    var config_dir = try known_folders.open(
        std.heap.page_allocator,
        known_folders.KnownFolder.local_configuration,
        std.fs.Dir.OpenOptions{ .access_sub_paths = true },
    ) orelse unreachable;
    defer config_dir.close();
    const dir = try config_dir.makeOpenPath(i3_config_dirname, .{});
    return dir;
}

/// Result of config retrieval containing
/// both the path and boolean indicating whether
/// config exists or not.
const configDirResult = Tuple(&.{
    []const u8,
    bool,
});

/// Retrieve directory containing particular config.
pub fn getConfigDir(config_name: []const u8) !configDirResult {
    var i3Dir = try getI3NewsDir();
    defer i3Dir.close();
    const i3NewsPath = try i3Dir.realpathAlloc(
        std.heap.page_allocator,
        ".",
    );
    const rel_path = try std.fmt.allocPrint(
        std.heap.page_allocator,
        "{s}/",
        .{config_name},
    );
    const paths = [_][]const u8{ i3NewsPath, rel_path };
    const full_path = try std.fs.path.join(
        std.heap.page_allocator,
        &paths,
    );

    _ = std.fs.openDirAbsolute(full_path, .{}) catch {
        return .{ full_path, false };
    };
    return .{ full_path, true };
}

/// Recursively copy contents of one directory to another.
pub fn copyDirContents(src: []const u8, dest: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("leak");
    const allocator = gpa.allocator();

    // In order to walk the directry, `iterate` must be set to true.
    var dir = try std.fs.openDirAbsolute(src, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        const src_path = try std.fs.path.resolve(
            std.heap.page_allocator,
            &[_][]const u8{ src, entry.basename },
        );
        const dest_path = try std.fs.path.resolve(
            std.heap.page_allocator,
            &[_][]const u8{ dest, entry.basename },
        );
        try std.fs.copyFileAbsolute(src_path, dest_path, .{});
    }
}

/// Cleanup temp dir.
pub fn cleanupTemp(tmp_id: []const u8) void {
    var tmp_dir = std.fs.openDirAbsolute("/tmp", .{}) catch {
        return;
    };
    defer tmp_dir.close();
    tmp_dir.deleteTree(tmp_id) catch return;
    return;
}
