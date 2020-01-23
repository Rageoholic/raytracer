const rmath = @import("../rmath/rmath.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const RGBAPixelU8 = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const ImageRGBAU8 = struct {
    width: u32,
    height: u32,
    pixels: []RGBAPixelU8,
    allocator: *Allocator,
    pub fn init(allocator: *Allocator, width: u32, height: u32) !@This() {
        const pixels = try allocator.alloc(RGBAPixelU8, width * height);
        return @This(){ .width = width, .height = height, .pixels = pixels, .allocator = allocator };
    }
    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.pixels);
    }
};

pub const Sphere = struct {
    center: rmath.Vec3F32,
    radius: f32,
    mat: usize,
    pub fn hit(self: @This(), ray: rmath.Ray3F32) ?SphereHitRecord {
        const sphere_relative_ray_pos = ray.pos.sub(self.center);
        const a = ray.dir.dot(ray.dir);
        const b = 2 * sphere_relative_ray_pos.dot(ray.dir);
        const c = sphere_relative_ray_pos.dot(sphere_relative_ray_pos) - self.radius * self.radius;

        const discriminant = b * b - 4 * a * c;
        if (discriminant < 0) {
            return null;
        } else {
            const pos = (-b + std.math.sqrt(discriminant)) / (2 * a);
            const neg = (-b - std.math.sqrt(discriminant)) / (2 * a);
            return SphereHitRecord{ .pos = pos, .neg = neg };
        }
    }
};

const SphereHitRecord = struct {
    neg: f32,
    pos: f32,
};

pub const Material = union(enum) {
    Default: struct {
        ref: rmath.Vec3F32,
        emit: rmath.Vec3F32,
        specular: f32,
    },
};

pub const Plane = struct {
    norm: rmath.Vec3F32,
    distance_from_origin: f32,
    mat: usize,

    pub fn hit(self: @This(), ray: rmath.Ray3F32) ?PlaneHitRecord {
        const denom = self.norm.dot(ray.dir);
        if (std.math.absFloat(denom) > 0) {
            const distance = (self.distance_from_origin - self.norm.dot(ray.pos)) / denom;
            return PlaneHitRecord{ .distance = distance };
        } else {
            return null;
        }
    }
};

const PlaneHitRecord = struct {
    distance: f32,
};

pub const Camera = struct {
    camera_z: rmath.Vec3F32,
    camera_x: rmath.Vec3F32,
    camera_y: rmath.Vec3F32,
    pos: rmath.Vec3F32,

    lower_left_corner: rmath.Vec3F32,
    vertical: rmath.Vec3F32,
    horizontal: rmath.Vec3F32,

    pub fn init(
        pos: rmath.Vec3F32,
        targ: rmath.Vec3F32,
        up: rmath.Vec3F32,
        vfov: f32,
        aspect: f32,
    ) @This() {
        const theta = vfov / 180 * std.math.pi;
        const half_height = std.math.tan(theta / 2);
        const half_width = aspect * half_height;

        const camera_z = pos.sub(targ).normOrZero();
        const camera_x = up.cross(camera_z).normOrZero();
        const camera_y = camera_z.cross(camera_x);

        const lower_left_corner = pos.sub(camera_x.mul(half_width)).sub(camera_y.mul(half_height)).sub(camera_z);
        const horizontal = camera_x.mul(2 * half_width);
        const vertical = camera_y.mul(2 * half_height);

        return .{
            .camera_x = camera_x,
            .camera_y = camera_y,
            .camera_z = camera_z,
            .lower_left_corner = lower_left_corner,
            .horizontal = horizontal,
            .vertical = vertical,
            .pos = pos,
        };
    }

    pub fn ray(self: @This(), u: f32, v: f32) rmath.Ray3F32 {
        const dir = self.lower_left_corner.add(
            self.horizontal.mul(u),
        ).add(
            self.vertical.mul(v),
        ).sub(
            self.pos,
        );
        return rmath.Ray3F32.init(
            dir,
            self.pos,
        );
    }
};
