pub usingnamespace @import("types.zig");
const std = @import("std");
const rmath = @import("../rmath/rmath.zig");
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;

pub fn TranslateRGBVecToRGBAPixelU8(vec: rmath.Vec3F32) RGBAPixelU8 {
    const clamp_r = std.math.min(std.math.max(vec.r(), 0), 1);
    const clamp_g = std.math.min(std.math.max(vec.g(), 0), 1);
    const clamp_b = std.math.min(std.math.max(vec.b(), 0), 1);
    const corrected_r = std.math.sqrt(clamp_r);
    const corrected_g = std.math.sqrt(clamp_g);
    const corrected_b = std.math.sqrt(clamp_b);

    return RGBAPixelU8{
        .r = @floatToInt(u8, @round(corrected_r * 255)),
        .g = @floatToInt(u8, @round(corrected_g * 255)),
        .b = @floatToInt(u8, @round(corrected_b * 255)),
        .a = 255,
    };
}

fn random_bilateral_vec(random: *Random) rmath.Vec3F32 {
    return rmath.Vec3F32{
        .e = [_]f32{
            (random.float(f32) * 2) - 1,
            (random.float(f32) * 2) - 1,
            (random.float(f32) * 2) - 1,
        },
    };
}

pub const World = struct {
    spheres: []const Sphere,
    planes: []const Plane,
    materials: []const Material,
    pub fn raytraceImage(
        self: *@This(),
        allocator: *Allocator,
        random: *Random,
        image_width: u32,
        image_height: u32,
        camera_pos: rmath.Vec3F32,
        camera_targ: rmath.Vec3F32,
        camera_up: rmath.Vec3F32,
        vfov: f32,
        sample_count: u5,
    ) error{OutOfMemory}!ImageRGBAU8 {
        const image = try ImageRGBAU8.init(allocator, image_width, image_height);
        const theta = vfov / 180 * std.math.pi;
        const aspect = @intToFloat(f32, image_width) / @intToFloat(f32, image_height);
        const half_height = std.math.tan(theta / 2);
        const half_width = aspect * half_height;

        const camera_z = camera_pos.sub(camera_targ).normOrZero();
        const camera_x = camera_up.cross(camera_z).normOrZero();
        const camera_y = camera_z.cross(camera_x);

        const lower_left_corner = camera_pos.sub(camera_x.mul(half_width)).sub(camera_y.mul(half_height)).sub(camera_z);
        const horizontal = camera_x.mul(2 * half_width);
        const vertical = camera_y.mul(2 * half_height);

        for (image.pixels) |pixel, i| {
            const x = i % image_width;
            const y = @divFloor(i, image_width);
            const net_samples = rmath.Vec3F32.initScalar(0);

            var sample_index: u5 = 0;
            while (sample_index < sample_count) {
                defer sample_index += 1;
                const u = (@intToFloat(f32, x) + random.float(f32)) / @intToFloat(f32, image_width);
                const v = 1 - (@intToFloat(f32, y) + random.float(f32)) / @intToFloat(f32, image_height);
                const dir = lower_left_corner.add(horizontal.mul(u)).add(vertical.mul(v)).sub(camera_pos);
                var ray = rmath.Ray3F32.init(
                    dir,
                    camera_pos,
                );
                const attenuation = rmath.Vec3F32.initScalar(1);
                var net_color = rmath.Vec3F32.initScalar(0);
                var bounce_index: usize = 0;
                const bounce_count = 8;

                while (bounce_index < bounce_count) {
                    defer bounce_index += 1;
                    var material_opt: ?usize = null;
                    var bounce_normal: ?rmath.Vec3F32 = null;

                    const t = (ray.dir.y() + 1) * 0.5;

                    const v1 = rmath.Vec3F32.initScalar(1);
                    const v2 = rmath.Vec3F32{ .e = [_]f32{ 0.5, 0.7, 1.0 } };
                    var col = v2.lerp(v1, t);

                    var distance: f32 = std.math.inf(f32);

                    for (self.spheres) |sphere| {
                        const sphere_hit_opt = sphere.hit(ray);
                        if (sphere_hit_opt) |sphere_hit| {
                            if (sphere_hit.neg < distance and sphere_hit.neg > 0.0001) {
                                distance = sphere_hit.neg;
                                material_opt = sphere.mat;
                                bounce_normal = ray.getPointAtDistance(distance).sub(sphere.center).normOrZero();
                            }
                            if (sphere_hit.pos < distance and sphere_hit.pos > 0.0001) {
                                distance = sphere_hit.neg;
                                material_opt = sphere.mat;
                                bounce_normal = ray.getPointAtDistance(distance).sub(sphere.center).normOrZero();
                            }
                        }
                    }
                    for (self.planes) |plane| {
                        if (plane.hit(ray)) |plane_hit| {
                            if (plane_hit.distance < distance and plane_hit.distance > 0.0001) {
                                distance = plane_hit.distance;
                                material_opt = plane.mat;
                                bounce_normal = plane.norm;
                            }
                        }
                    }
                    if (material_opt) |material_index| {
                        const mat = self.materials[material_index];
                        switch (mat) {
                            .Metal => |metal| {
                                net_color = net_color.add(attenuation.hadamardMul(metal.emit));
                                attenuation = attenuation.hadamardMul(metal.ref);
                                ray.pos = ray.getPointAtDistance(distance);
                                const pure_bounce = ray.dir.reflect(bounce_normal.?).normOrZero();
                                const random_bounce = bounce_normal.?.add(random_bilateral_vec(random));
                                ray.dir = pure_bounce.lerp(random_bounce, metal.specular);
                            },
                        }
                    } else {
                        net_color = net_color.add(attenuation.hadamardMul(col));
                        break;
                    }
                }
                net_samples = net_samples.add(net_color);
            }

            pixel = TranslateRGBVecToRGBAPixelU8(net_samples.div(@intToFloat(f32, sample_count)));
        }
        return image;
    }
};
