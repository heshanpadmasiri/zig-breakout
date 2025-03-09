const rl = @import("raylib");
const std = @import("std");

// FIXME: try to use a packed struct and treat all objects as same
// -- this will require Vecs to be pointers
const Player = struct { position: rl.Vector2, speed: rl.Vector2, size: rl.Vector2 };
const Ball = struct { position: rl.Vector2, speed: rl.Vector2, radius: f32 };
const Brick = struct { position: rl.Vector2, active: bool };

const World = struct {
    player: Player,
    ball: Ball,
    remaining_lives: u32,
    remaining_bricks: u32,
    height: u32,
    width: u32,
    bricks: [nBricks]Brick,
};

const playerSize = rl.Vector2.init(200, 25);

const screenWidth = 800;
const screenHeight = 450;
const brickCols = 10;
const brickRows = 5;
const nBricks = brickCols * brickRows;
const brickWidth = screenWidth / brickCols;
const brickHeight = 20;
const brickSize = rl.Vector2.init(brickWidth, brickHeight);

const ballRadius = 10;

var world = init_world(screenHeight, screenWidth);

pub fn main() anyerror!void {
    rl.initWindow(screenWidth, screenHeight, "Zig BreakOut");
    defer rl.closeWindow();

    rl.setTargetFPS(60);
    const world_ptr = &world;
    while (!rl.windowShouldClose()) {
        if (rl.isKeyPressed(rl.KeyboardKey.r)) {
            reset_world(world_ptr);
        }

        if (should_update_world(world_ptr)) {
            handle_user_input(world_ptr);
            const dt = rl.getFrameTime();
            tick(world_ptr, dt);
        }
        draw_game(world_ptr);
    }
}

fn reset_world(world_ptr: *World) void {
    world_ptr.remaining_bricks = nBricks;
    world_ptr.remaining_lives = 3;

    const playerX, const playerY = initial_player_position(world_ptr.height, world_ptr.width);
    world_ptr.player.position.x = playerX;
    world_ptr.player.position.y = playerY;
    world_ptr.player.speed.x = 0;
    world_ptr.player.speed.y = 0;

    const ball_x, const ball_y = ball_starting_position(world_ptr.height, world_ptr.width);
    world_ptr.ball.position.x = ball_x;
    world_ptr.ball.position.y = ball_y;
    world_ptr.ball.speed.x = 0;
    world_ptr.ball.speed.y = 100;

    for (&world_ptr.bricks) |*brick| {
        brick.active = true;
    }
}

inline fn move_player_left(world_ptr: *World) void {
    world_ptr.player.speed.x = -200;
}

inline fn move_player_right(world_ptr: *World) void {
    world_ptr.player.speed.x = 200;
}

inline fn stop_player(world_ptr: *World) void {
    world_ptr.player.speed.x = 0;
}

inline fn is_game_over(world_ptr: *World) bool {
    return world_ptr.remaining_lives == 0;
}

inline fn is_game_won(world_ptr: *World) bool {
    return world_ptr.remaining_bricks == 0;
}

inline fn should_update_world(world_ptr: *World) bool {
    return !is_game_over(world_ptr) and !is_game_won(world_ptr);
}

fn handle_user_input(world_ptr: *World) void {
    if (rl.isKeyDown(rl.KeyboardKey.l)) {
        move_player_right(world_ptr);
    } else if (rl.isKeyDown(rl.KeyboardKey.h)) {
        move_player_left(world_ptr);
    } else {
        stop_player(world_ptr);
    }
}

fn draw_game(world_ptr: *World) void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.white);
    rl.drawText(rl.textFormat("Remaining lives: %02i", .{world_ptr.remaining_lives}), 200, 180, 20, rl.Color.black);
    if (is_game_over(world_ptr)) {
        rl.drawText("Game Over", 200, 200, 20, rl.Color.red);
    } else if (is_game_won(world_ptr)) {
        rl.drawText("You Won!", 200, 200, 20, rl.Color.green);
    }

    draw_player(world_ptr.player);
    draw_ball(world_ptr.ball);
    for (world_ptr.bricks) |brick| {
        draw_brick(brick);
    }
}

fn tick(world_ptr: *World, dt: f32) void {
    handle_user_input(world_ptr);
    update_world(world_ptr, dt);
}

