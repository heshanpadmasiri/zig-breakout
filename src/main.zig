const rl = @import("raylib");

// FIXME: try to use a packed struct and treat all objects as same
// -- this will require Vecs to be pointers
const Player = struct { position: rl.Vector2, speed: rl.Vector2, size: rl.Vector2 };
const Ball = struct { position: rl.Vector2, speed: rl.Vector2, radius: f32 };

const World = struct { player: Player, ball: Ball };

const playerSize = rl.Vector2.init(200, 25);

const screenWidth = 800;
const screenHeight = 450;

const ballRadius = 10;

pub fn main() anyerror!void {
    var world = init_world(screenHeight, screenWidth);

    rl.initWindow(screenWidth, screenHeight, "Zig BreakOut");
    defer rl.closeWindow();

    rl.setTargetFPS(60);
    while (!rl.windowShouldClose()) {
        if (rl.isKeyDown(rl.KeyboardKey.l)) {
            move_player_right(&world.player);
        } else if (rl.isKeyDown(rl.KeyboardKey.h)) {
            move_player_left(&world.player);
        } else {
            stop_player(&world.player);
        }
        const dt = rl.getFrameTime();
        update_world(&world, dt);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);
        draw_player(world.player);
        draw_ball(world.ball);
    }
}

fn move_player_left(player: *Player) void {
    player.speed.x = -200;
}

fn move_player_right(player: *Player) void {
    player.speed.x = 200;
}

fn stop_player(player: *Player) void {
    player.speed.x = 0;
}

fn update_world(world: *World, dt: f32) void {
    // TODO: do any collision detection logic and update the speed of stuff
    handle_player_boundaries(&world.player, screenWidth);
    update_player(&world.player, dt);
    update_ball(&world.ball, dt);
}

fn handle_player_boundaries(player: *Player, width: i32) void {
    if (player.position.x <= 0 and player.speed.x < 0) {
        player.position.x = 0;
        player.speed.x = 0;
    } else if (player.position.x + player.size.x >= @as(f32, @floatFromInt(width)) and player.speed.x > 0) {
        player.position.x = @as(f32, @floatFromInt(width)) - player.size.x;
        player.speed.x = 0;
    }
}

fn update_player(player: *Player, dt: f32) void {
    player.position.x += player.speed.x * dt;
    player.position.y += player.speed.y * dt;
}

fn update_ball(ball: *Ball, dt: f32) void {
    ball.position.x += ball.speed.x * dt;
    ball.position.y += ball.speed.y * dt;
}

fn init_world(height: i32, width: i32) World {
    const playerXOffset = playerSize.x / 2;
    const playerYOffset = playerSize.y / 2;
    return World{ .player = init_player((@as(f32, @floatFromInt(width)) / 2.0) - playerXOffset, (@as(f32, @floatFromInt(height)) / 1.25) - playerYOffset), .ball = init_ball((@as(f32, @floatFromInt(width)) / 2.0) - ballRadius, (@as(f32, @floatFromInt(height)) / 2) - ballRadius) };
}

fn init_ball(x: f32, y: f32) Ball {
    const position = rl.Vector2.init(x, y);
    // FIXME:
    const speed = rl.Vector2.init(0, 100);
    const radius = @as(f32, ballRadius);
    return Ball{ .position = position, .speed = speed, .radius = radius };
}

fn init_player(x: f32, y: f32) Player {
    const position = rl.Vector2.init(x, y);
    debug_print_vec("start position", position);
    const size = playerSize;
    const speed = rl.Vector2.zero();
    return Player{ .position = position, .size = size, .speed = speed };
}

fn debug_print_vec(name: []const u8, vec: rl.Vector2) void {
    const x = vec.x;
    const y = vec.y;
    @import("std").debug.print("{s} x: {d}, y: {d}\n", .{ name, x, y });
}

fn draw_player(player: Player) void {
    rl.drawRectangleV(player.position, player.size, rl.Color.red);
}

fn draw_ball(ball: Ball) void {
    rl.drawCircleV(ball.position, ball.radius, rl.Color.blue);
}
