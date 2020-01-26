// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");

// TODO: tests check that all instances have necessary traits
pub const EasyFBInstance = if (builtin.os == .windows)
    windows.EasyFBInstanceWindows
else
    @compileError("Implement easyFB for platform");
