const std = @import("std");
const rmath = @import("rmath/rmath.zig");
const easyfb = @import("easyfb/easyfb.zig");
const raytracer = @import("raytracer/raytracer.zig");

pub const KiB = 1024;
pub const MiB = 1024 * KiB;
pub const GiB = 1024 * MiB;

const ThreadContext = struct {
    id: usize,
    world: *raytracer.World,
    random: *std.rand.Random,
    work_queue: *WorkQueue(raytracer.Tile),
    image: *raytracer.ImageRGBAU8,
    camera: raytracer.Camera,
    sample_count: usize,
};

fn WorkQueue(comptime T: type) type {
    return struct {
        work: []const T,
        claimed: usize = 0,
        retired: usize = 0,
        pub fn init(work: []const T) @This() {
            return .{ .work = work };
        }

        const WorkQueueEntry = struct {
            entry: T,
            idx: usize,
        };

        pub fn claimWorkQueueEntry(self: *@This()) ?WorkQueueEntry {
            while (true) {
                const idx = @atomicLoad(usize, &self.claimed, .SeqCst);
                if (idx >= self.work.len) {
                    return null;
                }
                // TODO: swap version?
                if (@cmpxchgWeak(usize, &self.claimed, idx, idx + 1, .SeqCst, .SeqCst) == null) {
                    return WorkQueueEntry{ .entry = self.work[idx], .idx = idx };
                }
            }
        }
        pub fn retireWorkQueueEntry(self: *@This(), wqe: *const WorkQueueEntry) void {
            _ = @atomicRmw(
                usize,
                &self.retired,
                .Add,
                1,
                .AcqRel,
            );
        }

        pub fn isWorkComplete(self: *This()) bool {
            return @atomicLoad(usize, &self.retired, .Acquire) == self.retired;
        }
    };
}

fn threadFn(thread_context: *ThreadContext) void {
    while (thread_context.work_queue.claimWorkQueueEntry()) |work| {
        thread_context.world.raytraceTile(
            thread_context.random,
            work.entry,
            thread_context.camera,
            thread_context.image,
            thread_context.sample_count,
        );
        thread_context.work_queue.retireWorkQueueEntry(&work);
    }
}

pub fn main() anyerror!void {
    const raytracer_mem = try std.heap.page_allocator.alloc(u8, 512 * MiB);
    defer std.heap.page_allocator.free(raytracer_mem);

    const os_mem = try std.heap.page_allocator.alloc(u8, 1 * MiB);
    defer std.heap.page_allocator.free(os_mem);

    var primary_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(raytracer_mem);
    var os_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(os_mem);

    var easyfb_instance = try easyfb.EasyFBInstance.init(&os_allocator.allocator, "EasyFB");

    const image_width = 1280;
    const image_height = 720;
    const spheres = [_]raytracer.Sphere{
        raytracer.Sphere{
            .center = rmath.Vec(f32, 3){ .e = [_]f32{ 0, 0, -1 } },
            .radius = 0.5,
            .mat = 0,
        },
        raytracer.Sphere{
            .center = rmath.Vec(f32, 3){ .e = [_]f32{ -1, 1, -2 } },
            .radius = 0.5,
            .mat = 5,
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
            .distance_from_origin = 0,
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
    const camera_pos = rmath.Vec3F32{ .e = [3]f32{ 3, 1, 4 } };
    const camera_targ = rmath.Vec3F32{ .e = [3]f32{ 0, 0, -1 } };
    const camera_up = rmath.Vec3F32{ .e = [3]f32{ 0, 1, 0 } };
    const aspect = @intToFloat(f32, image_width) / @intToFloat(f32, image_height);

    var timer = try std.time.Timer.start();
    const cpu_count = std.Thread.cpuCount() catch |err| 1;

    var image = try raytracer.ImageRGBAU8.init(
        &primary_allocator.allocator,
        image_width,
        image_height,
    );
    defer image.deinit();

    const tiles = try image.divideIntoTiles(&primary_allocator.allocator, cpu_count * 3);
    defer primary_allocator.allocator.free(tiles);

    const camera = raytracer.Camera.init(camera_pos, camera_targ, camera_up, 60, aspect);
    var work_queue = WorkQueue(raytracer.Tile).init(tiles);

    const thread_contexts = try primary_allocator.allocator.alloc(ThreadContext, cpu_count);
    for (thread_contexts) |thread_context, i| {
        thread_context = .{
            .world = &world,
            .random = &rand.random,
            .work_queue = &work_queue,
            .image = &image,
            .camera = camera,
            .sample_count = 16,
            .id = i,
        };
    }
    defer primary_allocator.allocator.free(thread_contexts);

    const threads = try primary_allocator.allocator.alloc(*std.Thread, cpu_count);
    for (threads) |*thread, i| {
        thread.* = try std.Thread.spawn(&thread_contexts[i], threadFn);
    }
    defer primary_allocator.allocator.free(threads);
    for (threads) |thread| {
        thread.wait();
    }

    const time_ns = timer.read();
    std.debug.warn("{} ns, {d:.3}s, {} bounces, approx {} ns per bounce\n", .{
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
