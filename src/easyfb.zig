const std = @import("std");
const builtin = @import("builtin");
const windows = @import("easyfb/windows.zig");

// TODO: tests check that all instances have necessary traits
pub const EasyFBInstance = if (builtin.os == .windows)
    windows.EasyFBInstanceWindows
else
    @compileError("Implement easyFB for platform");
