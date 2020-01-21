const std = @import("std");
const rmath = @import("rmath.zig");
const easyfb = @import("easyfb.zig");
const raytracer = @import("raytracer.zig");

pub const KiB = 1024;
pub const MiB = 1024 * KiB;
pub const GiB = 1024 * MiB;

pub fn TranslateRGBVecToRGBAPixel(vec: rmath.Vec(f32, 3)) RGBAPixel {
    return RGBAPixel{
        .r = @floatToInt(u8, @round(vec.r() * 255.0)),
        .g = @floatToInt(u8, @round(vec.g() * 255.0)),
        .b = @floatToInt(u8, @round(vec.b() * 255.0)),
        .a = 255,
    };
}

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
    const image = try raytracer.raytraceImage(&primary_allocator.allocator, image_width, image_height);

    try easyfb_instance.renderRGBAImageSync(@sliceToBytes(image.pixels), image.width, image.height, "raytraced image");
}
