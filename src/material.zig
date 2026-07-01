const std = @import("std");
const pow = std.math.pow;

const math = @import("math.zig");
const Vec3 = math.Vec3;
const Ray = math.Ray;

const tracing = @import("tracing.zig");
const HitRecord = tracing.HitRecord;

const MaterialTag = enum {
    lambertian,
    metal,
    dielectric,

    empty,
};

pub const Material = union(MaterialTag) {
    lambertian: Lambertian,
    metal: Metal,
    dielectric: Dielectric,

    empty: void,

    pub fn scatter(self: @This(), ray: Ray, record: HitRecord, attenuation: *Vec3, scattered: *Ray) bool {
        return switch (self) {
            MaterialTag.lambertian => |lambertian| {
                return lambertian.scatter_lambertian(record, attenuation, scattered);
            },
            MaterialTag.metal => |metal| {
                return metal.scatter_metal(ray, record, attenuation, scattered);
            },
            MaterialTag.dielectric => |dielectric| {
                return dielectric.scatter_dielectric(ray, record, attenuation, scattered);
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

fn schlick(cosine: f32, refractive_index: f32) f32 {
    var r0 = (1 - refractive_index) / (1 + refractive_index);
    r0 = r0 * r0;
    return r0 + (1 - r0) * pow(f32, (1 - cosine), 5);
}

const Dielectric = struct {
    refractive_index: f32,

    fn scatter_dielectric(self: @This(), ray: Ray, record: HitRecord, attenuation: *Vec3, scattered: *Ray) bool {
        var outward_normal = Vec3.zero();
        var ni_over_nt: f32 = 0.0;

        attenuation.* = Vec3.init(1.0, 1.0, 1.0);
        var refracted = Vec3.zero();
        var reflect_prob: f32 = 0.0;
        var cosine: f32 = 0.0;

        if (Vec3.dot(ray.direction(), record.normal) > 0) {
            outward_normal = Vec3.multiply_scalar(record.normal, -1.0);
            ni_over_nt = self.refractive_index;
            cosine = self.refractive_index * Vec3.dot(ray.direction(), record.normal) / ray.direction().length();
        } else {
            outward_normal = record.normal;
            ni_over_nt = 1.0 / self.refractive_index;
            cosine = -Vec3.dot(ray.direction(), record.normal) / ray.direction().length();
        }

        if (Vec3.refract(ray.direction(), outward_normal, ni_over_nt, &refracted)) {
            reflect_prob = schlick(cosine, self.refractive_index);
            //scattered.* = Ray.init(record.p, refracted);
        } else {
            //scattered.* = Ray.init(record.p, reflected);
            reflect_prob = 1.0;
        }

        if (math.prng.random().float(f32) < reflect_prob) {
            const reflected = Vec3.reflect(ray.direction(), record.normal);
            scattered.* = Ray.init(record.p, reflected);
        } else {
            scattered.* = Ray.init(record.p, refracted);
        }

        return true;
    }
};
