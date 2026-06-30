const std = @import("std");
const math = @import("math.zig");

const Vec3 = math.Vec3;
const Ray = math.Ray;

pub const HitRecord = struct {
    t: f32,
    p: Vec3,
    normal: Vec3,

    pub fn init() @This() {
        return .{
            .t = 0.0,
            .p = Vec3.zero(),
            .normal = Vec3.zero(),
        };
    }
};

pub const Sphere = struct {
    center: Vec3,
    radius: f32,

    pub fn init(cen: Vec3, r: f32) @This() {
        return .{
            .center = cen,
            .radius = r,
        };
    }

    pub fn hit(self: @This(), ray: Ray, t_min: f32, t_max: f32, record: *HitRecord) bool {
        const oc = Vec3.subtract(ray.origin(), self.center);
        const a = Vec3.dot(ray.direction(), ray.direction());
        const b = Vec3.dot(oc, ray.direction());
        const c = Vec3.dot(oc, oc) - self.radius * self.radius;
        const discriminant = b * b - a * c;

        if (discriminant > 0) {
            var temp = (-b - @sqrt(b * b - a * c)) / a;
            if (temp < t_max and temp > t_min) {
                record.t = temp;
                record.p = ray.evaluate(record.t);
                record.normal = Vec3.divide_scalar(Vec3.subtract(record.p, self.center), self.radius);
                return true;
            }

            temp = (-b + @sqrt(b * b - a * c)) / a;
            if (temp < t_max and temp > t_min) {
                record.t = temp;
                record.p = ray.evaluate(record.t);
                record.normal = Vec3.divide_scalar(Vec3.subtract(record.p, self.center), self.radius);
                return true;
            }
        }

        return false;
    }
};

const MAX_OBJECT_COUNT: usize = 128;

pub const World = struct {
    spheres: [MAX_OBJECT_COUNT]Sphere,
    sphere_count: usize,

    pub fn init() @This() {
        return .{
            .spheres = comptime std.mem.zeroes([MAX_OBJECT_COUNT]Sphere),
            .sphere_count = 0,
        };
    }

    pub fn trace(self: @This(), ray: Ray, record: *HitRecord) bool {
        const t_max = std.math.floatMax(f32);
        var hit_anything = false;
        var closest = t_max;

        for (0..self.sphere_count) |i| {
            if (self.spheres[i].hit(ray, 0.0, closest, record)) {
                hit_anything = true;
                closest = record.t;
            }
        }

        return hit_anything;
    }

    pub fn add_sphere(self: *@This(), sphere: Sphere) void {
        self.spheres[self.sphere_count] = sphere;
        self.sphere_count += 1;
    }
};