fn update_world(world_ptr: *World, dt: f32) void {
    handle_player_boundaries(&world_ptr.player, world_ptr.width);
    handle_ball_player_collisions(&world_ptr.ball, &world.player);
    for (&world_ptr.bricks) |*brick| {
        handle_ball_brick_collisions(&world_ptr.ball, brick);
    }
    world_ptr.ball = handle_ball_boundaries(world_ptr, &world.ball, world_ptr.width, world_ptr.height);
    if (world_ptr.remaining_lives == 0) {
        return;
    }
    update_player(&world_ptr.player, dt);
    update_ball(&world_ptr.ball, dt);
}

fn handle_ball_brick_collisions(ball: *Ball, brick: *Brick) void {
    if (!brick.active) {
        return;
    }
    const ball_x = ball.position.x;
    const ball_y = ball.position.y;
    const brick_x = brick.position.x;
    const brick_y = brick.position.y;
    if (ball_y + ball.radius >= brick_y and ball_y - ball.radius <= brick_y + brickSize.y) {
        if (ball_x + ball.radius >= brick_x and ball_x - ball.radius <= brick_x + brickSize.x) {
            ball.speed.y = -ball.speed.y;
            brick.active = false;
        }
    }
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

fn handle_ball_boundaries(world_ptr: *World, ball: *Ball, width: u32, height: u32) Ball {
    if (ball.position.y >= @as(f32, @floatFromInt(height))) {
        const ball_x, const ball_y = ball_starting_position(height, width);
        // TODO: how does the old ball get deallocated?
        world_ptr.remaining_lives -= 1;
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

fn handle_player_boundaries(player: *Player, width: u32) void {
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

fn init_world(height: u32, width: u32) World {
    const ball_x, const ball_y = ball_starting_position(height, width);

    const bricks = init_bricks();
    const playerX, const playerY = initial_player_position(height, width);
    return World{
        .player = init_player(playerX, playerY),
        .ball = init_ball(ball_x, ball_y),
        .remaining_lives = 3,
        .bricks = bricks,
        .remaining_bricks = brickCols * brickRows,
        .height = height,
        .width = width,
    };
}

fn initial_player_position(height: u32, width: u32) [2]f32 {
    const playerXOffset = playerSize.x / 2;
    const playerYOffset = playerSize.y / 2;
    const x = (@as(f32, @floatFromInt(width)) / 2.0) - playerXOffset;
    const y = (@as(f32, @floatFromInt(height)) / 1.25) - playerYOffset;
    return .{ x, y };
}

fn ball_starting_position(height: u32, width: u32) [2]f32 {
    const x = (@as(f32, @floatFromInt(width)) / 2.0) - ballRadius;
    const y = (@as(f32, @floatFromInt(height)) / 2) - ballRadius;
    return .{ x, y };
}

fn init_ball(x: f32, y: f32) Ball {
    const position = rl.Vector2.init(x, y);
    const speed = rl.Vector2.init(0, 100);
    const radius = @as(f32, ballRadius);
    return Ball{ .position = position, .speed = speed, .radius = radius };
}

fn init_player(x: f32, y: f32) Player {
    const position = rl.Vector2.init(x, y);
    const size = playerSize;
    const speed = rl.Vector2.init(0, 0);
    return Player{ .position = position, .size = size, .speed = speed };
}

fn init_bricks() [nBricks]Brick {
    var bricks: [nBricks]Brick = undefined;

    for (0..brickRows) |row| {
        for (0..brickCols) |col| {
            const x = col * brickWidth;
            const y = row * brickHeight;
            const position = rl.Vector2.init(@as(f32, @floatFromInt(x)), @as(f32, @floatFromInt(y)));
            const index = row * brickCols + col;
            bricks[index] = Brick{ .position = position, .active = true };
        }
    }
    return bricks;
}

fn draw_player(player: Player) void {
    rl.drawRectangleV(player.position, player.size, rl.Color.red);
}

fn draw_ball(ball: Ball) void {
    rl.drawCircleV(ball.position, ball.radius, rl.Color.blue);
}

fn draw_brick(brick: Brick) void {
    if (!brick.active) {
        return;
    }
    // Draw the brick body
    rl.drawRectangleV(brick.position, brickSize, rl.Color.green);
    // Draw black boundary around the brick (using standard drawRectangleLines)
    rl.drawRectangleLines(@intFromFloat(brick.position.x), @intFromFloat(brick.position.y), @intFromFloat(brickSize.x), @intFromFloat(brickSize.y), rl.Color.black);
}
