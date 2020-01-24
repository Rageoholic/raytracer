const std = @import("std");
const rmath = @import("rmath/rmath.zig");
const easyfb = @import("easyfb/easyfb.zig");
const raytracer = @import("raytracer/raytracer.zig");

pub const KiB = 1024;
pub const MiB = 1024 * KiB;
pub const GiB = 1024 * MiB;

pub fn main() anyerror!void {
    const raytracer_mem = try std.heap.page_allocator.alloc(u8, 512 * MiB);
    defer std.heap.page_allocator.free(raytracer_mem);

    const os_mem = try std.heap.page_allocator.alloc(u8, 1 * MiB);
    defer std.heap.page_allocator.free(os_mem);

    var primary_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(raytracer_mem);
    var os_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(os_mem);

    var easyfb_instance = try easyfb.EasyFBInstance.init(&os_allocator.allocator, "EasyFB");

    const image_width = 1600;
    const image_height = 900;
    const spheres = [_]raytracer.Sphere{
        raytracer.Sphere{
            .center = rmath.Vec(f32, 3){ .e = [_]f32{ 0, 0, -1 } },
            .radius = 0.5,
            .mat = 5,
        },
        raytracer.Sphere{
            .center = rmath.Vec(f32, 3){ .e = [_]f32{ -1, 1, -2 } },
            .radius = 0.5,
            .mat = 0,
        },

        raytracer.Sphere{
            .center = rmath.Vec(f32, 3){ .e = [_]f32{ 1, 1, -2 } },
            .radius = 0.5,
            .mat = 2,
        },
        raytracer.Sphere{
            .center = rmath.vec3(3, 1, -2),
            .radius = 1,
            .mat = 3,
        },

        raytracer.Sphere{
            .center = rmath.vec3(6, 2, -8),
            .radius = 2,
            .mat = 4,
        },
    };

    const planes = [_]raytracer.Plane{
        raytracer.Plane{
            .norm = rmath.Vec(f32, 3){ .e = [_]f32{ 0, 1, 0 } },
            .distance_from_origin = -0.5,
            .mat = 1,
        },
    };

    const materials = [_]raytracer.Material{
        .{
            .Default = .{
                .ref = rmath.Vec3F32{ .e = [_]f32{ 0.5, 0.5, 0.5 } },
                .emit = rmath.Vec3F32.initScalar(0),
                .specular = 1,
            },
        },
        .{
            .Default = .{
                .ref = rmath.Vec3F32{ .e = [_]f32{ 0.3, 0.9, 0.1 } },
                .emit = rmath.Vec3F32.initScalar(0),
                .specular = 0.2,
            },
        },
        .{
            .Default = .{
                .ref = rmath.Vec3F32{ .e = [_]f32{ 0.7, 0.9, 0.1 } },
                .emit = rmath.Vec3F32{ .e = [_]f32{ 0.5, 0.1, 0.1 } },
                .specular = 0.7,
            },
        },
        .{
            .Default = .{
                .ref = rmath.Vec3F32{ .e = [_]f32{ 0.7, 0.9, 0.1 } },
                .emit = rmath.Vec3F32{ .e = [_]f32{ 0.5, 0.1, 0.8 } },
                .specular = 0.7,
            },
        },
        .{
            .Default = .{
                .ref = rmath.Vec3F32{ .e = [_]f32{ 0, 0, 0 } },
                .emit = rmath.Vec3F32{ .e = [_]f32{ 0.5, 0.1, 0.8 } },
                .specular = 0.7,
            },
        },
        .{
            .Default = .{
                .ref = rmath.Vec3F32{ .e = [_]f32{ 0, 0, 0 } },
                .emit = rmath.Vec3F32{ .e = [_]f32{ 1, 0.1, 1 } },
                .specular = 0.7,
            },
        },
    };

    var world = raytracer.World{
        .spheres = spheres[0..],
        .materials = materials[0..],
        .planes = planes[0..],
    };
    var rand = std.rand.Pcg.init(0);
    const camera_pos = rmath.Vec3F32{ .e = [3]f32{ 0, 1, 4 } };
    const camera_targ = rmath.Vec3F32{ .e = [3]f32{ 0, 0, -1 } };
    const camera_up = rmath.Vec3F32{ .e = [3]f32{ 0, 1, 0 } };
    const aspect = @intToFloat(f32, image_width) / @intToFloat(f32, image_height);

    const cpu_count = std.Thread.cpuCount() catch |err| 1;

    var image = try raytracer.ImageRGBAU8.init(
        &primary_allocator.allocator,
        image_width,
        image_height,
    );
    defer image.deinit();

    const tiles = try image.divideIntoTiles(&primary_allocator.allocator, cpu_count);
    defer primary_allocator.allocator.free(tiles);

    const camera = raytracer.Camera.init(camera_pos, camera_targ, camera_up, 60, aspect);
    std.debug.warn("{} cpus on this machine\n", .{cpu_count});

    var timer = try std.time.Timer.start();
    for (tiles) |tile| {
        world.raytraceTile(&rand.random, tile, camera, image, 16);
    }

    const time_ns = timer.read();
    std.debug.warn("{} ns, {} s,{} bounces, approx {} ns per bounce\n", .{
        time_ns,
        @intToFloat(f32, time_ns) / 1000000000,
        world.bounce_count,
        time_ns / world.bounce_count,
    });

    try easyfb_instance.renderRGBAImageSync(
        @sliceToBytes(image.pixels),
        image.width,
        image.height,
        "simple raytracer",
    );
}
