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

            .futexWait = futexWait,
            .futexWaitUncancelable = futexWaitUncancelable,
            .futexWake = futexWake,

            .dirCreateDir = dirCreateDir,
            .dirCreateDirPath = dirCreateDirPath,
            .dirCreateDirPathOpen = dirCreateDirPathOpen,
            .dirStat = dirStat,
            .dirStatFile = dirStatFile,
            .dirAccess = dirAccess,
            .dirCreateFile = dirCreateFile,
            .dirCreateFileAtomic = dirCreateFileAtomic,
            .dirOpenFile = dirOpenFile,
            .dirOpenDir = dirOpenDir,
            .dirClose = dirClose,
            .dirRead = dirRead,
            .dirRealPath = dirRealPath,
            .dirRealPathFile = dirRealPathFile,
            .dirDeleteFile = dirDeleteFile,
            .dirDeleteDir = dirDeleteDir,
            .dirRename = dirRename,
            .dirRenamePreserve = dirRenamePreserve,
            .dirSymLink = dirSymLink,
            .dirReadLink = dirReadLink,
            .dirSetOwner = dirSetOwner,
            .dirSetFileOwner = dirSetFileOwner,
            .dirSetPermissions = dirSetPermissions,
            .dirSetFilePermissions = dirSetFilePermissions,
            .dirSetTimestamps = dirSetTimestamps,
            .dirHardLink = dirHardLink,

            .fileStat = fileStat,
            .fileLength = fileLength,
            .fileClose = fileClose,
            .fileWriteStreaming = fileWriteStreaming,
            .fileWritePositional = fileWritePositional,
            .fileWriteFileStreaming = fileWriteFileStreaming,
            .fileWriteFilePositional = fileWriteFilePositional,
            .fileReadStreaming = fileReadStreaming,
            .fileReadPositional = fileReadPositional,
            .fileSeekBy = fileSeekBy,
            .fileSeekTo = fileSeekTo,
            .fileSync = fileSync,
            .fileIsTty = fileIsTty,
            .fileEnableAnsiEscapeCodes = fileEnableAnsiEscapeCodes,
            .fileSupportsAnsiEscapeCodes = fileSupportsAnsiEscapeCodes,
            .fileSetLength = fileSetLength,
            .fileSetOwner = fileSetOwner,
            .fileSetPermissions = fileSetPermissions,
            .fileSetTimestamps = fileSetTimestamps,
            .fileLock = fileLock,
            .fileTryLock = fileTryLock,
            .fileUnlock = fileUnlock,
            .fileDowngradeLock = fileDowngradeLock,
            .fileRealPath = fileRealPath,
            .fileHardLink = fileHardLink,

            .processExecutableOpen = processExecutableOpen,
            .processExecutablePath = processExecutablePath,
            .lockStderr = lockStderr,
            .tryLockStderr = tryLockStderr,
            .unlockStderr = unlockStderr,
            .processSetCurrentDir = processSetCurrentDir,
            .processReplace = processReplace,
            .processReplacePath = processReplacePath,
            .processSpawn = processSpawn,
            .processSpawnPath = processSpawnPath,
            .childWait = childWait,
            .childKill = childKill,

            .progressParentFile = progressParentFile,

            .now = now,
            .sleep = sleep,

            .random = random,
            .randomSecure = randomSecure,

            .netListenIp = netListenIp,
            .netListenUnix = netListenUnix,
            .netAccept = netAccept,
            .netBindIp = netBindIp,
            .netConnectIp = netConnectIp,
            .netConnectUnix = netConnectUnix,
            .netClose = netClose,
            .netShutdown = netShutdown,
            .netRead = netRead,
            .netWrite = netWrite,
            .netWriteFile = netWriteFile,
            .netSend = netSend,
            .netReceive = netReceive,
            .netInterfaceNameResolve = netInterfaceNameResolve,
            .netInterfaceName = netInterfaceName,
            .netLookup = netLookup,
        },
    };
}

fn async(
    _: ?*anyopaque,
    _: []u8,
    _: std.mem.Alignment,
    _: []const u8,
    _: std.mem.Alignment,
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
    _: []u8,
    _: std.mem.Alignment,
) void {}

fn cancel(
    _: ?*anyopaque,
    _: *std.Io.AnyFuture,
    _: []u8,
    _: std.mem.Alignment,
) void {}

