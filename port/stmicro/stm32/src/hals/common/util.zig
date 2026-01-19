const std = @import("std");
const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;

pub fn match_name(heystack: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (std.mem.indexOf(u8, heystack, needle)) |_| {
            return true;
        }
    }
    return false;
}

pub fn create_peripheral_enum(comptime bases_name: []const []const u8) type {
    var field_names: [70][]const u8 = undefined;
    var field_values: [70]usize = undefined;
    var names_index = 0;
    const peripheral = @typeInfo(peripherals);
    @setEvalBranchQuota(10_000);
    switch (peripheral) {
        .@"struct" => |data| {
            for (data.decls) |decls| {
                const decl_name = decls.name;
                if (match_name(decl_name, bases_name)) {
                    field_names[names_index] = decls.name;
                    field_values[names_index] = names_index;
                    names_index += 1;
                }
            }
        },
        else => unreachable,
    }

    return @Enum(usize, .exhaustive, field_names[0..names_index], field_values[0..names_index]);
}

pub fn sub_peripheral_enum(comptime T: type, comptime keep_name: []const []const u8, match_type: ?[]const u8) type {
    const enum_info = @typeInfo(T);
    var names_index = 0;

    var field_names: [10][]const u8 = undefined;
    var field_values: [10]usize = undefined;

    @setEvalBranchQuota(10_000);
    switch (enum_info) {
        .@"enum" => |data| {
            for (data.fields) |field| {
                if (match_name(field.name, keep_name)) {
                    if (match_type) |match| {
                        const type_name = @typeName(@TypeOf(@field(peripherals, field.name)));
                        _ = std.mem.indexOf(u8, type_name, match) orelse continue;
                    }
                    field_names[names_index] = field.name;
                    field_values[names_index] = field.value;
                    names_index += 1;
                }
            }
        },
        else => unreachable,
    }

    return @Enum(usize, .exhaustive, field_names[0..names_index], field_values[0..names_index]);
}

pub fn load_timer_interrupt(handler: *const fn () callconv(.c) void) microzig.cpu.InterruptOptions {
    var int_op: microzig.cpu.InterruptOptions = .{};
    if (@hasField(microzig.cpu.InterruptOptions, "TIM2")) {
        int_op.TIM2 = .{ .c = handler };
    }
    if (@hasField(microzig.cpu.InterruptOptions, "TIM3")) {
        int_op.TIM3 = .{ .c = handler };
    }
    if (@hasField(microzig.cpu.InterruptOptions, "TIM4")) {
        int_op.TIM4 = .{ .c = handler };
    }
    if (@hasField(microzig.cpu.InterruptOptions, "TIM5")) {
        int_op.TIM5 = .{ .c = handler };
    }

    return int_op;
}
