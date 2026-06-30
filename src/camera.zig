const math = @import("math.zig");
const Vec3 = math.Vec3;
const Ray = math.Ray;

pub const Camera = struct {
    origin: Vec3,
    upper_left_corner: Vec3,
    horizontal: Vec3,
    vertical: Vec3,

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
