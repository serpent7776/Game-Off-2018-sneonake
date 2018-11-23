local shack = require('lib/shack/shack')
local wave = require('lib/wave/wave')

local WX, WY
local tacc
local time
local game_time
local beat
local target_beat
local music
local sounds = {}
local C
local player = {
	update = function(self, dt)
		if self:is_alive() then
			local tx, ty = get_turbo(self.v.x, self.v.y)
			move(self, dt, tx, ty)
		end
	end,

	score = function(self)
		self.points = self.points + 1
		print('score', self.points)
	end,

	is_invul = function(self)
		return time < self.last_hit_time + self.invul_time
	end,

	hit = function(self)
		self.lives = self.lives - 1
		self.last_hit_time = time
		shack:setShake(20)
		shack:setRotation(0.16)
	end,

	is_alive = function(self)
		return self.lives > 0
	end,

	reset = function(self)
		self.x = 32
		self.y = 24
		self.curr_x = 32
		self.curr_y = 24
		self.prev_x = 32
		self.prev_y = 24
		self.s = 1
		self.c = {0, 255/C, 0, 255/C}
		self.v = {x = 12, y = 0}
		self.vmax = 12
		self.points = 0
		self.lives = 3
		self.last_hit_time = 0
		self.invul_time = 0.5
	end,
}
local cookie = {
	update = function(self, dt)
		self.s = 0.76 - math.abs(beat - target_beat) / 2
	end,

	spawn = function(self)
		self.x = love.math.random(0, 64 - 1)
		self.y = love.math.random(0, 48 - 1)
		self.curr_x = self.x
		self.curr_y = self.y
		self.prev_x = self.x
		self.prev_y = self.y
	end,

	reset = function(self)
		self.x = 48
		self.y = 24
		self.curr_x = 48
		self.curr_y = 24
		self.prev_x = 48
		self.prev_y = 24
		self.s = 0.75
		self.c = {0, 250/C, 250/C, 255/C}
	end,
}
local bullets = {
	spawn = function(self, x, y, vx, vy)
		local bullet = {
			x = x,
			y = y,
			curr_x = x,
			curr_y = y,
			prev_x = x,
			prev_y = y,
			v = {x = vx, y = vy},
			s = 1,
			c = {250/C, 0, 0, 255/C},
		}
		table.insert(self.all, bullet)
	end,

	update = function(self, dt)
		for i,b in ipairs(self.all) do
			move(b, dt)
		end
	end,

	reset = function(self)
		self.all = {}
	end,
}
local ripples = {
	all = {},
	count = 0,

	spawn = function(self, x, y)
		local r = {
			x = x,
			y = y,
			r = 1,
			v = 128,
		}
		table.insert(self.all, r)
		self.count = self.count + 1
	end,

	update = function(self, dt)
		for i, r in ipairs(self.all) do
			r.r = r.r + dt * r.v
		end
		if self.count > 0 and self.all[1].r > 80 then
			table.remove(self.all, 1)
			self.count = self.count - 1
		end
	end,
}
local grid = {

	load = function(self)
		self.tiles = {}
		for y=0, 48 do
			for x=0, 64 do
				self.tiles[y * 64 + x] = {
					s = 0,
					c = {0, 0, 0, 255/C},
				}
			end
		end
	end,

	tile = function(self, x, y)
		return self.tiles[y * 64 + x]
	end,

	set_tile = function(self, x, y, s, c)
		local t = self:tile(x, y)
		t.s = s
		t.c = c
		return t
	end,

	scale_tile = function(self, x, y, s)
		local t = self:tile(x, y)
		t.s = t.s * s
		return t
	end,

	lerp_tile = function(self, x, y, a, c)
		local t = self:tile(x, y)
		t.c = clerp(t.c, c, a)
		t.s = lerp(t.s, a, a)
		return t
	end,

	update = function(self, dt)
		for y=0, 48 do
			for x=0, 64 do
				self:scale_tile(x, y, 0.98)
				for i, r in ipairs(ripples.all) do
					local d = distance(x, y, r.x, r.y)
					local dd = math.abs(d - r.r)
					local a = 1 / (dd + 1)
					self:lerp_tile(x, y, a, player.c)
				end
			end
		end
		self:set_tile(cookie.x, cookie.y, cookie.s, cookie.c)
		if player:is_alive() then
			self:set_tile(get_x(player), get_y(player), player.s, player.c)
		end
		for i, b in ipairs(bullets.all) do
			self:set_tile(get_x(b), get_y(b), b.s, b.c)
		end
	end,

	draw = function(self)
		local bg1_c = {0, 48/C, 0, 255/C}
		local bg2_c = {0, 200/C, 0, 200/C}
		local s = beat
		local bg_c = clerp(bg1_c, bg2_c, s)
		local sz_max = WX / 64
		local sz_max_m1 = sz_max - 1
		for y=0, 48 do
			for x=0, 64 do
				local t = self:tile(x, y)
				local scale = t.s
				local sz = 2/3 * sz_max_m1 * scale + 1/3 * sz_max_m1
				local dd = scale * 1/3 * sz_max_m1
				love.graphics.setColor(clerp(bg_c, t.c, t.s))
				love.graphics.rectangle('fill', x * sz_max - dd + 1/3 * sz_max_m1, y * sz_max - dd + 1/3 * sz_max_m1, sz, sz)
			end
		end
	end,

}
gameover_tiles =
{{7, 4}, {8, 4}, {9, 4}, {10, 4}, {11, 4}, {12, 4}, {13, 4}, {23, 4}, {24, 4}, {25, 4}, {34, 4}, {35, 4}, {36, 4}, {44, 4}, {45, 4}, {46, 4}, {52, 4}, {53, 4}, {54, 4}, {55, 4}, {56, 4}, {57, 4}, {58, 4}, {59, 4}, {60, 4}, {5, 5}, {6, 5}, {7, 5}, {12, 5}, {13, 5}, {14, 5}, {23, 5}, {24, 5}, {25, 5}, {34, 5}, {35, 5}, {36, 5}, {37, 5}, {43, 5}, {44, 5}, {45, 5}, {46, 5}, {52, 5}, {53, 5}, {4, 6}, {5, 6}, {14, 6}, {22, 6}, {23, 6}, {25, 6},
{26, 6}, {34, 6}, {35, 6}, {36, 6}, {37, 6}, {43, 6}, {44, 6}, {45, 6}, {46, 6}, {52, 6}, {53, 6}, {4, 7}, {5, 7}, {22, 7}, {23, 7}, {25, 7}, {26, 7}, {34, 7}, {35, 7}, {37, 7}, {43, 7}, {45, 7}, {46, 7}, {52, 7}, {53, 7}, {3, 8}, {4, 8}, {22, 8}, {23, 8}, {25, 8}, {26, 8}, {34, 8}, {35, 8}, {37, 8}, {38, 8}, {42, 8}, {43, 8}, {45, 8}, {46, 8}, {52, 8}, {53, 8}, {3, 9}, {4, 9}, {21, 9}, {22, 9}, {26, 9}, {27, 9}, {34, 9}, {35, 9}, {37, 9},
{38, 9}, {42, 9}, {43, 9}, {45, 9}, {46, 9}, {52, 9}, {53, 9}, {3, 10}, {4, 10}, {21, 10}, {22, 10}, {26, 10}, {27, 10}, {34, 10}, {35, 10}, {38, 10}, {42, 10}, {45, 10}, {46, 10}, {52, 10}, {53, 10}, {54, 10}, {55, 10}, {56, 10}, {57, 10}, {58, 10}, {59, 10}, {60, 10}, {3, 11}, {4, 11}, {10, 11}, {11, 11}, {12, 11}, {13, 11}, {14, 11}, {21, 11}, {22, 11}, {27, 11}, {34, 11}, {35, 11}, {38, 11}, {39, 11}, {41, 11}, {42, 11}, {45, 11}, {46, 11}, {52, 11}, {53, 11}, {3, 12}, {4, 12},
{13, 12}, {14, 12}, {20, 12}, {21, 12}, {27, 12}, {28, 12}, {34, 12}, {35, 12}, {39, 12}, {41, 12}, {45, 12}, {46, 12}, {52, 12}, {53, 12}, {3, 13}, {4, 13}, {13, 13}, {14, 13}, {20, 13}, {21, 13}, {22, 13}, {23, 13}, {24, 13}, {25, 13}, {26, 13}, {27, 13}, {28, 13}, {34, 13}, {35, 13}, {39, 13}, {41, 13}, {45, 13}, {46, 13}, {52, 13}, {53, 13}, {4, 14}, {5, 14}, {13, 14}, {14, 14}, {19, 14}, {20, 14}, {28, 14}, {29, 14}, {34, 14}, {35, 14}, {39, 14}, {40, 14}, {41, 14}, {45, 14}, {46, 14}, {52, 14},
{53, 14}, {4, 15}, {5, 15}, {13, 15}, {14, 15}, {19, 15}, {20, 15}, {28, 15}, {29, 15}, {34, 15}, {35, 15}, {45, 15}, {46, 15}, {52, 15}, {53, 15}, {5, 16}, {6, 16}, {7, 16}, {12, 16}, {13, 16}, {14, 16}, {19, 16}, {20, 16}, {28, 16}, {29, 16}, {34, 16}, {35, 16}, {45, 16}, {46, 16}, {52, 16}, {53, 16}, {7, 17}, {8, 17}, {9, 17}, {10, 17}, {11, 17}, {12, 17}, {13, 17}, {18, 17}, {19, 17}, {29, 17}, {30, 17}, {34, 17}, {35, 17}, {45, 17}, {46, 17}, {52, 17}, {53, 17}, {54, 17}, {55, 17},
{56, 17}, {57, 17}, {58, 17}, {59, 17}, {60, 17}, {9, 28}, {10, 28}, {11, 28}, {12, 28}, {13, 28}, {20, 28}, {21, 28}, {31, 28}, {32, 28}, {36, 28}, {37, 28}, {38, 28}, {39, 28}, {40, 28}, {41, 28}, {42, 28}, {43, 28}, {44, 28}, {49, 28}, {50, 28}, {51, 28}, {52, 28}, {53, 28}, {54, 28}, {55, 28}, {7, 29}, {8, 29}, {14, 29}, {15, 29}, {21, 29}, {22, 29}, {30, 29}, {31, 29}, {36, 29}, {37, 29}, {49, 29}, {50, 29}, {55, 29}, {56, 29}, {6, 30}, {7, 30}, {15, 30}, {16, 30}, {21, 30}, {22, 30},
{30, 30}, {31, 30}, {36, 30}, {37, 30}, {49, 30}, {50, 30}, {56, 30}, {57, 30}, {6, 31}, {7, 31}, {15, 31}, {16, 31}, {21, 31}, {22, 31}, {30, 31}, {31, 31}, {36, 31}, {37, 31}, {49, 31}, {50, 31}, {56, 31}, {57, 31}, {5, 32}, {6, 32}, {16, 32}, {17, 32}, {22, 32}, {23, 32}, {29, 32}, {30, 32}, {36, 32}, {37, 32}, {49, 32}, {50, 32}, {56, 32}, {57, 32}, {5, 33}, {6, 33}, {16, 33}, {17, 33}, {22, 33}, {23, 33}, {29, 33}, {30, 33}, {36, 33}, {37, 33}, {49, 33}, {50, 33}, {56, 33}, {57, 33},
{5, 34}, {6, 34}, {16, 34}, {17, 34}, {23, 34}, {24, 34}, {28, 34}, {29, 34}, {36, 34}, {37, 34}, {38, 34}, {39, 34}, {40, 34}, {41, 34}, {42, 34}, {43, 34}, {44, 34}, {49, 34}, {50, 34}, {55, 34}, {56, 34}, {5, 35}, {6, 35}, {16, 35}, {17, 35}, {23, 35}, {24, 35}, {28, 35}, {29, 35}, {36, 35}, {37, 35}, {49, 35}, {50, 35}, {51, 35}, {52, 35}, {53, 35}, {54, 35}, {55, 35}, {5, 36}, {6, 36}, {16, 36}, {17, 36}, {23, 36}, {24, 36}, {28, 36}, {29, 36}, {36, 36}, {37, 36}, {49, 36}, {50, 36},
{55, 36}, {56, 36}, {5, 37}, {6, 37}, {16, 37}, {17, 37}, {24, 37}, {25, 37}, {27, 37}, {28, 37}, {36, 37}, {37, 37}, {49, 37}, {50, 37}, {56, 37}, {57, 37}, {6, 38}, {7, 38}, {15, 38}, {16, 38}, {24, 38}, {25, 38}, {27, 38}, {28, 38}, {36, 38}, {37, 38}, {49, 38}, {50, 38}, {56, 38}, {57, 38}, {6, 39}, {7, 39}, {15, 39}, {16, 39}, {24, 39}, {25, 39}, {27, 39}, {28, 39}, {36, 39}, {37, 39}, {49, 39}, {50, 39}, {57, 39}, {58, 39}, {7, 40}, {8, 40}, {14, 40}, {15, 40}, {25, 40}, {26, 40},
{27, 40}, {36, 40}, {37, 40}, {49, 40}, {50, 40}, {57, 40}, {58, 40}, {9, 41}, {10, 41}, {11, 41}, {12, 41}, {13, 41}, {25, 41}, {26, 41}, {27, 41}, {36, 41}, {37, 41}, {38, 41}, {39, 41}, {40, 41}, {41, 41}, {42, 41}, {43, 41}, {44, 41}, {49, 41}, {50, 41}, {58, 41}, {59, 41}}

