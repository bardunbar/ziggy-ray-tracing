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

pub fn main(init: std.process.Init) void {
    const io = init.io;

    const screen_width = 1024;
    const screen_height = screen_width / 2;
    const sample_count = 10;

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

    var cache_y: usize = 0;
    var cache_x: usize = 0;

    const screenTexture = rl.loadTextureFromImage(screenImage) catch {
        return;
    };
    defer rl.unloadTexture(screenTexture);

    rl.traceLog(rl.TraceLogLevel.info, "Starting Raytrace", .{});
    var render_done = false;
    //const render_start = std.Io.Clock.awake.now(io);

    while (!rl.windowShouldClose()) {
        if (!render_done) {
            const frame_start = std.Io.Clock.awake.now(io);
            var timeslice_elapsed = false;
            // Update the texture a bit each frame based on the desired frame rate
            for (cache_y..screen_height) |y| {
                for (cache_x..screen_width) |x| {
                    const frame_current = std.Io.Clock.awake.now(io);
                    const elapsed = frame_start.durationTo(frame_current);
                    timeslice_elapsed = elapsed.toMicroseconds() > 100000;
                    if (timeslice_elapsed) {
                        break;
                    }

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

                    cache_x = x + 1;
                }

                if (timeslice_elapsed) {
                    break;
                }

                cache_y = y + 1;
                cache_x = 0;
            }

            rl.updateTexture(screenTexture, screenImage.data);

            if (!timeslice_elapsed) {
                render_done = true;
                //const render_done_timestamp = std.Io.Clock.awake.now(io);
                //const render_duration = render_start.durationTo(render_done_timestamp);
            }
        }

        {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.black);
            //rl.drawText("Ziggy Ray Tracing!", 300, 200, 40, rl.Color.green);
            rl.drawTexture(screenTexture, 0, 0, rl.Color.white);
        }
    }
}
