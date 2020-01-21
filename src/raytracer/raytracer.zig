pub usingnamespace @import("types.zig");
const std = @import("std");
const rmath = @import("../rmath/rmath.zig");
const Allocator = std.mem.Allocator;

pub fn TranslateRGBVecToRGBAPixelU8(vec: rmath.Vec3F32) RGBAPixelU8 {
    return RGBAPixelU8{
        .r = @floatToInt(u8, @round(vec.r() * 255.0)),
        .g = @floatToInt(u8, @round(vec.g() * 255.0)),
        .b = @floatToInt(u8, @round(vec.b() * 255.0)),
        .a = 255,
    };
}
pub const World = struct {
    spheres: []Sphere,
    allocator: *Allocator,
    pub fn init(allocator: *Allocator, spheres: []const Sphere) error{OutOfMemory}!@This() {
        const spheres_copy = try allocator.alloc(Sphere, spheres.len);
        std.mem.copy(Sphere, spheres_copy, spheres);
        return @This(){ .spheres = spheres_copy, .allocator = allocator };
    }
    pub fn raytraceImage(
        self: *@This(),
        camera_x: f32,
        camera_y: f32,
        camera_z: f32,
        image_width: u32,
        image_height: u32,
    ) error{OutOfMemory}!ImageRGBAU8 {
        const image = try ImageRGBAU8.init(self.allocator, image_width, image_height);
        const aspect = @intToFloat(f32, image_width) / @intToFloat(f32, image_height);

        const n = aspect;
        const lower_left_corner = rmath.Vec3F32{ .e = [3]f32{ -n, -1, -1 } };
        const horizontal = rmath.Vec3F32{ .e = [3]f32{ n * 2, 0, 0 } };
        const vertical = rmath.Vec3F32{ .e = [3]f32{ 0, 2, 0 } };
        const origin = rmath.Vec3F32.initScalar(0);
        for (image.pixels) |pixel, i| {
            const x = i % image_width;
            const y = @divFloor(i, image_width);
            const u = @intToFloat(f32, x) / @intToFloat(f32, image_width);
            const v = @intToFloat(f32, y) / @intToFloat(f32, image_height);
            const dir = lower_left_corner.add(horizontal.mul(u)).add(vertical.mul(v));
            const ray = rmath.Ray.init(
                dir,
                origin,
            );
            const t = (ray.dir.y() + 1) * 0.5;
            const v1 = rmath.Vec3F32.initScalar(1);
            const v2 = rmath.Vec3F32{ .e = [_]f32{ 0.5, 0.7, 1.0 } };
            var col = v1.lerp(v2, t);
            for (self.spheres) |sphere| {
                if (sphere.hit(ray)) {
                    col = rmath.Vec(f32, 3){ .e = [_]f32{ 1, 0, 0 } };
                }
            }
            pixel = TranslateRGBVecToRGBAPixelU8(col);
        }
        return image;
    }
};
