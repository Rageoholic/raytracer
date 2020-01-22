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
        },
        raytracer.Sphere{
            .center = rmath.Vec(f32, 3){ .e = [_]f32{ 0, -100.5, -1 } },
            .radius = 100,
        },
    };

    var world = raytracer.World{ .spheres = spheres[0..] };
    var rand = std.rand.Pcg.init(0);
    var image = try world.raytraceImage(&primary_allocator.allocator, &rand.random, image_width, image_height, 4);
    defer image.deinit();

    try easyfb_instance.renderRGBAImageSync(@sliceToBytes(image.pixels), image.width, image.height, "raytraced image");
}
