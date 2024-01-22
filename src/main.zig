const std = @import("std");
const math = std.math;
const mem = std.mem;
const s = @cImport({
    @cInclude("SDL.h");
});

// zig fmt: off
const CELL_SIZE     = 5;
const TICK_RATE     = 100;
const W_HEIGHT:i32  = 480;
const W_WIDTH: i32  = 640;
const Pi            = std.math.pi;
const Renderer      = s.SDL_Renderer;
const Keycode       = s.SDL_Keycode;
const MouseBtnEvent = s.SDL_MouseButtonEvent;
const Rectangle     = s.SDL_Rect;
const SDL_Event     = s.SDL_Event;
const Cells         = [W_HEIGHT][W_WIDTH]Cell;
// zig fmt: on

pub fn main() !void {
    _ = s.SDL_Init(s.SDL_INIT_VIDEO);
    var window = s.SDL_CreateWindow("Game of Life", s.SDL_WINDOWPOS_CENTERED, s.SDL_WINDOWPOS_CENTERED, 640, 480, 0);
    var renderer = s.SDL_CreateRenderer(window, 0, s.SDL_RENDERER_PRESENTVSYNC);
    defer {
        s.SDL_Quit();
        s.SDL_DestroyWindow(window);
        s.SDL_DestroyRenderer(renderer);
    }

    var game_start: bool = false;
    var cells: Cells = mem.zeroes(Cells);
    var current_time = s.SDL_GetTicks();
    var delta_time = current_time;

    // MAIN GAME
    gameloop: while (true) {
        var event: SDL_Event = undefined;
        while (s.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                // zig fmt: off
                s.SDL_QUIT              => break :gameloop,
                s.SDL_MOUSEBUTTONDOWN   => setFromMouse(event.button, &cells), 
                s.SDL_KEYDOWN           => toggleState(event.key.keysym.sym, &game_start),
                else                    => {},
                // zig fmt: on
            }
        }
        if (game_start) {
            delta_time = s.SDL_GetTicks() - current_time;
            if (delta_time >= TICK_RATE) {
                current_time += delta_time;
                updateCells(&cells);
            }
        }
        renderFrame(renderer.?, &cells);
    }
}

pub fn toggleState(key: Keycode, state: *bool) void {
    switch (key) {
        s.SDLK_RETURN => state.* = if (state.*) false else true,
        else => {},
    }
}

pub const Cell = struct {
    const Self = @This();
    is_living: bool,
    will_live: bool,

    pub fn isOverpop(self: *Self, neighbors: usize) bool {
        if (self.is_living and (neighbors < 2 or neighbors > 3)) return true;
        return false;
    }
    pub fn isStable(self: *Self, neighbors: usize) bool {
        if (self.is_living and (neighbors == 2 or neighbors == 3)) return true;
        return false;
    }
    pub fn isBirthed(self: *Self, neighbors: usize) bool {
        if (!self.is_living and neighbors == 3) return true;
        return false;
    }
};

pub fn setCell(mx: i32, my: i32, cells: *Cells, state: bool) void {
    const x: usize = @as(usize, @intCast(mx)) / CELL_SIZE;
    const y: usize = @as(usize, @intCast(my)) / CELL_SIZE;
    cells.*[x][y].is_living = state;
}

pub fn setFromMouse(event: MouseBtnEvent, cells: *Cells) void {
    const btn = event.button;
    switch (btn) {
        s.SDL_BUTTON_LEFT => setCell(event.x, event.y, cells, true),
        s.SDL_BUTTON_RIGHT => setCell(event.x, event.y, cells, false),
        else => {},
    }
}

pub fn renderFrame(r: *Renderer, cells: *Cells) void {
    _ = s.SDL_SetRenderDrawColor(r, 0x00, 0x00, 0x00, 0xff);
    _ = s.SDL_RenderClear(r);
    _ = s.SDL_SetRenderDrawColor(r, 0x50, 0x50, 0xf0, 0xff);
    for (cells, 0..) |cols, x| for (cols, 0..) |c, y| {
        if (!c.is_living) continue;
        var cell = Rectangle{ .x = @intCast(x * CELL_SIZE), .y = @intCast(y * CELL_SIZE), .w = CELL_SIZE, .h = CELL_SIZE };
        _ = s.SDL_RenderDrawRect(r, &cell);
    };
    _ = s.SDL_RenderPresent(r);
}

pub fn getNeighbors(cell_x: usize, cell_y: usize, cells: *Cells) usize {
    const x_min = if (cell_x > 0) cell_x - 1 else 0;
    const x_max = if (cell_x < W_HEIGHT - 1) cell_x + 2 else W_HEIGHT - 1;
    const y_min = if (cell_y > 0) cell_y - 1 else 0;
    const y_max = if (cell_y < W_WIDTH - 1) cell_y + 2 else W_WIDTH - 1;
    var neighbors: usize = 0;
    for (x_min..x_max) |i| for (y_min..y_max) |j| {
        if (i == cell_x and j == cell_y) continue;
        if (cells[i][j].is_living) neighbors += 1;
    };
    return neighbors;
}

pub fn updateCells(cells: *Cells) void {
    for (0..W_HEIGHT) |x| for (0..W_WIDTH) |y| {
        const neighbors = getNeighbors(x, y, cells);
        var c = cells[x][y];
        if (c.isStable(neighbors)) cells.*[x][y].will_live = true;
        if (c.isOverpop(neighbors)) cells.*[x][y].will_live = false;
        if (c.isBirthed(neighbors)) cells.*[x][y].will_live = true;
    };
    for (0..W_HEIGHT) |x| for (0..W_WIDTH) |y| {
        cells.*[x][y].is_living = cells.*[x][y].will_live;
        cells.*[x][y].will_live = false;
    };
}
