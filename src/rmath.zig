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
            return ret;
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

        pub fn rp(self: *@This()) *T {
            if (S < 1) {
                @compileError("accessor not available");
            }
            return &self.e[0];
        }
        pub fn gp(self: *@This()) *T {
            if (S < 2) {
                @compileError("accessor not available");
            }
            return &self.e[1];
        }
        pub fn bp(self: *@This()) *T {
            if (S < 3) {
                @compileError("accessor not available");
            }
            return &self.e[2];
        }
        pub fn ap(self: *@This()) *T {
            if (S < 4) {
                @compileError("accessor not available");
            }
            return &self.e[3];
        }

        pub fn xp(self: *@This()) *T {
            if (S < 1) {
                @compileError("accessor not available");
            }
            return &self.e[0];
        }
        pub fn yp(self: *@This()) *T {
            if (S < 2) {
                @compileError("accessor not available");
            }
            return &self.e[1];
        }
        pub fn zp(self: *@This()) *T {
            if (S < 3) {
                @compileError("accessor not available");
            }
            return &self.e[2];
        }
        pub fn wp(self: *@This()) *T {
            if (S < 4) {
                @compileError("accessor not available");
            }
            return &self.e[3];
        }

        pub fn ip(self: *@This()) *T {
            if (S < 1) {
                @compileError("accessor not available");
            }
            return &self.e[0];
        }
        pub fn jp(self: *@This()) *T {
            if (S < 2) {
                @compileError("accessor not available");
            }
            return &self.e[1];
        }
        pub fn kp(self: *@This()) *T {
            if (S < 3) {
                @compileError("accessor not available");
            }
            return &self.e[2];
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
            var ret = @This().initScalar(0);
            for (ret.e) |*val, idx| {
                val.* = (self.e[idx] / v);
            }
            return ret;
        }

        pub fn mul(self: @This(), v: T) @This() {
            var ret: @This() = undefined;
            for (ret.e) |*val, idx| {
                val.* = self.e[idx] * v;
            }
            return ret;
        }

        pub fn lenSquared(self: @This()) T {
            var acc: T = 0;
            for (self.e) |v| {
                acc += v * v;
            }
            return acc;
        }

        pub fn len(self: @This()) T {
            return std.math.sqrt(self.lenSquared());
        }

        pub fn normOrZero(self: @This()) @This() {
            if (@typeInfo(T) != .Float) {
                @compileError("Can only normalize floats");
            }
            const l = self.len();
            if (l > 0) {
                return self.div(l);
            } else {
                std.debug.warn("Zero vec\n", .{});
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
        pub fn lerp(self: @This(), other: @This(), t: T) @This() {
            if (@typeInfo(T) != .Float) {
                @compileError("Lerp can't be done with integers");
            }
            return self.mul(t).add(other.mul(1 - t));
        }
    };
}

pub const Ray = struct {
    // NOTE: If constructing, dir is expected to be a normal
    dir: Vec(f32, 3),
    pos: Vec(f32, 3),
    pub fn init(unnormalized_dir: Vec(f32, 3), pos: Vec(f32, 3)) @This() {
        return @This(){
            .dir = unnormalized_dir.normOrZero(),
            .pos = pos,
        };
    }

    pub fn pointAtLen(self: @This(), t: f32) rmath.Vec(f32, 3) {
        return self.pos.add(self.dir.mul(t));
    }
};
