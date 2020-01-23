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
            .mat = 0,
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
            .center = rmath.Vec(f32, 3){ .e = [_]f32{ 0, -100.5, -1 } },
            .radius = 100,
            .mat = 1,
        },
    };

    const materials = [_]raytracer.Material{
        .{
            .Metal = .{
                .ref = rmath.Vec3F32{ .e = [_]f32{ 0.5, 0.5, 0.5 } },
                .emit = rmath.Vec3F32.initScalar(0),
                .specular = 1,
            },
        },
        .{
            .Metal = .{
                .ref = rmath.Vec3F32{ .e = [_]f32{ 0.3, 0.9, 0.1 } },
                .emit = rmath.Vec3F32.initScalar(0),
                .specular = 0.2,
            },
        },
        .{
            .Metal = .{
                .ref = rmath.Vec3F32{ .e = [_]f32{ 0.7, 0.9, 0.1 } },
                .emit = rmath.Vec3F32{ .e = [_]f32{ 0.5, 0.1, 0.1 } },
                .specular = 0.2,
            },
        },
    };

    var world = raytracer.World{ .spheres = spheres[0..], .materials = materials[0..] };
    var rand = std.rand.Pcg.init(0);
    const camera_pos = rmath.Vec3F32{ .e = [3]f32{ 0, 4, 10 } };
    const camera_targ = rmath.Vec3F32{ .e = [3]f32{ 0, 0, 0 } };
    const camera_up = rmath.Vec3F32{ .e = [3]f32{ 0, 1, 0 } };
    var timer = try std.time.Timer.start();
    var image = try world.raytraceImage(
        &primary_allocator.allocator,
        &rand.random,
        image_width,
        image_height,
        camera_pos,
        camera_targ,
        camera_up,
        90,
        16,
    );
    const time_ns = timer.read();
    std.debug.warn("{} ns, {} s", .{ time_ns, @intToFloat(f32, time_ns) / 1000000000 });
    defer image.deinit();

    try easyfb_instance.renderRGBAImageSync(@sliceToBytes(image.pixels), image.width, image.height, "raytraced image");
}
