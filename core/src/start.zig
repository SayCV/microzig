const std = @import("std");
const builtin = @import("builtin");
const microzig = @import("microzig");
const app = @import("app");

// Use microzig panic handler if not defined by an application
pub const panic = if (!@hasDecl(app, "panic")) microzig.panic else app.panic;

// Conditionally provide a default no-op logFn if app does not have one
// defined. Parts of microzig use the stdlib logging facility and
// compilations will now fail on freestanding systems that use it but do
// not explicitly set `root.std_options.logFn`
pub const std_options: std.Options = .{
    .log_level = microzig.options.log_level,
    .log_scope_levels = microzig.options.log_scope_levels,
    .logFn = microzig.options.logFn,
};

pub const std_options_debug_io: std.Io = nop();

// Startup logic:
comptime {
    // Instantiate the startup logic for the given CPU type.
    // This usually implements the `_start` symbol that will populate
    // the sections .data and .bss with the correct data.
    // .rodata is not always necessary to be populated (flash based systems
    // can just index flash, while harvard or flash-less architectures need
    // to copy .rodata into RAM).
    microzig.cpu.export_startup_logic();
}

/// This is the logical entry point for microzig.
/// It will invoke the main function from the root source file
/// and provides error return handling as well as a event loop if requested.
///
/// Why is this function exported?
/// This is due to the modular design of microzig to allow the "chip" dependency of microzig
/// to call into our main function here. If we would use a normal function call, we'd have a
/// circular dependency between the `microzig` and `chip` package. This function is also likely
/// to be invoked from assembly, so it's also convenient in that regard.
export fn microzig_main() noreturn {
    if (!@hasDecl(app, "main"))
        @compileError("The root source file must provide a public function main!");

    const main = @field(app, "main");
    const info: std.builtin.Type = @typeInfo(@TypeOf(main));

    const invalid_main_msg = "main must be either 'pub fn main() void' or 'pub fn main() !void'.";
    if (info != .@"fn" or info.@"fn".params.len > 0)
        @compileError(invalid_main_msg);

    const return_type = info.@"fn".return_type orelse @compileError(invalid_main_msg);

    // A hal can export a default init function that runs before main for
    // procedures like clock configuration. The user may override and customize
    // this functionality by providing their own init function.
    // function.
    if (@hasDecl(app, "init"))
        app.init()
    else if (microzig.hal != void and @hasDecl(microzig.hal, "init"))
        microzig.hal.init();

    if (@typeInfo(return_type) == .error_union) {
        main() catch |err| {
            // Although here we could use @errorReturnTrace similar to
            // `std.start` and just dump the trace (without panic), the user
            // might not use logging and have the panic handler just blink an
            // led.

            const msg_base = "main() returned error.";

            if (!microzig.options.simple_panic_if_main_errors) {
                const max_error_size = comptime blk: {
                    var max_error_size: usize = 0;
                    const err_type = @typeInfo(return_type).error_union.error_set;
                    if (@typeInfo(err_type).error_set) |err_set| {
                        for (err_set) |current_err| {
                            max_error_size = @max(max_error_size, current_err.name.len);
                        }
                    }
                    break :blk max_error_size;
                };

                var buf: [msg_base.len + max_error_size]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, "{s}{s}", .{ msg_base, @errorName(err) }) catch @panic(msg_base);
                @panic(msg);
            } else {
                @panic(msg_base);
            }
        };
    } else {
        main();
    }

    // Main returned, just hang around here a bit.
    microzig.hang();
}

