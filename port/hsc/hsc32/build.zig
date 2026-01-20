const std = @import("std");
const microzig = @import("microzig/build-internals");

const Self = @This();

chips: struct {
    hsc32f3: *const microzig.Target,
},

boards: struct {
    hsc32f3_dongle: *const microzig.Target,
},

pub fn init(dep: *std.Build.Dependency) Self {
    const b = dep.builder;

    const hal: microzig.HardwareAbstractionLayer = .{
        .root_source_file = b.path("src/hal.zig"),
    };

    const chip_hsc32f3: microzig.Target = .{
        .dep = dep,
        .preferred_binary_format = .elf,
        .zig_target = .{
            .cpu_arch = .thumb,
            .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m3 },
            .os_tag = .freestanding,
            .abi = .eabi,
        },
        .chip = .{
            .name = "hsc32f3",
            .url = "https://www.hsc32.com/",
            .register_definition = .{
                .zig = b.path("src/chips/hsc32f3.zig"),
            },
            .memory_regions = &.{
                .{ .tag = .flash, .offset = 0x00000000, .length = 128 * 1024, .access = .rx },
                .{ .tag = .ram, .offset = 0x20000000, .length = 16 * 1024, .access = .rwx },
            },
            .patch_files = &.{
                b.path("patches/nrf51.zon"),
            },
        },
        .hal = hal,
    };

    return .{
        .chips = .{
            .hsc32f3 = chip_hsc32f3.derive(.{}),
        },
        .boards = .{
            .hsc32f3_dongle = chip_hsc32f3.derive(.{
                .board = .{
                    .name = "HSC32F3 Dongle",
                    .url = "https://www.hsc32.com/",
                    .root_source_file = b.path("src/boards/hsc32f3-dongle.zig"),
                },
            }),
        },
    };
}

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/hal.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const unit_tests_run = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run platform agnostic unit tests");
    test_step.dependOn(&unit_tests_run.step);
}