fn groupAsync(
    _: ?*anyopaque,
    _: *std.Io.Group,
    _: []const u8,
    _: std.mem.Alignment,
    _: *const fn (context: *const anyopaque) std.Io.Cancelable!void,
) void {}

fn groupConcurrent(
    _: ?*anyopaque,
    _: *std.Io.Group,
    _: []const u8,
    _: std.mem.Alignment,
    _: *const fn (context: *const anyopaque) std.Io.Cancelable!void,
) std.Io.ConcurrentError!void {}

fn groupAwait(
    _: ?*anyopaque,
    _: *std.Io.Group,
    _: *anyopaque,
) std.Io.Cancelable!void {}

fn groupCancel(
    _: ?*anyopaque,
    _: *std.Io.Group,
    _: *anyopaque,
) void {}

fn recancel(_: ?*anyopaque) void {}
fn swapCancelProtection(
    _: ?*anyopaque,
    _: std.Io.CancelProtection,
) std.Io.CancelProtection {
    return .blocked;
}

fn checkCancel(_: ?*anyopaque) std.Io.Cancelable!void {}

/// Blocks until one of the futures from the list has a result ready, such
/// that awaiting it will not block. Returns that index.
fn select(
    _: ?*anyopaque,
    _: []const *std.Io.AnyFuture,
) std.Io.Cancelable!usize {
    return error.Canceled;
}

fn futexWait(
    _: ?*anyopaque,
    _: *const u32,
    _: u32,
    _: std.Io.Timeout,
) std.Io.Cancelable!void {}
fn futexWaitUncancelable(
    _: ?*anyopaque,
    _: *const u32,
    _: u32,
) void {}
fn futexWake(
    _: ?*anyopaque,
    _: *const u32,
    _: u32,
) void {}

fn dirCreateDir(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.Dir.Permissions,
) std.Io.Dir.CreateDirError!void {}
fn dirCreateDirPath(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.Dir.Permissions,
) std.Io.Dir.CreateDirPathError!std.Io.Dir.CreatePathStatus {
    return error.AccessDenied;
}
fn dirCreateDirPathOpen(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.Dir.Permissions,
    _: std.Io.Dir.OpenOptions,
) std.Io.Dir.CreateDirPathOpenError!std.Io.Dir {
    return error.AccessDenied;
}
fn dirOpenDir(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.Dir.OpenOptions,
) std.Io.Dir.OpenError!std.Io.Dir {
    return error.AccessDenied;
}
fn dirStat(
    _: ?*anyopaque,
    _: std.Io.Dir,
) std.Io.Dir.StatError!std.Io.Dir.Stat {
    return error.AccessDenied;
}
fn dirStatFile(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.Dir.StatFileOptions,
) std.Io.Dir.StatFileError!std.Io.File.Stat {
    return error.AccessDenied;
}
fn dirAccess(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.Dir.AccessOptions,
) std.Io.Dir.AccessError!void {
    return error.AccessDenied;
}
fn dirCreateFile(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.File.CreateFlags,
) std.Io.File.OpenError!std.Io.File {
    return error.AccessDenied;
}
fn dirCreateFileAtomic(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.Dir.CreateFileAtomicOptions,
) std.Io.Dir.CreateFileAtomicError!std.Io.File.Atomic {
    return error.AccessDenied;
}
fn dirOpenFile(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.File.OpenFlags,
) std.Io.File.OpenError!std.Io.File {
    return error.AccessDenied;
}
fn dirClose(
    _: ?*anyopaque,
    _: []const std.Io.Dir,
) void {}
fn dirRead(
    _: ?*anyopaque,
    _: *std.Io.Dir.Reader,
    _: []std.Io.Dir.Entry,
) std.Io.Dir.Reader.Error!usize {
    return error.AccessDenied;
}
fn dirRealPath(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []u8,
) std.Io.Dir.RealPathError!usize {
    return error.AccessDenied;
}
fn dirRealPathFile(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: []u8,
) std.Io.Dir.RealPathFileError!usize {
    return error.AccessDenied;
}
fn dirDeleteFile(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
) std.Io.Dir.DeleteFileError!void {
    return error.AccessDenied;
}
fn dirDeleteDir(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
) std.Io.Dir.DeleteDirError!void {
    return error.AccessDenied;
}
fn dirRename(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.Dir,
    _: []const u8,
) std.Io.Dir.RenameError!void {
    return error.AccessDenied;
}
fn dirRenamePreserve(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.Dir,
    _: []const u8,
) std.Io.Dir.RenamePreserveError!void {
    return error.AccessDenied;
}
fn dirSymLink(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: []const u8,
    _: std.Io.Dir.SymLinkFlags,
) std.Io.Dir.SymLinkError!void {
    return error.AccessDenied;
}
fn dirReadLink(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: []u8,
) std.Io.Dir.ReadLinkError!usize {
    return error.AccessDenied;
}
fn dirSetOwner(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: ?std.Io.File.Uid,
    _: ?std.Io.File.Gid,
) std.Io.Dir.SetOwnerError!void {
    return error.AccessDenied;
}
fn dirSetFileOwner(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: ?std.Io.File.Uid,
    _: ?std.Io.File.Gid,
    _: std.Io.Dir.SetFileOwnerOptions,
) std.Io.Dir.SetFileOwnerError!void {
    return error.AccessDenied;
}
fn dirSetPermissions(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: std.Io.Dir.Permissions,
) std.Io.Dir.SetPermissionsError!void {
    return error.AccessDenied;
}
fn dirSetFilePermissions(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.File.Permissions,
    _: std.Io.Dir.SetFilePermissionsOptions,
) std.Io.Dir.SetFilePermissionsError!void {
    return error.AccessDenied;
}
fn dirSetTimestamps(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.Dir.SetTimestampsOptions,
) std.Io.Dir.SetTimestampsError!void {
    return error.AccessDenied;
}
fn dirHardLink(
    _: ?*anyopaque,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.Dir.HardLinkOptions,
) std.Io.Dir.HardLinkError!void {
    return error.AccessDenied;
}