fn nop() std.Io {
    return .{
        .userdata = null,
        .vtable = &.{
            .async = async,
            .concurrent = concurrent,
            .await = await,
            .cancel = cancel,
            .select = select,

            .groupAsync = groupAsync,
            .groupConcurrent = groupConcurrent,
            .groupAwait = groupAwait,
            .groupCancel = groupCancel,

            .recancel = recancel,
            .swapCancelProtection = swapCancelProtection,
            .checkCancel = checkCancel,

            .futexWait = @panic("futexWait unavailable"),
            .futexWaitUncancelable = @panic("futexWaitUncancelable unavailable"),
            .futexWake = @panic("futexWake unavailable"),

            .dirCreateDir = @panic("dirCreateDir unavailable"),
            .dirCreateDirPath = @panic("dirCreateDirPath unavailable"),
            .dirCreateDirPathOpen = @panic("dirCreateDirPathOpen unavailable"),
            .dirStat = @panic("dirStat unavailable"),
            .dirStatFile = @panic("dirStatFile unavailable"),
            .dirAccess = @panic("dirAccess unavailable"),
            .dirCreateFile = @panic("dirCreateFile unavailable"),
            .dirCreateFileAtomic = @panic("dirCreateFileAtomic unavailable"),
            .dirOpenFile = @panic("dirOpenFile unavailable"),
            .dirOpenDir = @panic("dirOpenDir unavailable"),
            .dirClose = @panic("dirClose unavailable"),
            .dirRead = @panic("dirRead unavailable"),
            .dirRealPath = @panic("dirRealPath unavailable"),
            .dirRealPathFile = @panic("dirRealPathFile unavailable"),
            .dirDeleteFile = @panic("dirDeleteFile unavailable"),
            .dirDeleteDir = @panic("dirDeleteDir unavailable"),
            .dirRename = @panic("dirRename unavailable"),
            .dirRenamePreserve = @panic("dirRenamePreserve unavailable"),
            .dirSymLink = @panic("dirSymLink unavailable"),
            .dirReadLink = @panic("dirReadLink unavailable"),
            .dirSetOwner = @panic("dirSetOwner unavailable"),
            .dirSetFileOwner = @panic("dirSetFileOwner unavailable"),
            .dirSetPermissions = @panic("dirSetPermissions unavailable"),
            .dirSetFilePermissions = @panic("dirSetFilePermissions unavailable"),
            .dirSetTimestamps = @panic("dirSetTimestamps unavailable"),
            .dirHardLink = @panic("dirHardLink unavailable"),

            .fileStat = @panic("fileStat unavailable"),
            .fileLength = @panic("fileLength unavailable"),
            .fileClose = @panic("fileClose unavailable"),
            .fileWriteStreaming = @panic("fileWriteStreaming unavailable"),
            .fileWritePositional = @panic("fileWritePositional unavailable"),
            .fileWriteFileStreaming = @panic("fileWriteFileStreaming unavailable"),
            .fileWriteFilePositional = @panic("fileWriteFilePositional unavailable"),
            .fileReadStreaming = @panic("fileReadStreaming unavailable"),
            .fileReadPositional = @panic("fileReadPositional unavailable"),
            .fileSeekBy = @panic("fileSeekBy unavailable"),
            .fileSeekTo = @panic("fileSeekTo unavailable"),
            .fileSync = @panic("fileSync unavailable"),
            .fileIsTty = @panic("fileIsTty unavailable"),
            .fileEnableAnsiEscapeCodes = @panic("fileEnableAnsiEscapeCodes unavailable"),
            .fileSupportsAnsiEscapeCodes = @panic("fileSupportsAnsiEscapeCodes unavailable"),
            .fileSetLength = @panic("fileSetLength unavailable"),
            .fileSetOwner = @panic("fileSetOwner unavailable"),
            .fileSetPermissions = @panic("fileSetPermissions unavailable"),
            .fileSetTimestamps = @panic("fileSetTimestamps unavailable"),
            .fileLock = @panic("fileLock unavailable"),
            .fileTryLock = @panic("fileTryLock unavailable"),
            .fileUnlock = @panic("fileUnlock unavailable"),
            .fileDowngradeLock = @panic("fileDowngradeLock unavailable"),
            .fileRealPath = @panic("fileRealPath unavailable"),
            .fileHardLink = @panic("fileHardLink unavailable"),

            .processExecutableOpen = @panic("processExecutableOpen unavailable"),
            .processExecutablePath = @panic("processExecutablePath unavailable"),
            .lockStderr = @panic("lockStderr unavailable"),
            .tryLockStderr = @panic("tryLockStderr unavailable"),
            .unlockStderr = @panic("unlockStderr unavailable"),
            .processSetCurrentDir = @panic("processSetCurrentDir unavailable"),
            .processReplace = @panic("processReplace unavailable"),
            .processReplacePath = @panic("processReplacePath unavailable"),
            .processSpawn = @panic("processSpawn unavailable"),
            .processSpawnPath = @panic("processSpawnPath unavailable"),
            .childWait = @panic("childWait unavailable"),
            .childKill = @panic("childKill unavailable"),

            .progressParentFile = @panic("progressParentFile unavailable"),

            .now = @panic("now unavailable"),
            .sleep = @panic("sleep unavailable"),

            .random = @panic("random unavailable"),
            .randomSecure = @panic("randomSecure unavailable"),

            .netListenIp = @panic("netListenIp unavailable"),
            .netListenUnix = @panic("netListenUnix unavailable"),
            .netAccept = @panic("netAccept unavailable"),
            .netBindIp = @panic("netBindIp unavailable"),
            .netConnectIp = @panic("netConnectIp unavailable"),
            .netConnectUnix = @panic("netConnectUnix unavailable"),
            .netClose = @panic("netClose unavailable"),
            .netShutdown = @panic("netShutdown unavailable"),
            .netRead = @panic("netRead unavailable"),
            .netWrite = @panic("netWrite unavailable"),
            .netWriteFile = @panic("netWriteFile unavailable"),
            .netSend = @panic("netSend unavailable"),
            .netReceive = @panic("netReceive unavailable"),
            .netInterfaceNameResolve = @panic("netInterfaceNameResolve unavailable"),
            .netInterfaceName = @panic("netInterfaceName unavailable"),
            .netLookup = @panic("netLookup unavailable"),
        },
    };
}

