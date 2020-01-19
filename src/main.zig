const std = @import("std");

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

pub fn main() anyerror!void {
    std.debug.warn("All your base are belong to us.\n", .{});

    const mem = try std.heap.page_allocator.alloc(u8, 2 * GiB);
    defer std.heap.page_allocator.free(mem);

    var primary_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(mem);

    var easyfb_instance = try easyfb.EasyFBInstance.init(&primary_allocator.allocator, "EasyFB");

    const image_width = 1600;
    const image_height = 900;

    const image = try primary_allocator.allocator.alloc(Pixel, image_width * image_height);

    for (image) |pixel, i| {
        const x = i % image_width;
        const y = @divFloor(i, image_width);
        pixel = Pixel{
            .r = 0,
            .g = @intCast(u8, x % (std.math.maxInt(u8) + 1)),
            .b = @intCast(u8, y % (std.math.maxInt(u8) + 1)),
            .a = 255,
        };
    }

    try easyfb_instance.renderRGBAImageSync(@sliceToBytes(image), image_width, image_height, "raytraced image");
}
