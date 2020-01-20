const std = @import("std");

pub fn Vec(comptime T: type, comptime S: usize) type {
    comptime if (@typeInfo(T) != .Int and @typeInfo(T) != .Float) {
        @compileError("Vectors only work on non-bool scalars");
    };
    return struct {
        e: [S]T,
        pub fn initSlice(slice: []const T) @This() {
            var ret: @This() = undefined;
            for (ret.e) |*val, idx| {
                val.* = slice[idx];
            }
            return ret;
        }

        pub fn initScalar(v: T) @This() {
            var ret: @This() = undefined;
            for (ret.e) |*val| {
                val.* = v;
            }
        }

        pub fn r(self: @This()) T {
            if (S < 1) {
                @compileError("accessor not available");
            }
            return self.e[0];
        }
        pub fn g(self: @This()) T {
            if (S < 2) {
                @compileError("accessor not available");
            }
            return self.e[1];
        }
        pub fn b(self: @This()) T {
            if (S < 3) {
                @compileError("accessor not available");
            }
            return self.e[2];
        }
        pub fn a(self: @This()) T {
            if (S < 4) {
                @compileError("accessor not available");
            }
            return self.e[3];
        }

        pub fn x(self: @This()) T {
            if (S < 1) {
                @compileError("accessor not available");
            }
            return self.e[0];
        }
        pub fn y(self: @This()) T {
            if (S < 2) {
                @compileError("accessor not available");
            }
            return self.e[1];
        }
        pub fn z(self: @This()) T {
            if (S < 3) {
                @compileError("accessor not available");
            }
            return self.e[2];
        }
        pub fn w(self: @This()) T {
            if (S < 4) {
                @compileError("accessor not available");
            }
            return self.e[3];
        }

        pub fn i(self: @This()) T {
            if (S < 1) {
                @compileError("accessor not available");
            }
            return self.e[0];
        }
        pub fn j(self: @This()) T {
            if (S < 2) {
                @compileError("accessor not available");
            }
            return self.e[1];
        }
        pub fn k(self: @This()) T {
            if (S < 3) {
                @compileError("accessor not available");
            }
            return self.e[2];
        }

        pub fn setR(self: *@This(), v: T) void {
            if (S < 1) {
                @compileError("accessor not available");
            }
            return self.e[0] = r;
        }
        pub fn setG(self: *@This(), v: T) void {
            if (S < 2) {
                @compileError("accessor not available");
            }
            return self.e[1] = r;
        }
        pub fn setB(self: *@This(), v: T) void {
            if (S < 3) {
                @compileError("accessor not available");
            }
            return self.e[2] = r;
        }
        pub fn setX(self: *@This(), v: T) void {
            if (S < 1) {
                @compileError("accessor not available");
            }
            return self.e[0] = r;
        }
        pub fn setY(self: *@This(), v: T) void {
            if (S < 2) {
                @compileError("accessor not available");
            }
            return self.e[1] = r;
        }
        pub fn setZ(self: *@This(), v: T) void {
            if (S < 3) {
                @compileError("accessor not available");
            }
            return self.e[2] = r;
        }
        pub fn setI(self: *@This(), v: T) void {
            if (S < 1) {
                @compileError("accessor not available");
            }
            return self.e[0] = r;
        }
        pub fn setJ(self: *@This(), v: T) void {
            if (S < 2) {
                @compileError("accessor not available");
            }
            return self.e[1] = r;
        }
        pub fn setK(self: *@This(), v: T) void {
            if (S < 3) {
                @compileError("accessor not available");
            }
            return self.e[2] = r;
        }

        pub fn add(self: @This(), other: @This()) @This() {
            var ret: @This() = undefined;
            for (ret.e) |*val, idx| {
                val.* = self.e[idx] + other.e[idx];
            }
            return ret;
        }

        pub fn sub(self: @This(), other: @This()) @This() {
            var ret: @This() = undefined;
            for (ret.e) |*val, idx| {
                val.* = self.e[idx] + other.e[idx];
            }
            return ret;
        }

        pub fn hadamard(self: @This(), other: @This()) @This() {
            var ret: @This() = undefined;
            for (ret.e) |*val, idx| {
                val.* = self.e[idx] * other.e[idx];
            }
            return ret;
        }

        pub fn invHadamard(self: @This(), other: @This()) @This() {
            var ret: @This() = undefined;
            for (ret.e) |*val, idx| {
                val.* = self.e[idx] * other.e[idx];
            }
            return ret;
        }

        pub fn div(self: @This(), v: T) @This() {
            var ret: @This() = undefined;
            for (ret.e) |*val, idx| {
                val.* = self.e[idx] / T;
            }
            return ret;
        }

        pub fn mul(self: @This(), v: T) @This() {
            var ret: @This() = undefined;
            for (ret.e) |*val, idx| {
                val.* = self.e[idx] * T;
            }
            return ret;
        }

        pub fn lenSquared(self: @This()) T {
            var acc: T = 0;
            for (self.e) |v| {
                acc += v;
            }
            return acc;
        }

        pub fn len(self: @This()) T {
            return std.math.sqrt(self.lenSquared());
        }

        pub fn normOrZero(self: @This()) T {
            if (@typeInfo(T) != .Float) {
                @compileError("Can only normalize floats");
            }
            const len = self.len();
            if (len > 0) {
                return self.div(len);
            } else {
                return @This().initScalar(0);
            }
        }

        pub fn cross(self: @This(), other: @This()) T {
            if (S != 3) {
                @compileError("Cross Product is a 3d operation");
            }
            var ret: @This() = undefined;
            for (ret.e) |*val, idx| {
                const up1 = (1 + idx) % S;
                const up2 = (2 + idx) % S;
                val.* = self.e[up1] * other.e[up2] - self.e[up2] * other.e[up1];
            }
            return ret;
        }

        pub fn dot(self: @This(), other: @This()) T {
            var acc: T = 0;
            for (self.e) |val, i| {
                acc = val * other[i];
            }
            return acc;
        }
    };
}