fn async(
    _: ?*anyopaque,
    _: []u8,
    _: std.Alignment,
    _: []const u8,
    _: std.Alignment,
    _: *const fn (context: *const anyopaque, result: *anyopaque) void,
) ?*std.Io.AnyFuture {
    return null;
}

fn concurrent(
    _: ?*anyopaque,
    _: usize,
    _: std.mem.Alignment,
    _: []const u8,
    _: std.mem.Alignment,
    _: *const fn (context: *const anyopaque, result: *anyopaque) void,
) std.Io.ConcurrentError!*std.Io.AnyFuture {
    return error.ConcurrencyUnavailable;
}

fn await(
    _: ?*anyopaque,
    _: *std.Io.AnyFuture,
    _: *anyopaque,
) void {
    @panic("await unavailable");
}

fn cancel(
    _: ?*anyopaque,
    _: *std.Io.AnyFuture,
) void {
    @panic("cancel unavailable");
}

fn select(
    _: ?*anyopaque,
    _: []*std.Io.AnyFuture,
    _: *anyopaque,
) void {
    @panic("select unavailable");
}

fn groupAsync(
    _: ?*anyopaque,
    _: []*std.Io.AnyFuture,
    _: *anyopaque,
) void {
    @panic("groupAsync unavailable");
}
fn groupConcurrent(
    _: ?*anyopaque,
    _: []*std.Io.AnyFuture,
    _: *anyopaque,
) void {
    @panic("groupConcurrent unavailable");
}
fn groupSelect(
    _: ?*anyopaque,
    _: []*std.Io.AnyFuture,
    _: *anyopaque,
) void {
    @panic("groupSelect unavailable");
}
fn groupCancel(
    _: ?*anyopaque,
    _: []*std.Io.AnyFuture,
    _: *anyopaque,
) void {
    @panic("groupCancel unavailable");
}
fn groupAwait(
    _: ?*anyopaque,
    _: []*std.Io.AnyFuture,
    _: *anyopaque,
) void {
    @panic("groupAwait unavailable");
}
fn recancel(
    _: ?*anyopaque,
    _: []*std.Io.AnyFuture,
    _: *anyopaque,
) void {
    @panic("recancel unavailable");
}
fn swapCancelProtection(
    _: ?*anyopaque,
    _: []*std.Io.AnyFuture,
    _: *anyopaque,
) void {
    @panic("swapCancelProtection unavailable");
}
fn checkCancel(
    _: ?*anyopaque,
    _: *anyopaque,
) void {
    @panic("checkCancel unavailable");
}
