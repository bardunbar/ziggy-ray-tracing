const rl = @import("raylib");

pub fn main() void {
    const screen_width = 800;
    const screen_height = 600;

    rl.initWindow(screen_width, screen_height, "Ziggy Ray Tracing!");
    defer rl.closeWindow();

    var screenImage = rl.genImageColor(screen_width, screen_width, rl.Color.black);
    defer rl.unloadImage(screenImage);

    // Initialize the screen image for testing
    for (0..screen_height) |y| {
        for (0..screen_width) |x| {
            const normalized_x = @as(f64, @floatFromInt(x)) / @as(f64, @floatFromInt(screen_width));
            const normalized_y = @as(f64, @floatFromInt(y)) / @as(f64, @floatFromInt(screen_height));
            const r = @as(u8, @trunc(normalized_x * 255.99));
            const g = @as(u8, @trunc(normalized_y * 255.99));

            rl.imageDrawPixel(&screenImage, @intCast(x), @intCast(y), rl.Color.init(r, g, 50, 255));
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