function get_x(o)
	return math.floor(o.x) % 64
end

function get_y(o)
	return math.floor(o.y) % 48
end

function distance(x1, y1, x2, y2)
	local x = math.abs(x2 - x1)
	local y = math.abs(y2 - y1)
	return x + y
end

function lerp(x, y, a)
	local b = 1 - a
	return x * b + y * a
end

function clerp(r, t, a)
	local b = 1 - a
	return {
		r[1] * b + t[1] * a,
		r[2] * b + t[2] * a,
		r[3] * b + t[3] * a,
		r[4] * b + t[4] * a,
	}
end

function minmax(x, y)
	local min = math.min(x, y)
	local max = math.max(x, y)
	return min, max
end

function minmaxp1(x, y)
	local min = math.min(x, y)
	local max = math.max(x, y)
	return math.floor(min), math.floor(max)
end

function move(o, dt, tx, ty)
	tx = tx or 0
	ty = ty or 0
	o.prev_x = o.x
	o.prev_y = o.y
	o.curr_x = (o.x + (o.v.x + tx) * dt)
	o.curr_y = (o.y + (o.v.y + ty) * dt)
	o.x = o.curr_x % 64
	o.y = o.curr_y % 48
end

function collides(a, b)
	local axmin, axmax = minmaxp1(a.curr_x, a.prev_x)
	local aymin, aymax = minmaxp1(a.curr_y, a.prev_y)
	local bxmin, bxmax = minmaxp1(b.curr_x, b.prev_x)
	local bymin, bymax = minmaxp1(b.curr_y, b.prev_y)
	local intersect =
		axmax >= bxmin and
		axmin <= bxmax and
		aymin <= bymax and
		aymax >= bymin
	return intersect
