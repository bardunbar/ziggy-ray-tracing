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

const tile = @import("tile.zig");

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

fn color(r: Ray, world: *const World, depth: u8) Vec3 {
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

const tile_dim = 96;
const desired_screen_width = tile_dim * 12; //1024;
const desired_screen_height = tile_dim * 8; //512;
const sample_count = 10;

const screen_tile_width = desired_screen_width / tile_dim;
const screen_tile_height = desired_screen_height / tile_dim;
const screen_width = screen_tile_width * tile_dim;
const screen_height = screen_tile_height * tile_dim;

const screen_width_float = @as(f32, @floatFromInt(screen_width));
const screen_height_float = @as(f32, @floatFromInt(screen_height));

const RenderJob = struct {
    tile: *tile.Tile,
    rect: rl.Rectangle,
    io: std.Io,
    camera: *const Camera,
    world: *const World,
    prng: std.Random.DefaultPrng,
    previous_samples: usize,
    current_samples: usize,

    pub fn render(self: *@This()) void {
        const sx = @as(usize, @intFromFloat(self.rect.x));
        const sy = @as(usize, @intFromFloat(self.rect.y));
        const ex = sx + @as(usize, @intFromFloat(self.rect.width));
        const ey = sy + @as(usize, @intFromFloat(self.rect.height));

        for (sy..ey) |y| {
            const iy = y - sy;

            for (sx..ex) |x| {
                const ix = x - sx;

                var col = Vec3.splat(0);
                for (0..self.current_samples) |_| {
                    const u = (@as(f32, @floatFromInt(x)) + self.prng.random().float(f32)) / screen_width_float;
                    const v = (@as(f32, @floatFromInt(y)) + self.prng.random().float(f32)) / screen_height_float;
                    const ray = self.camera.get_ray(u, v);
                    col = Vec3.add(col, color(ray, self.world, 0));
                }

                col = Vec3.divide_scalar(col, @as(f32, @floatFromInt(self.current_samples)));
                // Do gamma correction
                col = Vec3.init(@sqrt(col.r()), @sqrt(col.g()), @sqrt(col.b()));

                const r = @as(u8, @trunc(col.r() * 255.99));
                const g = @as(u8, @trunc(col.g() * 255.99));
                const b = @as(u8, @trunc(col.b() * 255.99));

                self.tile.mutex.lock(self.io) catch {
                    return;
                };
                defer self.tile.mutex.unlock(self.io);

                var image_color = rl.getImageColor(self.tile.image, @intCast(ix), @intCast(iy));

                if (self.previous_samples > 0) {
                    const total_samples = @as(f32, @floatFromInt(self.previous_samples + self.current_samples));
                    const ratio_current = @as(f32, @floatFromInt(self.current_samples)) / total_samples;
                    const ratio_previous = @as(f32, @floatFromInt(self.previous_samples)) / total_samples;
                    image_color.r = @as(u8, @trunc(@as(f32, @floatFromInt(r)) * ratio_current)) + @as(u8, @trunc(@as(f32, @floatFromInt(image_color.r)) * ratio_previous));
                    image_color.g = @as(u8, @trunc(@as(f32, @floatFromInt(g)) * ratio_current)) + @as(u8, @trunc(@as(f32, @floatFromInt(image_color.g)) * ratio_previous));
                    image_color.b = @as(u8, @trunc(@as(f32, @floatFromInt(b)) * ratio_current)) + @as(u8, @trunc(@as(f32, @floatFromInt(image_color.b)) * ratio_previous));
                } else {
                    image_color.r = r;
                    image_color.g = g;
                    image_color.b = b;
                    image_color.a = 255;
                }

                rl.imageDrawPixel(
                    &self.tile.image,
                    @intCast(ix),
                    @intCast(iy),
                    image_color,
                );
            }
        }
    }
};

fn worker(queue: *std.ArrayList(RenderJob), mutex: *std.Io.Mutex, remaining_work: *std.atomic.Value(usize), io: std.Io) !void {
    try mutex.lock(io);
    var job = queue.pop();
    mutex.unlock(io);

    while (job) |*work| {
        work.render();

        try mutex.lock(io);
        defer mutex.unlock(io);
        job = queue.pop();
    }

    const current_work = remaining_work.load(std.builtin.AtomicOrder.acquire);
    remaining_work.store(current_work - 1, std.builtin.AtomicOrder.release);
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    var prng = std.Random.DefaultPrng.init(0);

    rl.setConfigFlags(.{
        .window_resizable = true,
    });
    rl.initWindow(screen_width, screen_height, "Ziggy Ray Tracing!");
    defer rl.closeWindow();

    const screenImage = rl.genImageColor(screen_width, screen_width, rl.Color.black);
    defer rl.unloadImage(screenImage);

    std.debug.print("Desired Screen Size: {} x {}\n", .{ desired_screen_width, desired_screen_height });
    std.debug.print("Actual Screen Size: {} x {}\n", .{ screen_width, screen_height });
    std.debug.print("Tile size: {}\nTile Map Dimensions: {} x {}\n", .{ tile_dim, screen_tile_width, screen_tile_height });

    var tiles = try tile.TileSet.init(screen_tile_width, screen_tile_height, tile_dim, gpa);
    defer tiles.deinit();

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

    var render_queue_mutex = std.Io.Mutex.init;
    var render_queue = try std.ArrayList(RenderJob).initCapacity(gpa, tiles.tiles.items.len);
    defer render_queue.deinit(gpa);

    const iterations = 13;
    var total = std.math.shl(usize, 1, iterations) - 1;

    std.debug.print("Total Samples: {}\n", .{total});
    for (0..iterations) |iteration| {
        const current_shift = (iterations - iteration - 1);
        const current_samples = std.math.shl(usize, 1, current_shift);
        const previous_samples = total - current_samples;

        std.debug.print("Iteration {}: current samples ({}), previous samples({})\n", .{ current_shift, current_samples, previous_samples });
        for (0..tiles.tiles.items.len) |i| {
            const cur = &tiles.tiles.items[i];
            try render_queue.append(gpa, RenderJob{
                .tile = cur,
                .rect = cur.rect(),
                .io = io,
                .camera = &cam,
                .world = &world,
                .prng = std.Random.DefaultPrng.init(prng.random().int(u64)),
                .previous_samples = previous_samples,
                .current_samples = current_samples,
            });
        }

        total = previous_samples;
    }

    const available_cores = (std.Thread.getCpuCount() catch 2) - 1;
    var active_render_cores = std.atomic.Value(usize).init(0);

    for (0..available_cores) |_| {
        const current_active = active_render_cores.load(std.builtin.AtomicOrder.acquire);
        active_render_cores.store(current_active + 1, std.builtin.AtomicOrder.release);

        const job = try std.Thread.spawn(
            .{ .allocator = gpa, .stack_size = 1024 },
            worker,
            .{ &render_queue, &render_queue_mutex, &active_render_cores, io },
        );

        job.detach();
    }

    const screenTexture = rl.loadTextureFromImage(screenImage) catch {
        return;
    };
    defer rl.unloadTexture(screenTexture);

    rl.traceLog(rl.TraceLogLevel.info, "Starting Raytrace", .{});
    var render_done = false;
    const render_start = std.Io.Clock.awake.now(io);

    while (!rl.windowShouldClose()) {
        if (!render_done) {
            // Update tile data
            for (tiles.tiles.items) |*cur| {
                try cur.mutex.lock(io);
                defer cur.mutex.unlock(io);

                rl.updateTextureRec(screenTexture, cur.rect(), cur.image.data);
            }

            const active_jobs = active_render_cores.load(std.builtin.AtomicOrder.acquire);
            if (active_jobs == 0) {
                render_done = true;
                const render_timestamp = std.Io.Clock.awake.now(io);
                const render_time = render_start.durationTo(render_timestamp);

                std.debug.print("Render Complete in: {f}\n", .{render_time});

                var result_image = try rl.loadImageFromTexture(screenTexture);
                defer rl.unloadImage(result_image);

                rl.imageCrop(&result_image, rl.Rectangle.init(0.0, 0.0, screen_width_float, screen_height_float));
                _ = rl.exportImage(result_image, "result.png");
            }

            // Sleep to let the threads work
            try std.Io.sleep(io, .fromMilliseconds(100), .awake);
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
