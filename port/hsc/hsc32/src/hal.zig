const microzig = @import("microzig");

pub const clocks = @import("hal/clocks.zig");
pub const gpio = @import("hal/gpio.zig");
pub const i2c = @import("hal/i2c.zig");
pub const time = @import("hal/time.zig");
pub const uart = @import("hal/uart.zig");
pub const drivers = @import("hal/drivers.zig");
// TODO: adc, timers, pwm, rng, rtc alarms, interrupts, wdt, wifi, nfc, bt, zigbee

pub const default_interrupts: microzig.cpu.InterruptOptions = .{
    // Required for timekeeping longer than 512 seconds
    .RTC0 = .{ .c = time.rtc_interrupt },
};

pub fn init() void {
    time.init();
}

test "hal tests" {
    _ = clocks;
    _ = gpio;
    _ = i2c;
    _ = time;
    _ = uart;

    _ = drivers;
}