end

function check_cookie_eaten()
	if collides(player, cookie) then
		player:score()
		ripples:spawn(cookie.x, cookie.y)
		cookie:spawn()
		spawn_bullet()
		sounds.cookie_eaten:play()
		shack:setScale(1.02)
	end
end

function check_player_hit(self)
	if not player:is_alive() then
		return
	end
	for i, b in ipairs(bullets.all) do
		if collides(player, b) and not player:is_invul() then
			player:hit()
			sounds.player_hit:play()
		end
	end
end

function get_turbo(vx, vy)
	local tx = math.abs(vx) > 0 and player.points * 0.5 * math.abs(vx) / vx or 0
	local ty = math.abs(vy) > 0 and player.points * 0.5 * math.abs(vy) / vy or 0
	return tx, ty
end

function spawn_bullet()
	local vx = player.v.y
	local vy = -player.v.x
	local x = player.x + (math.abs(vx) > 0 and math.abs(vx) / vx * 2 or 0)
	local y = player.y + (math.abs(vy) > 0 and math.abs(vy) / vy * 2 or 0)
	local tx, ty = get_turbo(vx, vy)
	bullets:spawn(x, y, vx + tx, vy + ty)
end

function beat_handler()
	if target_beat > 0 then
		target_beat = 0
	else
		target_beat = 1
	end
	shack:setScale(1.01)
