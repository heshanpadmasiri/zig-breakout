const rl = @import("raylib");

// FIXME: try to use a packed struct and treat all objects as same
// -- this will require Vecs to be pointers
const Player = struct { position: rl.Vector2, speed: rl.Vector2, size: rl.Vector2 };
const Ball = struct { position: rl.Vector2, speed: rl.Vector2, radius: f32 };

const World = struct { player: Player, ball: Ball, remaining_lives: u32 };

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
        if (world.remaining_lives > 0) {
            if (rl.isKeyDown(rl.KeyboardKey.l)) {
                move_player_right(&world.player);
            } else if (rl.isKeyDown(rl.KeyboardKey.h)) {
                move_player_left(&world.player);
            } else {
                stop_player(&world.player);
            }
            const dt = rl.getFrameTime();
            update_world(&world, dt);
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);
        rl.drawText(rl.textFormat("Remaining lives: %02i", .{world.remaining_lives}), 200, 80, 20, rl.Color.black);
        if (world.remaining_lives == 0) {
            rl.drawText("Game Over", 200, 200, 20, rl.Color.red);
        }

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
    handle_ball_player_collisions(&world.ball, &world.player);
    world.ball = handle_ball_boundaries(world, &world.ball, screenWidth, screenHeight);
    if (world.remaining_lives == 0) {
        return;
    }
    update_player(&world.player, dt);
    update_ball(&world.ball, dt);
}

fn handle_ball_player_collisions(ball: *Ball, player: *Player) void {
    const ball_x = ball.position.x;
    const ball_y = ball.position.y;
    const player_x = player.position.x;
    const player_y = player.position.y;
    const player_width = player.size.x;
    const player_height = player.size.y;
    if (ball_y + ball.radius >= player_y and ball_y - ball.radius <= player_y + player_height) {
        if (ball_x + ball.radius >= player_x and ball_x - ball.radius <= player_x + player_width) {
            ball.speed.y = -ball.speed.y;
            ball.speed.x += player.speed.x;
        }
    }
}

fn handle_ball_boundaries(world: *World, ball: *Ball, width: i32, height: i32) Ball {
    if (ball.position.y >= @as(f32, @floatFromInt(height))) {
        const ball_x, const ball_y = ball_starting_position(height, width);
        // TODO: how does the old ball get deallocated?
        world.remaining_lives -= 1;
        return init_ball(ball_x, ball_y);
    }
    if (ball.position.x - ball.radius <= 0 and ball.speed.x < 0) {
        ball.position.x = ball.radius;
        ball.speed.x = -ball.speed.x;
    } else if (ball.position.x + ball.radius >= @as(f32, @floatFromInt(width)) and ball.speed.x > 0) {
        ball.position.x = @as(f32, @floatFromInt(width)) - ball.radius;
        ball.speed.x = -ball.speed.x;
    }
    if (ball.position.y - ball.radius <= 0 and ball.speed.y < 0) {
        ball.position.y = ball.radius;
        ball.speed.y = -ball.speed.y;
    }
    return ball.*;
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
    const ball_x, const ball_y = ball_starting_position(height, width);
    return World{
        .player = init_player((@as(f32, @floatFromInt(width)) / 2.0) - playerXOffset, (@as(f32, @floatFromInt(height)) / 1.25) - playerYOffset),
        .ball = init_ball(ball_x, ball_y),
        .remaining_lives = 3,
    };
}

fn ball_starting_position(height: i32, width: i32) [2]f32 {
    const x = (@as(f32, @floatFromInt(width)) / 2.0) - ballRadius;
    const y = (@as(f32, @floatFromInt(height)) / 2) - ballRadius;
    return .{ x, y };
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