fn fileStat(_: ?*anyopaque, _: std.Io.File) std.Io.File.StatError!std.Io.File.Stat {
    return error.Unexpected;
}
fn fileLength(_: ?*anyopaque, _: std.Io.File) std.Io.File.LengthError!u64 {
    return error.Unexpected;
}
fn fileClose(_: ?*anyopaque, _: []const std.Io.File) void {}
fn fileWriteStreaming(
    _: ?*anyopaque,
    _: std.Io.File,
    _: []const u8,
    _: []const []const u8,
    _: usize,
) std.Io.File.Writer.Error!usize {
    return error.Unexpected;
}
fn fileWritePositional(
    _: ?*anyopaque,
    _: std.Io.File,
    _: []const u8,
    _: []const []const u8,
    _: usize,
    _: u64,
) std.Io.File.WritePositionalError!usize {
    return error.Unexpected;
}
fn fileWriteFileStreaming(
    _: ?*anyopaque,
    _: std.Io.File,
    _: []const u8,
    _: *std.Io.File.Reader,
    _: std.Io.Limit,
) std.Io.File.Writer.WriteFileError!usize {
    return error.Unexpected;
}
fn fileWriteFilePositional(
    _: ?*anyopaque,
    _: std.Io.File,
    _: []const u8,
    _: *std.Io.File.Reader,
    _: std.Io.Limit,
    _: u64,
) std.Io.File.WriteFilePositionalError!usize {
    return error.Unexpected;
}
fn fileReadStreaming(
    _: ?*anyopaque,
    _: std.Io.File,
    _: []const []u8,
) std.Io.File.Reader.Error!usize {
    return error.Unexpected;
}
fn fileReadPositional(
    _: ?*anyopaque,
    _: std.Io.File,
    _: []const []u8,
    _: u64,
) std.Io.File.ReadPositionalError!usize {
    return error.Unexpected;
}
fn fileSeekBy(
    _: ?*anyopaque,
    _: std.Io.File,
    _: i64,
) std.Io.File.SeekError!void {
    return error.Unexpected;
}
fn fileSeekTo(
    _: ?*anyopaque,
    _: std.Io.File,
    _: u64,
) std.Io.File.SeekError!void {
    return error.Unexpected;
}
fn fileSync(_: ?*anyopaque, _: std.Io.File) std.Io.File.SyncError!void {
    return error.Unexpected;
}
fn fileIsTty(_: ?*anyopaque, _: std.Io.File) std.Io.Cancelable!bool {
    return error.Canceled;
}
fn fileEnableAnsiEscapeCodes(
    _: ?*anyopaque,
    _: std.Io.File,
) std.Io.File.EnableAnsiEscapeCodesError!void {
    return error.Canceled;
}
fn fileSupportsAnsiEscapeCodes(
    _: ?*anyopaque,
    _: std.Io.File,
) std.Io.Cancelable!bool {
    return error.Canceled;
}
fn fileSetLength(
    _: ?*anyopaque,
    _: std.Io.File,
    _: u64,
) std.Io.File.SetLengthError!void {
    return error.Unexpected;
}
fn fileSetOwner(
    _: ?*anyopaque,
    _: std.Io.File,
    _: ?std.Io.File.Uid,
    _: ?std.Io.File.Gid,
) std.Io.File.SetOwnerError!void {
    return error.Unexpected;
}
fn fileSetPermissions(
    _: ?*anyopaque,
    _: std.Io.File,
    _: std.Io.File.Permissions,
) std.Io.File.SetPermissionsError!void {
    return error.Unexpected;
}
fn fileSetTimestamps(
    _: ?*anyopaque,
    _: std.Io.File,
    _: std.Io.File.SetTimestampsOptions,
) std.Io.File.SetTimestampsError!void {
    return error.Unexpected;
}
fn fileLock(
    _: ?*anyopaque,
    _: std.Io.File,
    _: std.Io.File.Lock,
) std.Io.File.LockError!void {
    return error.Unexpected;
}
fn fileTryLock(
    _: ?*anyopaque,
    _: std.Io.File,
    _: std.Io.File.Lock,
) std.Io.File.LockError!bool {
    return error.Unexpected;
}
fn fileUnlock(_: ?*anyopaque, _: std.Io.File) void {}
fn fileDowngradeLock(
    _: ?*anyopaque,
    _: std.Io.File,
) std.Io.File.DowngradeLockError!void {
    return error.Unexpected;
}
fn fileRealPath(
    _: ?*anyopaque,
    _: std.Io.File,
    _: []u8,
) std.Io.File.RealPathError!usize {
    return error.Unexpected;
}
fn fileHardLink(
    _: ?*anyopaque,
    _: std.Io.File,
    _: std.Io.Dir,
    _: []const u8,
    _: std.Io.File.HardLinkOptions,
) std.Io.File.HardLinkError!void {
    return error.Unexpected;
}