end

function load_music()
	music = wave:newSource('snake.ogg', 'stream')
	music:setLooping(true)
	music:setVolume(0.44)
	music:setIntensity(20)
	music:setBPM(80)
	music:onBeat(beat_handler)
	music:parse()
	music:play()
end

function load_sounds()
	sounds = {
		player_hit = love.audio.newSource('hit.ogg', 'static'),
		cookie_eaten = love.audio.newSource('cookie.ogg', 'static'),
	}
end

function load_shack()
	local width, height = love.graphics.getDimensions()
	shack:setDimensions(width, height)
end

function gameover()
	local s = math.abs(beat - target_beat) * 0.666
	for _, t in ipairs(gameover_tiles) do
		local x = t[1]
		local y = t[2]
		local tile = grid:tile(x, y)
		if tile.s < 0.5 then
			grid:set_tile(x, y, s, player.c)
		end
	end
end

function reset()
	time = 0
	game_time = 0
	player:reset()
	bullets:reset()
	cookie:reset()
end

function love.load()
	local major = love.getVersion()
	WX, WY = love.graphics.getDimensions()
	C = major < 1 and 1 or 255
	tacc = 0
	beat = 0
	target_beat = 1
	grid:load()
	load_shack()
	load_sounds()
	load_music()
	reset()
