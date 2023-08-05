const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const boringssl_dep = b.dependency("boringssl", .{
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addStaticLibrary(.{
        .name = "usockets",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();
    lib.linkLibCpp();
    lib.linkLibrary(boringssl_dep.artifact("ssl"));
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
    }, &.{"-DLIBUS_USE_OPENSSL"});

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
