const math = @import("math.zig");
const Vec3 = math.Vec3;
const Ray = math.Ray;

const tracing = @import("tracing.zig");
const HitRecord = tracing.HitRecord;

const MaterialTag = enum {
    lambertian,
    metal,

    empty,
};

pub const Material = union(MaterialTag) {
    lambertian: Lambertian,
    metal: Metal,

    empty: void,

    pub fn scatter(self: @This(), ray: Ray, record: HitRecord, attenuation: *Vec3, scattered: *Ray) bool {
        return switch (self) {
            MaterialTag.lambertian => |lambertian| {
                return lambertian.scatter_lambertian(record, attenuation, scattered);
            },
            MaterialTag.metal => |metal| {
                return metal.scatter_metal(ray, record, attenuation, scattered);
            },
            MaterialTag.empty => return false,
        };
    }

    pub fn init_empty() @This() {
        return .{ .empty = undefined };
    }
};

const Lambertian = struct {
    albedo: Vec3,

    fn scatter_lambertian(self: @This(), record: HitRecord, attenuation: *Vec3, scattered: *Ray) bool {
        const target = Vec3.add(Vec3.add(record.p, record.normal), Vec3.random_in_unit_sphere());
        scattered.* = Ray.init(record.p, Vec3.subtract(target, record.p));
        attenuation.* = self.albedo;
        return true;
    }
};

const Metal = struct {
    albedo: Vec3,
    fuzz: f32,

    fn scatter_metal(self: @This(), ray: Ray, record: HitRecord, attenuation: *Vec3, scattered: *Ray) bool {
        const reflected = Vec3.reflect(ray.direction().normalized(), record.normal);
        const fuzzing = Vec3.multiply_scalar(Vec3.random_in_unit_sphere(), self.fuzz);
        scattered.* = Ray.init(record.p, Vec3.add(reflected, fuzzing));
        attenuation.* = self.albedo;
        return Vec3.dot(scattered.direction(), record.normal) > 0.0;
    }
};