end

function love.keypressed(key, scancode, isRepeat)
	if not player:is_alive() then
		if key == 'r' then
			reset()
		end
		return
	end
	if key == 'up' and player.v.y <= 0 then
		player.v.x = 0
		player.v.y = -player.vmax
	elseif key == 'down' and player.v.y >= 0 then
		player.v.x = 0
		player.v.y = player.vmax
	elseif key == 'left' and player.v.x <= 0 then
		player.v.x = -player.vmax
		player.v.y = 0
	elseif key == 'right' and player.v.x >= 0 then
		player.v.x = player.vmax
		player.v.y = 0
	end
end

function love.update(dt)
	local ut = 0.02
	tacc = tacc + dt
	while tacc > ut do
		tacc = tacc - ut
		time = time + ut
		beat = target_beat * ut * 3 + beat * (1 - ut * 3)
		music:update(ut)
		if not player:is_alive() then
			gameover()
		end
		cookie:update(ut)
		player:update(ut)
		bullets:update(ut)
		ripples:update(ut)
		check_cookie_eaten()
		check_player_hit()
		grid:update(ut)
		shack:update(ut)
	end
	if player:is_alive() then
		game_time = time
	end
end

function love:draw()
	local t = string.format('%.1f', game_time)
	love.graphics.print('Score: ' .. player.points, 5, 1, 0, 1, 1)
	love.graphics.printf('Time: ' .. t, 700, 1, 95, 'right')
	if not player:is_alive() then
		love.graphics.printf('Press R to restart', 325, 1, 200, 'center')
	end
	love.graphics.translate(0, 16)
	shack:apply()
	grid:draw()
	love.graphics.setColor(255/C, 255/C, 255/C, 255/C)
end
