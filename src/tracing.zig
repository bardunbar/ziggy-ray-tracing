const std = @import("std");
const material = @import("material.zig");
const Material = material.Material;

const math = @import("math.zig");
const Vec3 = math.Vec3;
const Ray = math.Ray;

pub const HitRecord = struct {
    t: f32,
    p: Vec3,
    normal: Vec3,
    material: Material,

    pub fn init() @This() {
        return .{
            .t = 0.0,
            .p = Vec3.zero(),
            .normal = Vec3.zero(),
            .material = Material.init_empty(),
        };
    }
};

pub const Sphere = struct {
    center: Vec3,
    radius: f32,
    material: Material,

    pub fn init(cen: Vec3, r: f32, mat: Material) @This() {
        return .{
            .center = cen,
            .radius = r,
            .material = mat,
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
                record.material = self.material;
                return true;
            }

            temp = (-b + @sqrt(b * b - a * c)) / a;
            if (temp < t_max and temp > t_min) {
                record.t = temp;
                record.p = ray.evaluate(record.t);
                record.normal = Vec3.divide_scalar(Vec3.subtract(record.p, self.center), self.radius);
                record.material = self.material;
                return true;
            }
        }

        return false;
    }
};

const MAX_OBJECT_COUNT: usize = 512;

fn random_f32() f32 {
    return math.prng.random().float(f32);
}

pub const World = struct {
    spheres: [MAX_OBJECT_COUNT]Sphere,
    sphere_count: usize,

    pub fn init() @This() {
        return .{
            .spheres = [_]Sphere{
                .{
                    .center = Vec3.zero(),
                    .radius = 0.0,
                    .material = .{
                        .lambertian = .{ .albedo = Vec3.zero() },
                    },
                },
            } ** MAX_OBJECT_COUNT,
            .sphere_count = 0,
        };
    }

    pub fn initialize_cover_scene(self: *@This()) void {
        self.add_sphere(.{
            .center = Vec3.init(0, -1000, 0),
            .radius = 1000,
            .material = .{
                .lambertian = .{ .albedo = Vec3.init(0.5, 0.5, 0.5) },
            },
        });

        self.add_sphere(.{
            .center = Vec3.init(0.0, 1.0, 0.0),
            .radius = 1.0,
            .material = .{ .dielectric = .{ .refractive_index = 1.5 } },
        });

        self.add_sphere(.{
            .center = Vec3.init(-4.0, 1.0, 0.0),
            .radius = 1.0,
            .material = .{
                .lambertian = .{ .albedo = Vec3.init(0.4, 0.2, 0.1) },
            },
        });

        self.add_sphere(.{
            .center = Vec3.init(4.0, 1.0, 0.0),
            .radius = 1.0,
            .material = .{
                .metal = .{ .albedo = Vec3.init(0.7, 0.6, 0.5), .fuzz = 0.0 },
            },
        });

        for (0..22) |a| {
            for (0..22) |b| {
                const select_material = random_f32();
                const center = Vec3.init(
                    @as(f32, @floatFromInt(a)) - 11 + 0.9 * random_f32(),
                    0.2,
                    @as(f32, @floatFromInt(b)) - 11 + 0.9 * random_f32(),
                );
                if (Vec3.subtract(center, Vec3.init(4, 0.2, 0)).length() > 0.9) {
                    if (select_material < 0.8) {
                        self.add_sphere(.{
                            .center = center,
                            .radius = 0.2,
                            .material = .{
                                .lambertian = .{
                                    .albedo = Vec3.init(
                                        random_f32() * random_f32(),
                                        random_f32() * random_f32(),
                                        random_f32() * random_f32(),
                                    ),
                                },
                            },
                        });
                    } else if (select_material < 0.94) {
                        self.add_sphere(.{
                            .center = center,
                            .radius = 0.2,
                            .material = .{
                                .metal = .{
                                    .albedo = Vec3.init(
                                        0.5 * (1 + random_f32()),
                                        0.5 * (1 + random_f32()),
                                        0.5 * (1 + random_f32()),
                                    ),
                                    .fuzz = 0.5 * random_f32(),
                                },
                            },
                        });
                    } else {
                        self.add_sphere(.{ .center = center, .radius = 0.2, .material = .{ .dielectric = .{
                            .refractive_index = 1.5,
                        } } });
                    }
                }
            }
        }
    }

    pub fn trace(self: @This(), ray: Ray, record: *HitRecord) bool {
        const t_max = comptime std.math.floatMax(f32);
        var hit_anything = false;
        var closest = t_max;

        for (0..self.sphere_count) |i| {
            if (self.spheres[i].hit(ray, 0.001, closest, record)) {
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
