const std = @import("std");
const Prng = std.Random.DefaultPrng;

pub var prng = Prng.init(0);

pub const Vec3 = struct {
    data: [3]f32,

    // Investigate the @Vector type, might make some of this easier!
    pub fn init(d0: f32, d1: f32, d2: f32) @This() {
        return .{
            .data = .{ d0, d1, d2 },
        };
    }

    pub fn zero() @This() {
        return .{
            .data = @splat(0),
        };
    }

    pub fn splat(v: f32) @This() {
        return .{
            .data = @splat(v),
        };
    }

    pub fn x(self: @This()) f32 {
        return self.data[0];
    }

    pub fn y(self: @This()) f32 {
        return self.data[1];
    }

    pub fn z(self: @This()) f32 {
        return self.data[2];
    }

    pub fn r(self: @This()) f32 {
        return self.data[0];
    }

    pub fn g(self: @This()) f32 {
        return self.data[1];
    }

    pub fn b(self: @This()) f32 {
        return self.data[2];
    }

    pub fn add(lhs: @This(), rhs: @This()) @This() {
        return .{ .data = .{
            lhs.data[0] + rhs.data[0],
            lhs.data[1] + rhs.data[1],
            lhs.data[2] + rhs.data[2],
        } };
    }

    pub fn subtract(lhs: @This(), rhs: @This()) @This() {
        return .{ .data = .{
            lhs.data[0] - rhs.data[0],
            lhs.data[1] - rhs.data[1],
            lhs.data[2] - rhs.data[2],
        } };
    }

    pub fn multiply(lhs: @This(), rhs: @This()) @This() {
        return .{ .data = .{
            lhs.data[0] * rhs.data[0],
            lhs.data[1] * rhs.data[1],
            lhs.data[2] * rhs.data[2],
        } };
    }

    pub fn multiply_scalar(lhs: @This(), rhs: f32) @This() {
        return .{ .data = .{
            lhs.data[0] * rhs,
            lhs.data[1] * rhs,
            lhs.data[2] * rhs,
        } };
    }

    pub fn divide(lhs: @This(), rhs: @This()) @This() {
        return .{ .data = .{
            lhs.data[0] / rhs.data[0],
            lhs.data[1] / rhs.data[1],
            lhs.data[2] / rhs.data[2],
        } };
    }

    pub fn divide_scalar(lhs: @This(), rhs: f32) @This() {
        return .{ .data = .{
            lhs.data[0] / rhs,
            lhs.data[1] / rhs,
            lhs.data[2] / rhs,
        } };
    }

    pub fn length(self: @This()) f32 {
        return @sqrt(self.data[0] * self.data[0] + self.data[1] * self.data[1] + self.data[2] * self.data[2]);
    }

    pub fn length_squared(self: @This()) f32 {
        return self.data[0] * self.data[0] + self.data[1] * self.data[1] + self.data[2] * self.data[2];
    }

    pub fn normalize(self: *@This()) void {
        const k = 1.0 / self.length();
        self.data[0] *= k;
        self.data[1] *= k;
        self.data[2] *= k;
    }

    pub fn normalized(self: @This()) @This() {
        const k = 1.0 / self.length();
        return multiply_scalar(self, k);
    }

    pub fn dot(lhs: @This(), rhs: @This()) f32 {
        return lhs.data[0] * rhs.data[0] + lhs.data[1] * rhs.data[1] + lhs.data[2] * rhs.data[2];
    }

    pub fn cross(lhs: @This(), rhs: @This()) @This() {
        return .{ .data = .{
            lhs.data[1] * rhs.data[2] - lhs.data[2] * rhs.data[1],
            -(lhs.data[0] * rhs.data[2] - lhs.data[2] * rhs.data[0]),
            lhs.data[0] * rhs.data[1] - lhs.data[1] * rhs.data[0],
        } };
    }

    pub fn random_in_unit_sphere() Vec3 {
        var random_vec = Vec3.init(
            prng.random().float(f32) * 2.0 - 1.0,
            prng.random().float(f32) * 2.0 - 1.0,
            prng.random().float(f32) * 2.0 - 1.0,
        );

        while (random_vec.length_squared() > 1) {
            random_vec = Vec3.init(
                prng.random().float(f32) * 2.0 - 1.0,
                prng.random().float(f32) * 2.0 - 1.0,
                prng.random().float(f32) * 2.0 - 1.0,
            );
        }

        return random_vec;
    }

    pub fn reflect(v: @This(), n: @This()) @This() {
        return Vec3.subtract(
            v,
            Vec3.multiply_scalar(
                n,
                2.0 * Vec3.dot(v, n),
            ),
        );
    }
};

pub const Ray = struct {
    a: Vec3,
    b: Vec3,

    pub fn init(A: Vec3, B: Vec3) @This() {
        return .{
            .a = A,
            .b = B,
        };
    }

    pub fn origin(self: @This()) Vec3 {
        return self.a;
    }

    pub fn direction(self: @This()) Vec3 {
        return self.b;
    }

    pub fn evaluate(self: @This(), t: f32) Vec3 {
        return Vec3.add(self.a, Vec3.multiply_scalar(self.b, t));
    }
};
