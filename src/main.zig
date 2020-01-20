const std = @import("std");
const rmath = @import("rmath.zig");
const easyfb = @import("easyfb.zig");

const Pixel = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const KiB = 1024;
pub const MiB = 1024 * KiB;
pub const GiB = 1024 * MiB;

pub fn TranslateRGBVecToPixel(vec: rmath.Vec(f32, 3)) Pixel {
    return Pixel{
        .r = @floatToInt(u8, @round(vec.r() * 255.0)),
        .g = @floatToInt(u8, @round(vec.g() * 255.0)),
        .b = @floatToInt(u8, @round(vec.b() * 255.0)),
        .a = 255,
    };
}

pub fn main() anyerror!void {
    std.debug.warn("All your base are belong to us.\n", .{});

    const raytracer_mem = try std.heap.page_allocator.alloc(u8, 2 * GiB);
    defer std.heap.page_allocator.free(raytracer_mem);

    const os_mem = try std.heap.page_allocator.alloc(u8, 1 * MiB);
    defer std.heap.page_allocator.free(os_mem);

    var primary_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(raytracer_mem);
    var os_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(os_mem);

    var easyfb_instance = try easyfb.EasyFBInstance.init(&os_allocator.allocator, "EasyFB");

    const image_width = 1600;
    const image_height = 900;

    const image = try primary_allocator.allocator.alloc(Pixel, image_width * image_height);

    for (image) |pixel, i| {
        const x = i % image_width;
        const y = @divFloor(i, image_width);
        const x_per = @intToFloat(f32, x) / @intToFloat(f32, image_width);
        const y_per = @intToFloat(f32, y) / @intToFloat(f32, image_height);
        const val_array = [3]f32{ x_per, y_per, 1 };
        const col = rmath.Vec(f32, 3).initSlice(val_array[0..]);
        pixel = TranslateRGBVecToPixel(col);
    }

    try easyfb_instance.renderRGBAImageSync(@sliceToBytes(image), image_width, image_height, "raytraced image");
}
