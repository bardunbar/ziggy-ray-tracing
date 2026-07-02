const std = @import("std");
const rl = @import("raylib");

const math = @import("math.zig");
const Vec3 = math.Vec3;
const Ray = math.Ray;

const tracing = @import("tracing.zig");
const World = tracing.World;
const HitRecord = tracing.HitRecord;

const camera = @import("camera.zig");
const Camera = camera.Camera;

const material = @import("material.zig");
const Material = material.Material;

fn hit_sphere(center: Vec3, radius: f32, r: Ray) f32 {
    const oc = Vec3.subtract(r.origin(), center);
    const a = Vec3.dot(r.direction(), r.direction());
    const b = 2.0 * Vec3.dot(oc, r.direction());
    const c = Vec3.dot(oc, oc) - radius * radius;
    const discriminant = b * b - 4 * a * c;

    if (discriminant < 0) {
        return -1.0;
    } else {
        return (-b - @sqrt(discriminant)) / (2.0 * a);
    }
}

fn color(r: Ray, world: World, depth: u8) Vec3 {
    var record = HitRecord.init();

    if (world.trace(r, &record)) {
        var scattered: Ray = Ray.init(Vec3.zero(), Vec3.zero());
        var attenuation = Vec3.zero();

        if (depth < 50 and record.material.scatter(r, record, &attenuation, &scattered)) {
            return Vec3.multiply(attenuation, color(scattered, world, depth + 1));
        } else {
            return Vec3.zero();
        }
    } else {
        const normalized = r.direction().normalized();
        const t: f32 = 0.5 * (normalized.y() + 1.0);
        return Vec3.add(
            Vec3.multiply_scalar(Vec3.splat(1.0), (1.0 - t)),
            Vec3.multiply_scalar(Vec3.init(0.5, 0.7, 1.0), t),
        );
    }
}

pub fn main() void {
    const screen_width = 1024;
    const screen_height = screen_width / 2;
    const sample_count = 100;

    var prng = std.Random.DefaultPrng.init(0);

    rl.setConfigFlags(.{
        .window_resizable = true,
    });
    rl.initWindow(screen_width, screen_height, "Ziggy Ray Tracing!");
    defer rl.closeWindow();

    var screenImage = rl.genImageColor(screen_width, screen_width, rl.Color.black);
    defer rl.unloadImage(screenImage);

    var world = tracing.World.init();

    world.initialize_cover_scene();

    const look_from = Vec3.init(12.0, 2.0, 3.0);
    const look_at = Vec3.init(0.0, 0.5, 0.0);
    const dist_to_focus = Vec3.subtract(look_from, look_at).length();
    const aperture: f32 = 0.25;
    const up = Vec3.init(0.0, 1.0, 0.0);

    const cam = Camera.init(
        look_from,
        look_at,
        up,
        20.0,
        @as(f32, @floatFromInt(screen_width)) / @as(f32, @floatFromInt(screen_height)),
        aperture,
        dist_to_focus,
    );

    // Initialize the screen image for testing
    for (0..screen_height) |y| {
        for (0..screen_width) |x| {
            var col = Vec3.splat(0);
            for (0..sample_count) |_| {
                const u = (@as(f32, @floatFromInt(x)) + prng.random().float(f32)) / @as(f32, @floatFromInt(screen_width));
                const v = (@as(f32, @floatFromInt(y)) + prng.random().float(f32)) / @as(f32, @floatFromInt(screen_height));
                const ray = cam.get_ray(u, v);
                col = Vec3.add(col, color(ray, world, 0));
            }

            col = Vec3.divide_scalar(col, @as(f32, @floatFromInt(sample_count)));
            // Do gamma correction
            col = Vec3.init(@sqrt(col.r()), @sqrt(col.g()), @sqrt(col.b()));

            const r = @as(u8, @trunc(col.r() * 255.99));
            const g = @as(u8, @trunc(col.g() * 255.99));
            const b = @as(u8, @trunc(col.b() * 255.99));

            rl.imageDrawPixel(
                &screenImage,
                @intCast(x),
                @intCast(y),
                rl.Color.init(r, g, b, 255),
            );
        }
    }

    const screenTexture = rl.loadTextureFromImage(screenImage) catch {
        return;
    };
    defer rl.unloadTexture(screenTexture);

    while (!rl.windowShouldClose()) {
        {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.black);
            //rl.drawText("Ziggy Ray Tracing!", 300, 200, 40, rl.Color.green);
            rl.drawTexture(screenTexture, 0, 0, rl.Color.white);
        }
    }
}
