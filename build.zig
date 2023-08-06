const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    const ssl = b.option(bool, "ssl", "Enable SSL support") orelse false;
    const uv = b.option(bool, "uv", "Enable libuv support") orelse false;

    const lib = b.addStaticLibrary(.{
        .name = "usockets",
        .target = target,
        .optimize = optimize,
    });

    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();

    lib.linkLibC();

    if (ssl) {
        const boringssl_dep = b.dependency("boringssl", .{
            .target = target,
            .optimize = optimize,
        });

        lib.linkLibCpp();
        lib.linkLibrary(boringssl_dep.artifact("ssl"));

        try flags.append("-DLIBUS_USE_OPENSSL");
    } else {
        try flags.append("-DLIBUS_NO_SSL");
    }

    if (uv) {
        const libuv_dep = b.dependency("libuv", .{
            .target = target,
            .optimize = optimize,
        });
        
        lib.linkLibrary(libuv_dep.artifact("uv"));

        try flags.append("-DLIBUS_USE_LIBUV");
    }

    lib.addIncludePath(.{ .cwd_relative = "vendor/src" });
    lib.installHeader("vendor/src/libusockets.h", "libusockets.h");
    lib.installHeader("vendor/src/quic.h", "quic.h");
    lib.addCSourceFiles(&.{
        "vendor/src/bsd.c",
        "vendor/src/context.c",
        "vendor/src/crypto/openssl.c",
        "vendor/src/crypto/sni_tree.cpp",
        "vendor/src/eventing/epoll_kqueue.c",
        "vendor/src/eventing/gcd.c",
        "vendor/src/eventing/libuv.c",
        "vendor/src/io_uring/io_context.c",
        "vendor/src/io_uring/io_loop.c",
        "vendor/src/io_uring/io_socket.c",
        "vendor/src/loop.c",
        "vendor/src/quic.c",
        "vendor/src/socket.c",
        "vendor/src/udp.c",
    }, flags.items);

    b.installArtifact(lib);

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    tests.linkLibC();
    tests.linkLibrary(lib);

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
