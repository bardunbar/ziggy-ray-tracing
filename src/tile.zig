const std = @import("std");
const Mutex = std.Io.Mutex;

const rl = @import("raylib");

pub const Tile = struct {
    mutex: Mutex = Mutex.init,
    image: rl.Image,
    dimension: usize,
    x: usize,
    y: usize,

    pub fn init(x_pos: usize, y_pos: usize, size: usize) @This() {
        return .{
            .image = rl.genImageColor(@intCast(size), @intCast(size), rl.Color.black),
            .dimension = size,
            .x = x_pos,
            .y = y_pos,
        };
    }

    pub fn deinit(self: @This()) void {
        rl.unloadImage(self.image);
    }

    pub fn rect(self: @This()) rl.Rectangle {
        const fx = @as(f32, @floatFromInt(self.x * self.dimension));
        const fy = @as(f32, @floatFromInt(self.y * self.dimension));
        const f_width = @as(f32, @floatFromInt(self.dimension));
        const f_height = f_width;

        return .init(fx, fy, f_width, f_height);
    }
};

pub const TileSet = struct {
    tiles: std.ArrayList(Tile),
    gpa: std.mem.Allocator,

    pub fn init(w: usize, h: usize, dimension: usize, allocator: std.mem.Allocator) !@This() {
        const tile_count = w * h;
        var t = try std.ArrayList(Tile).initCapacity(allocator, tile_count);

        for (0..tile_count) |i| {
            const tile_h = i % w;
            const tile_v = i / w;

            try t.append(allocator, Tile.init(tile_h, tile_v, dimension));
        }

        return .{
            .tiles = t,
            .gpa = allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.tiles.items) |tile| {
            tile.deinit();
        }

        self.tiles.deinit(self.gpa);
    }
};
