const std = @import("std");

const math = @import("math.zig");
const Vec3 = math.Vec3;
const Ray = math.Ray;

pub const Camera = struct {
    origin: Vec3,
    upper_left_corner: Vec3,
    horizontal: Vec3,
    vertical: Vec3,

    pub fn init(look_from: Vec3, look_at: Vec3, up: Vec3, v_fov: f32, aspect: f32) @This() {
        const theta = v_fov * std.math.pi / 180.0;
        const half_height = std.math.tan(theta / 2.0);
        const half_width = aspect * half_height;

        const w = Vec3.subtract(look_from, look_at).normalized();
        const u = Vec3.cross(up, w).normalized();
        const v = Vec3.cross(w, u);

        const horizontal_offset = Vec3.multiply_scalar(u, -half_width);
        const vertical_offset = Vec3.multiply_scalar(v, half_height);
        const corner = Vec3.add(
            look_from,
            Vec3.add(
                horizontal_offset,
                Vec3.subtract(vertical_offset, w),
            ),
        );

        return .{
            .origin = look_from,
            .upper_left_corner = corner,
            .horizontal = Vec3.multiply_scalar(u, 2.0 * half_width),
            .vertical = Vec3.multiply_scalar(v, -2.0 * half_height),
        };
    }

    pub fn get_ray(self: @This(), u: f32, v: f32) Ray {
        const horizontal_comp = Vec3.multiply_scalar(self.horizontal, u);
        const vertical_comp = Vec3.multiply_scalar(self.vertical, v);
        const direction = Vec3.subtract(
            Vec3.add(
                Vec3.add(
                    horizontal_comp,
                    vertical_comp,
                ),
                self.upper_left_corner,
            ),
            self.origin,
        );

        return Ray.init(self.origin, direction);
    }
};
