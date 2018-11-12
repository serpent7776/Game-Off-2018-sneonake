local shack = require('lib/shack/shack')
local wave = require('lib/wave/wave')

local time
local beat
local target_beat
local music
local sounds = {}
local C = 255
local player = {
	x = 32,
	y = 24,
	curr_x = 32,
	curr_y = 24,
	prev_x = 32,
	prev_y = 24,
	s = 1,
	c = {0, 255/C, 0, 255/C},
	v = {x = 12, y = 0},
	vmax = 12,
	points = 0,
	lives = 3,
	last_hit_time = 0,
	invul_time = 0.5,

	update = function(self, dt)
		if self:is_alive() then
			local tx = math.abs(self.v.x) > 0 and self.points * math.abs(self.v.x) / self.v.x or 0
			local ty = math.abs(self.v.y) > 0 and self.points * math.abs(self.v.y) / self.v.y or 0
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
	end
}
local cookie = {
	x = 48,
	y = 24,
	curr_x = 48,
	curr_y = 24,
	prev_x = 48,
	prev_y = 24,
	s = 0.75,
	c = {0, 250/C, 250/C, 255/C},

	update = function(self, dt)
		self.s = 0.76 - math.abs(beat - target_beat) / 2
	end,

	spawn = function(self)
		self.x = math.random(0, 64 - 1)
		self.y = math.random(0, 48 - 1)
		self.curr_x = self.x
		self.curr_y = self.y
		self.prev_x = self.x
		self.prev_y = self.y
	end,
}
local bullets = {
	all = {},
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

	update = function(self, dt)
		for y=0, 48 do
			for x=0, 64 do
				self:scale_tile(x, y, 0.98)
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
		local bg1_c = {0, 48/C, 0, 255/C, 1}
		local bg2_c = {0, 200/C, 0, 200/C, 1}
		local s = beat
		local c = lerp(bg1_c, bg2_c, s)
		for y=0, 48 do
			for x=0, 64 do
				local t = self:tile(x, y)
				local scale = t.s
				local sz = 10 * scale + 5
				local dd = scale * 5
				love.graphics.setColor(lerp(c, t.c, t.s))
				love.graphics.rectangle('fill', x * 16 - dd + 5, y * 16 - dd + 5, sz, sz)
			end
		end
	end,

}

function get_x(o)
	return math.floor(o.x) % 64
end

function get_y(o)
	return math.floor(o.y) % 48
end

function lerp(r, t, a)
	local b = 1 - a
	return {
		r[1] * b + t[1] * a,
		r[2] * b + t[2] * a,
		r[3] * b + t[3] * a,
		r[4] * b + t[4] * a,
	}
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

function spawn_bullet()
	local vx = player.v.y
	local vy = -player.v.x
	local x = player.x + (math.abs(vx) > 0 and math.abs(vx) / vx * 2 or 0)
	local y = player.y + (math.abs(vy) > 0 and math.abs(vy) / vy * 2 or 0)
	local tx = math.abs(vx) > 0 and player.points * math.abs(vx) / vx or 0
	local ty = math.abs(vy) > 0 and player.points * math.abs(vy) / vy or 0
	bullets:spawn(x, y, vx + tx, vy + ty)
end

function beat_handler()
	if target_beat > 0 then
		target_beat = 0
	else
		target_beat = 1
	end
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

function love.load()
	time = 0
	beat = 0
	target_beat = 1
	math.randomseed(os.time())
	grid:load()
	load_shack()
	load_sounds()
	load_music()
end

function love.keypressed(key, scancode, isRepeat)
	if not player:is_alive() then
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
	time = time + dt
	beat = target_beat * dt * 3 + beat * (1 - dt * 3)
	music:update(dt)
	cookie:update(dt)
	player:update(dt)
	bullets:update(dt)
	check_cookie_eaten()
	check_player_hit()
	grid:update(dt)
	shack:update(dt)
end

function love:draw()
	shack:apply()
	grid:draw()
end
