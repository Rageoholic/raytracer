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

const RefractInfo = struct {
    reflect_prob: f32,
    refracted: rmath.Vec3F32,
};

fn refract(
    v: rmath.Vec3F32,
    n: rmath.Vec3F32,
    ni_over_nt: f32,
    cosine: f32,
    ref_idx: f32,
) ?RefractInfo {
    const uv = v.normOrZero();
    const dt = uv.dot(n);
    const discriminant = 1 - ni_over_nt * ni_over_nt * (1 - dt * dt);
    if (discriminant > 0) {
        const refracted = uv.sub(
            n.mul(dt),
        ).mul(
            ni_over_nt,
        ).sub(
            n.mul(std.math.sqrt(discriminant)),
        );

        const r0 = (1 - ref_idx) / (1 + ref_idx);
        const r0_square = r0 * r0;
        const ref_prob = r0_square + (1 - r0_square) * std.math.pow(f32, (1 - cosine), 5);
        return RefractInfo{ .reflect_prob = ref_prob, .refracted = refracted };
    } else {
        return null;
    }
}

pub const World = struct {
    spheres: []const Sphere,
    planes: []const Plane,
    materials: []const Material,
    bounce_count: usize = 0,
    const RaytraceResult = struct {
        col: rmath.Vec3F32,
        bounce_count: usize,
    };
    pub fn raytrace(self: @This(), fired_ray: rmath.Ray3F32, random: *Random) RaytraceResult {
        var ray = fired_ray;

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
                    if (sphere_hit.neg < distance and sphere_hit.neg > 0.001) {
                        distance = sphere_hit.neg;
                        material_opt = sphere.mat;
                        bounce_normal = ray.getPointAtDistance(sphere_hit.neg).sub(sphere.center).normOrZero();
                    }
                    if (sphere_hit.pos < distance and sphere_hit.pos > 0.001) {
                        distance = sphere_hit.pos;
                        material_opt = sphere.mat;
                        bounce_normal = ray.getPointAtDistance(sphere_hit.pos).sub(sphere.center).normOrZero();
                    }
                }
            }
            for (self.planes) |plane| {
                if (plane.hit(ray)) |plane_hit| {
                    if (plane_hit.distance < distance and plane_hit.distance > 0.001) {
                        distance = plane_hit.distance;
                        material_opt = plane.mat;
                        bounce_normal = plane.norm;
                    }
                }
            }
            if (material_opt) |material_index| {
                const mat = self.materials[material_index];
                switch (mat) {
                    .Default => |metal| {
                        net_color = net_color.add(attenuation.hadamardMul(metal.emit));
                        attenuation = attenuation.hadamardMul(metal.ref);
                        ray.pos = ray.getPointAtDistance(distance);
                        const pure_bounce = ray.dir.reflect(bounce_normal.?).normOrZero();
                        const random_bounce = bounce_normal.?.add(random_bilateral_vec(random));
                        ray.dir = pure_bounce.lerp(random_bounce, metal.specular);
                    },
                    .Dielectric => |di| {
                        const reflect = ray.dir.reflect(bounce_normal.?);
                        const pos_dot = !(ray.dir.dot(bounce_normal.?) > 0);
                        const out_normal = bounce_normal.?.mul(if (pos_dot) 1 else -1);
                        const ni_over_nt = if (pos_dot) 1 / di.ref_idx else di.ref_idx;
                        const cosine = di.ref_idx * std.math.absFloat(ray.dir.dot(bounce_normal.?));
                        var new_ray: rmath.Ray3F32 = undefined;
                        new_ray.pos = ray.getPointAtDistance(distance);
                        new_ray.dir = reflect;
                        if (refract(
                            ray.dir,
                            bounce_normal.?,
                            ni_over_nt,
                            cosine,
                            di.ref_idx,
                        )) |refract_info| {
                            if (random.float(f32) > refract_info.reflect_prob) {
                                new_ray.dir = refract_info.refracted;
                            }
                        }
                        ray = new_ray;
                    },
                }
            } else {
                net_color = net_color.add(attenuation.hadamardMul(col));
                return .{ .col = net_color, .bounce_count = bounce_index + 1 };
            }
        }
        std.debug.warn("Missed sky", .{});
        return .{ .col = net_color, .bounce_count = bounce_count };
    }

    pub fn raytraceTile(
        self: *@This(),
        random: *Random,
        tile: Tile,
        camera: Camera,
        image: *ImageRGBAU8,
        sample_count: usize,
    ) void {
        var y = tile.y;
        while (y < (tile.height + tile.y)) : (y += 1) {
            var x = tile.x;
            while (x < (tile.width + tile.x)) : (x += 1) {
                const pixel_index = x + image.width * y;

                const pixel = &image.pixels[x + image.width * y];

                const net_samples = rmath.Vec3F32.initScalar(0);

                var sample_index: usize = 0;
                while (sample_index < sample_count) {
                    defer sample_index += 1;
                    const u = (@intToFloat(f32, x) + random.float(f32)) /
                        @intToFloat(f32, image.width);
                    const v = 1 - (@intToFloat(f32, y) + random.float(f32)) /
                        @intToFloat(f32, image.height);
                    var ray = camera.ray(u, v);
                    const raytrace_result = self.raytrace(ray, random);
                    _ = @atomicRmw(
                        usize,
                        &self.bounce_count,
                        .Add,
                        raytrace_result.bounce_count,
                        .SeqCst,
                    );
                    net_samples = net_samples.add(raytrace_result.col);
                }

                pixel.* = TranslateRGBVecToRGBAPixelU8(
                    net_samples.div(@intToFloat(f32, sample_count)),
                );
            }
        }
    }

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
        sample_count: usize,
    ) error{
        OutOfMemory,
        TimerUnsupported,
    }!ImageRGBAU8 {
        const image = try ImageRGBAU8.init(allocator, image_width, image_height);
        const aspect = @intToFloat(f32, image_width) / @intToFloat(f32, image_height);
        const camera = Camera.init(camera_pos, camera_targ, camera_up, vfov, aspect);

        var total_bounce_count: usize = 0;
        for (image.pixels) |pixel, i| {
            const x = i % image_width;
            const y = @divFloor(i, image_width);
            const net_samples = rmath.Vec3F32.initScalar(0);

            var sample_index: usize = 0;
            while (sample_index < sample_count) {
                defer sample_index += 1;
                const u = (@intToFloat(f32, x) + random.float(f32)) / @intToFloat(f32, image_width);
                const v = 1 - (@intToFloat(f32, y) + random.float(f32)) / @intToFloat(f32, image_height);
                var ray = camera.ray(u, v);
                const raytrace_result = self.raytrace(ray, random);
                net_samples = net_samples.add(raytrace_result.col);
                _ = @atomicRmw(usize, &self.bounce_count, .Add, raytrace_result.bounce_count, .SeqCst);
            }

            pixel = TranslateRGBVecToRGBAPixelU8(net_samples.div(@intToFloat(f32, sample_count)));
        }
        return image;
    }
};
