const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
//
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    // const lib_mod = b.createModule(.{
    //     // `root_source_file` is the Zig "entry point" of the module. If a module
    //     // only contains e.g. external object files, you can make this `null`.
    //     // In this case the main source file is merely a path, however, in more
    //     // complicated build scripts, this could be a generated file.
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });

    // We will also create a module for our other entry point, 'main.zig'.
    const exe_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // const sqlite_lib = b.addStaticLibrary(
    //     .{
    //         .name = "sqlite",
    //         .target = target,
    //         .optimize = .ReleaseSafe,
    //         .use_llvm = true,
    //     },
    // );

    // sqlite_lib.addCSourceFile(.{ .file = .{ .src_path = .{
    //     .owner = b,
    //     .sub_path = "vendor/p/N-V-__8AACpFpwCXJZXXDaM9adUZOSdCSCy5dik1zsuZkk4x/sqlite.c",
    // } } });

    // sqlite_lib.linkLibC();

    // exe_mod.addImport("i3_news_lib", lib_mod);
    // const lib = b.addLibrary(.{
    //     .linkage = .static,
    //     .name = "i3_news",
    //     .root_module = lib_mod,
    // });

    // b.installArtifact(lib);
    const exe = b.addExecutable(.{
        .name = "i3_news",
        .root_module = exe_mod,
        .use_llvm = true,
    });
    exe.linkLibC();
    // exe.linkLibrary(lib);
    // exe.linkLibrary(sqlite_lib);
    exe.addIncludePath(b.path("vendor/p/sqlite-3.48.0-F2R_a_uGDgCfOH5UEJYjuOCe-HixnLjToxOdEGAEM3xk/c"));

    const args_m = b.dependency("args", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("args", args_m.module("args"));
    const sqlite = b.dependency("sqlite", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("sqlite", sqlite.module("sqlite"));
    const known_folders = b.dependency("known_folders", .{}).module("known-folders");
    exe.root_module.addImport("known-folders", known_folders);

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    // const lib_unit_tests = b.addTest(.{
    //     .root_module = lib_mod,
    // });

    // const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
