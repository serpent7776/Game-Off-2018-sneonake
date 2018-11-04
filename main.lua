local grid_shader
local time
local player = {
	x = 32,
	y = 24,
	s = 1,
	c = {0, 255, 0, 255},
	v = {x = 12, y = 0},
	vmax = 12,
	points = 0,

	update = function(self, dt)
		local tx = math.abs(self.v.x) > 0 and self.points * math.abs(self.v.x) / self.v.x or 0
		local ty = math.abs(self.v.y) > 0 and self.points * math.abs(self.v.y) / self.v.y or 0
		print(tx, ty)
		self.x = (self.x + (self.v.x + tx) * dt) % 64
		self.y = (self.y + (self.v.y + ty) * dt) % 48
	end,

	score = function(self)
		self.points = self.points + 1
		print('score', self.points)
	end,
}
local cookie = {
	x = 48,
	y = 24,
	s = 0.75,
	c = {0, 250, 250, 255},

	update = function(self, dt)
		self.s = 1 / math.max(0.5, math.cos(time * 3)) / 2 * 0.75
	end,

	spawn = function(self)
		self.x = math.random(0, 64 - 1)
		self.y = math.random(0, 48 - 1)
	end,
}
local grid = {

	load = function(self)
		self.tiles = {}
		for y=0, 48 do
			for x=0, 64 do
				self.tiles[y * 64 + x] = {
					s = 0,
					c = {0, 0, 0, 255},
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
				-- love.graphics.setColor(self:tile(x, y).c)
				-- love.graphics.rectangle('fill', x, y, 1, 1)
				self:scale_tile(x, y, 0.98)
			end
		end
		self:set_tile(cookie.x, cookie.y, cookie.s, cookie.c)
		self:set_tile(get_x(player), get_y(player), player.s, player.c)
	end,

	draw = function(self)
		local c = {0, 48, 0, 255}
		for y=0, 48 do
			for x=0, 64 do
				-- love.graphics.setColor(0, 48, 0)
				-- love.graphics.rectangle('fill', x * 16 + 1, y * 16 + 1, 12, 12)
				local t = self:tile(x, y)
				-- local scale = math.sin(time * 3) / 2 + 0.5
				local scale = t.s
				local sz = 10 * scale + 5
				-- local sz = 12
				local dd = scale * 5
				-- print(time, scale, sz, dd)
				love.graphics.setColor(lerp(c, t.c, t.s))
				-- love.graphics.setColor(t.c)
				love.graphics.rectangle('fill', x * 16 - dd + 5, y * 16 - dd + 5, sz, sz)
			end
		end
	end,

}

function get_x(o)
	return math.floor(o.x + 0.5) % 64
end

function get_y(o)
	return math.floor(o.y + 0.5) % 64
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

function collides(a, b)
	if get_x(a) == get_x(b) and get_y(a) == get_y(b) then
		return true
	end
	return false
end

function check_cookie_eaten()
	if collides(player, cookie) then
		player:score()
		cookie:spawn()
	end
end

function love.load()
	time = 0
	math.randomseed(os.time())
	grid:load()
	grid_shader = love.graphics.newShader [[
		extern number time;
		vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords) {
			// number x = step(0.5f, mod(pixel_coords.x, 16) / 15.0f);
			// number y = step(0.5f, mod(pixel_coords.y, 16) / 15.0f);
			// vec2 xy = step((0.5f + sin(time) / 2.0f), mod(pixel_coords + 4, 16) / 15.0f);
			// vec2 xy = step((0.5f + sin(time) / 2.0f), (sin(pixel_coords / 16.0f)));
			// vec2 xy = step((0.5f + sin(time) / 2.0f), fract(pixel_coords / 16.0f));
			// vec2 xy = step((0.5f + sin(time) / 2.0f), sin(pixel_coords + 4) / 2.0f + 0.5f);
			vec2 xy = step(0.5f + sin(time * 3.0f) / 2.1f, (cos((pixel_coords * 3.14159f) / 8.0f) / 2.0f + 0.5f));
			return xy.x * xy.y * vec4(0, 0.25, 0, 1.0);
			// return vec4(xy.x, xy.y, 0.0f, 1.0f);
		}
	]]
end

function love.keypressed(key, scancode, isRepeat)
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
	cookie:update(dt)
	player:update(dt)
	check_cookie_eaten()
	grid:update(dt)
end

function love:draw()
	grid:draw()
	--[[
	   [ grid_shader:send('time', time)
	   [ love.graphics.setShader(grid_shader)
	   [ love.graphics.rectangle('fill', 0, 0, 1024, 768)
	   ]]
end
