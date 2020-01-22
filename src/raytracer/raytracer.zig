pub usingnamespace @import("types.zig");
const std = @import("std");
const rmath = @import("../rmath/rmath.zig");
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;

pub fn TranslateRGBVecToRGBAPixelU8(vec: rmath.Vec3F32) RGBAPixelU8 {
    return RGBAPixelU8{
        .r = @floatToInt(u8, @round(vec.r() * 255.0)),
        .g = @floatToInt(u8, @round(vec.g() * 255.0)),
        .b = @floatToInt(u8, @round(vec.b() * 255.0)),
        .a = 255,
    };
}

pub const World = struct {
    spheres: []const Sphere,
    materials: []const Material,
    pub fn raytraceImage(
        self: *@This(),
        allocator: *Allocator,
        random: *Random,
        image_width: u32,
        image_height: u32,
        sample_count: u5,
    ) error{OutOfMemory}!ImageRGBAU8 {
        const image = try ImageRGBAU8.init(allocator, image_width, image_height);
        const aspect = @intToFloat(f32, image_width) / @intToFloat(f32, image_height);

        // TODO: Field of view
        const n = aspect;
        const lower_left_corner = rmath.Vec3F32{ .e = [3]f32{ -n, -1, -1 } };
        const horizontal = rmath.Vec3F32{ .e = [3]f32{ n * 2, 0, 0 } };
        const vertical = rmath.Vec3F32{ .e = [3]f32{ 0, 2, 0 } };
        const origin = rmath.Vec3F32.initScalar(0);

        for (image.pixels) |pixel, i| {
            const x = i % image_width;
            const y = @divFloor(i, image_width);
            const net_samples = rmath.Vec3F32.initScalar(0);

            var sample_index: u5 = 0;
            while (sample_index < sample_count) {
                defer sample_index += 1;
                const u = (@intToFloat(f32, x) + random.float(f32)) / @intToFloat(f32, image_width);
                const v = 1 - (@intToFloat(f32, y) + random.float(f32)) / @intToFloat(f32, image_height);
                const dir = lower_left_corner.add(horizontal.mul(u)).add(vertical.mul(v));
                const ray = rmath.Ray3F32.init(
                    dir,
                    origin,
                );

                var material_opt: ?usize = null;

                const t = (ray.dir.y() + 1) * 0.5;

                const v1 = rmath.Vec3F32.initScalar(1);
                const v2 = rmath.Vec3F32{ .e = [_]f32{ 0.5, 0.7, 1.0 } };
                var col = v2.lerp(v1, t);

                var distance: f32 = std.math.inf(f32);

                for (self.spheres) |sphere| {
                    const sphere_hit_opt = sphere.hit(ray);
                    if (sphere_hit_opt) |sphere_hit| {
                        if (sphere_hit.neg < distance and sphere_hit.neg > 0) {
                            distance = sphere_hit.neg;
                            material_opt = sphere.mat;
                        }
                        if (sphere_hit.pos < distance and sphere_hit.pos > 0) {
                            distance = sphere_hit.neg;
                            material_opt = sphere.mat;
                        }
                    }
                }
                if (material_opt) |material_index| {
                    const mat = self.materials[material_index];
                    net_samples = net_samples.add(mat.col);
                } else {
                    net_samples = net_samples.add(col);
                }
            }

            pixel = TranslateRGBVecToRGBAPixelU8(net_samples.div(@intToFloat(f32, sample_count)));
        }
        return image;
    }
};
