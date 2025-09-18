const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Artemis WebKit Library
    const webkit_lib = b.addStaticLibrary(.{
        .name = "artemis-webkit",
        .root_source_file = b.path("src/webkit.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Dependencies
    const artemis_engine = b.dependency("artemis_engine", .{
        .target = target,
        .optimize = optimize,
    });
    webkit_lib.root_module.addImport("artemis-engine", artemis_engine.module("artemis-engine"));

    const artemis_gui = b.dependency("artemis_gui", .{
        .target = target,
        .optimize = optimize,
    });
    webkit_lib.root_module.addImport("artemis-gui", artemis_gui.module("artemis-gui"));

    // Add WASM target support
    if (target.result.cpu.arch == .wasm32) {
        webkit_lib.entry = .disabled;
        webkit_lib.rdynamic = true;
    }

    b.installArtifact(webkit_lib);

    // Create module for other projects to use
    const webkit_module = b.addModule("artemis-webkit", .{
        .root_source_file = b.path("src/webkit.zig"),
        .target = target,
        .optimize = optimize,
    });
    webkit_module.addImport("artemis-engine", artemis_engine.module("artemis-engine"));
    webkit_module.addImport("artemis-gui", artemis_gui.module("artemis-gui"));

    // Examples
    const example_step = b.step("examples", "Build all examples");
    
    const basic_example = b.addExecutable(.{
        .name = "basic-web-app",
        .root_source_file = b.path("examples/basic.zig"),
        .target = target,
        .optimize = optimize,
    });
    basic_example.root_module.addImport("artemis-webkit", webkit_module);
    basic_example.root_module.addImport("artemis-engine", artemis_engine.module("artemis-engine"));
    basic_example.root_module.addImport("artemis-gui", artemis_gui.module("artemis-gui"));
    
    const install_example = b.addInstallArtifact(basic_example, .{});
    example_step.dependOn(&install_example.step);

    // Tests
    const test_step = b.step("test", "Run unit tests");
    
    const webkit_tests = b.addTest(.{
        .name = "webkit-tests",
        .root_source_file = b.path("tests/webkit_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    webkit_tests.root_module.addImport("artemis-webkit", webkit_module);
    webkit_tests.root_module.addImport("artemis-engine", artemis_engine.module("artemis-engine"));
    webkit_tests.root_module.addImport("artemis-gui", artemis_gui.module("artemis-gui"));

    const run_tests = b.addRunArtifact(webkit_tests);
    test_step.dependOn(&run_tests.step);

    // WASM-specific build
    const wasm_step = b.step("wasm", "Build for WebAssembly");
    const wasm_target = std.Target.Query{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    };
    
    const wasm_lib = b.addStaticLibrary(.{
        .name = "artemis-webkit-wasm",
        .root_source_file = b.path("src/webkit.zig"),
        .target = b.resolveTargetQuery(wasm_target),
        .optimize = optimize,
    });
    wasm_lib.entry = .disabled;
    wasm_lib.rdynamic = true;
    
    const install_wasm = b.addInstallArtifact(wasm_lib, .{});
    wasm_step.dependOn(&install_wasm.step);

    // Documentation
    const docs_step = b.step("docs", "Generate documentation");
    const docs = webkit_lib.getEmittedDocs();
    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs,
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);
}