fn processExecutableOpen(_: ?*anyopaque, _: std.Io.File.OpenFlags) std.process.OpenExecutableError!std.Io.File {
    return error.Unexpected;
}
fn processExecutablePath(_: ?*anyopaque, _: []u8) std.process.ExecutablePathError!usize {
    return error.Unexpected;
}
fn lockStderr(_: ?*anyopaque, _: ?std.Io.Terminal.Mode) std.Io.Cancelable!std.Io.LockedStderr {
    return error.Canceled;
}
fn tryLockStderr(_: ?*anyopaque, _: ?std.Io.Terminal.Mode) std.Io.Cancelable!?std.Io.LockedStderr {
    return error.Canceled;
}
fn unlockStderr(_: ?*anyopaque) void {}
fn processSetCurrentDir(_: ?*anyopaque, _: std.Io.Dir) std.process.SetCurrentDirError!void {
    return error.Unexpected;
}
fn processReplace(_: ?*anyopaque, _: std.process.ReplaceOptions) std.process.ReplaceError {
    return error.Unexpected;
}
fn processReplacePath(_: ?*anyopaque, _: std.Io.Dir, _: std.process.ReplaceOptions) std.process.ReplaceError {
    return error.Unexpected;
}
fn processSpawn(_: ?*anyopaque, _: std.process.SpawnOptions) std.process.SpawnError!std.process.Child {
    return error.Unexpected;
}
fn processSpawnPath(_: ?*anyopaque, _: std.Io.Dir, _: std.process.SpawnOptions) std.process.SpawnError!std.process.Child {
    return error.Unexpected;
}
fn childWait(_: ?*anyopaque, _: *std.process.Child) std.process.Child.WaitError!std.process.Child.Term {
    return error.Unexpected;
}
fn childKill(_: ?*anyopaque, _: *std.process.Child) void {}

fn progressParentFile(_: ?*anyopaque) std.Progress.ParentFileError!std.Io.File {
    return error.UnsupportedOperation;
}

fn now(_: ?*anyopaque, _: std.Io.Clock) std.Io.Clock.Error!std.Io.Timestamp {
    return error.Unexpected;
}
fn sleep(_: ?*anyopaque, _: std.Io.Timeout) std.Io.Cancelable!void {
    return error.Canceled;
}

