const rl = @import("raylib");
const math = @import("math.zig");

const Vec3 = math.Vec3;
const Ray = math.Ray;

fn hit_sphere(center: Vec3, radius: f32, r: Ray) bool {
    const oc = Vec3.subtract(r.origin(), center);
    const a = Vec3.dot(r.direction(), r.direction());
    const b = 2.0 * Vec3.dot(oc, r.direction());
    const c = Vec3.dot(oc, oc) - radius * radius;
    const discriminant = b * b - 4 * a * c;

    return discriminant > 0;
}

fn color(r: Ray) Vec3 {
    if (hit_sphere(Vec3.init(0.0, 0.0, -1.0), 0.5, r)) {
        return Vec3.init(1.0, 0.0, 0.0);
    }
    const normalized = r.direction().normalized();
    const t: f32 = 0.5 * (normalized.y() + 1.0);
    return Vec3.add(
        Vec3.multiply_scalar(Vec3.splat(1.0), (1.0 - t)),
        Vec3.multiply_scalar(Vec3.init(0.5, 0.7, 1.0), t),
    );
}

pub fn main() void {
    const screen_width = 1200;
    const screen_height = 600;

    rl.initWindow(screen_width, screen_height, "Ziggy Ray Tracing!");
    defer rl.closeWindow();

    var screenImage = rl.genImageColor(screen_width, screen_width, rl.Color.black);
    defer rl.unloadImage(screenImage);

    const upper_left_corner = Vec3.init(-2.0, 1.0, -1.0);
    const horizontal = Vec3.init(4.0, 0.0, 0.0);
    const vertical = Vec3.init(0.0, -2.0, 0.0);
    const origin = Vec3.splat(0.0);

    // Initialize the screen image for testing
    for (0..screen_height) |y| {
        for (0..screen_width) |x| {
            const u = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(screen_width));
            const v = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(screen_height));

            const ray = Ray.init(
                origin,
                Vec3.add(
                    upper_left_corner,
                    Vec3.add(
                        Vec3.multiply_scalar(horizontal, u),
                        Vec3.multiply_scalar(vertical, v),
                    ),
                ),
            );

            const col = color(ray);

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
