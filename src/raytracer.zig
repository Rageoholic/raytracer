pub usingnamespace @import("raytracer/types.zig");
const std = @import("std");
const rmath = @import("rmath.zig");
const Allocator = std.mem.Allocator;

pub fn TranslateRGBVecToRGBAPixelU8(vec: rmath.Vec(f32, 3)) RGBAPixelU8 {
    return RGBAPixelU8{
        .r = @floatToInt(u8, @round(vec.r() * 255.0)),
        .g = @floatToInt(u8, @round(vec.g() * 255.0)),
        .b = @floatToInt(u8, @round(vec.b() * 255.0)),
        .a = 255,
    };
}

pub fn raytraceImage(
    allocator: *Allocator,
    image_width: u32,
    image_height: u32,
) error{OutOfMemory}!ImageRGBAU8 {
    const image = try ImageRGBAU8.init(allocator, image_width, image_height);
    const aspect = @intToFloat(f32, image_width) / @intToFloat(f32, image_height);
    const n = aspect * 3 / 2;
    const lower_left_corner = rmath.Vec(f32, 3){ .e = [3]f32{ -n, -1, 1 } };
    const horizontal = rmath.Vec(f32, 3){ .e = [3]f32{ 2 * n, 0, 0 } };
    const vertical = rmath.Vec(f32, 3){ .e = [3]f32{ 0, -2, 0 } };
    const origin = rmath.Vec(f32, 3).initScalar(0);
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
        const t = ray.dir.y() * 0.5 + 1;
        const v1 = rmath.Vec(f32, 3).initScalar(1);
        const v2 = rmath.Vec(f32, 3){ .e = [_]f32{ 0.5, 0.7, 1.0 } };
        const col = v2.lerp(v1, t);
        pixel = TranslateRGBVecToRGBAPixelU8(col);
    }
    return image;
}