fn random(_: ?*anyopaque, _: []u8) void {}
fn randomSecure(_: ?*anyopaque, _: []u8) std.Io.Cancelable!void {
    return error.Canceled;
}

fn netListenIp(
    _: ?*anyopaque,
    _: std.Io.net.IpAddress,
    _: std.Io.net.IpAddress.ListenOptions,
) std.Io.net.IpAddress.ListenError!std.Io.net.Server {
    return error.Unexpected;
}
fn netAccept(
    _: ?*anyopaque,
    _: std.Io.net.Socket.Handle,
) std.Io.net.Server.AcceptError!std.Io.net.Stream {
    return error.Unexpected;
}
fn netBindIp(
    _: ?*anyopaque,
    _: *const std.Io.net.IpAddress,
    _: std.Io.net.IpAddress.BindOptions,
) std.Io.net.IpAddress.BindError!std.Io.net.Socket {
    return error.Unexpected;
}
fn netConnectIp(
    _: ?*anyopaque,
    _: *const std.Io.net.IpAddress,
    _: std.Io.net.IpAddress.ConnectOptions,
) std.Io.net.IpAddress.ConnectError!std.Io.net.Stream {
    return error.Unexpected;
}
fn netListenUnix(
    _: ?*anyopaque,
    _: *const std.Io.net.UnixAddress,
    _: std.Io.net.UnixAddress.ListenOptions,
) std.Io.net.UnixAddress.ListenError!std.Io.net.Socket.Handle {
    return error.Unexpected;
}
fn netConnectUnix(
    _: ?*anyopaque,
    _: *const std.Io.net.UnixAddress,
) std.Io.net.UnixAddress.ConnectError!std.Io.net.Socket.Handle {
    return error.Unexpected;
}
fn netSend(
    _: ?*anyopaque,
    _: std.Io.net.Socket.Handle,
    _: []std.Io.net.OutgoingMessage,
    _: std.Io.net.SendFlags,
) struct { ?std.Io.net.Socket.SendError, usize } {
    return .{ error.Unexpected, 0 };
}
fn netReceive(
    _: ?*anyopaque,
    _: std.Io.net.Socket.Handle,
    _: []std.Io.net.IncomingMessage,
    _: []u8,
    _: std.Io.net.ReceiveFlags,
    _: std.Io.Timeout,
) struct { ?std.Io.net.Socket.ReceiveTimeoutError, usize } {
    return .{ error.Unexpected, 0 };
}
fn netRead(
    _: ?*anyopaque,
    _: std.Io.net.Socket.Handle,
    _: [][]u8,
) std.Io.net.Stream.Reader.Error!usize {
    return 0;
}
fn netWrite(
    _: ?*anyopaque,
    _: std.Io.net.Socket.Handle,
    _: []const u8,
    _: []const []const u8,
    _: usize,
) std.Io.net.Stream.Writer.Error!usize {
    return 0;
}
fn netWriteFile(
    _: ?*anyopaque,
    _: std.Io.net.Socket.Handle,
    _: []const u8,
    _: *std.Io.File.Reader,
    _: std.Io.Limit,
) std.Io.net.Stream.Writer.WriteFileError!usize {
    return 0;
}
fn netClose(_: ?*anyopaque, _: []const std.Io.net.Socket.Handle) void {}
fn netShutdown(
    _: ?*anyopaque,
    _: std.Io.net.Socket.Handle,
    _: std.Io.net.ShutdownHow,
) std.Io.net.ShutdownError!void {
    return error.Unexpected;
}
fn netInterfaceNameResolve(
    _: ?*anyopaque,
    _: *const std.Io.net.Interface.Name,
) std.Io.net.Interface.Name.ResolveError!std.Io.net.Interface {
    return error.Unexpected;
}
fn netInterfaceName(
    _: ?*anyopaque,
    _: std.Io.net.Interface,
) std.Io.net.Interface.NameError!std.Io.net.Interface.Name {
    return error.Unexpected;
}
fn netLookup(
    _: ?*anyopaque,
    _: std.Io.net.HostName,
    _: *std.Io.Queue(std.Io.net.HostName.LookupResult),
    _: std.Io.net.HostName.LookupOptions,
) std.Io.net.HostName.LookupError!void {
    return error.Unexpected;
}
