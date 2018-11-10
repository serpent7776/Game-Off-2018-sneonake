local time
local C = 255
local player = {
	x = 32,
	y = 24,
	s = 1,
	c = {0, 255/C, 0, 255/C},
	v = {x = 12, y = 0},
	vmax = 12,
	points = 0,

	update = function(self, dt)
		local tx = math.abs(self.v.x) > 0 and self.points * math.abs(self.v.x) / self.v.x or 0
		local ty = math.abs(self.v.y) > 0 and self.points * math.abs(self.v.y) / self.v.y or 0
		print(tx, ty)
		-- self.x = (self.x + (self.v.x + tx) * dt) % 64
		-- self.y = (self.y + (self.v.y + ty) * dt) % 48
		move(self, dt, tx, ty)
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
	c = {0, 250/C, 250/C, 255/C},

	update = function(self, dt)
		self.s = 1 / math.max(0.5, math.cos(time * 3)) / 2 * 0.75
	end,

	spawn = function(self)
		self.x = math.random(0, 64 - 1)
		self.y = math.random(0, 48 - 1)
	end,
}
local bullets = {
	all = {},
	spawn = function(self, x, y, vx, vy)
		local bullet = {
			x = x,
			y = y,
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
		self:set_tile(get_x(player), get_y(player), player.s, player.c)
		for i, b in ipairs(bullets.all) do
			self:set_tile(get_x(b), get_y(b), b.s, b.c)
		end
	end,

	draw = function(self)
		local c = {0, 48/255, 0, 255/C}
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

function move(o, dt, tx, ty)
	tx = tx or 0
	ty = ty or 0
	o.x = (o.x + (o.v.x + tx) * dt) % 64
	o.y = (o.y + (o.v.y + ty) * dt) % 48
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
		spawn_bullet()
	end
end

function check_player_hit()
	for i, b in ipairs(bullets.all) do
		if collides(player, b) then
			print('player hit')
		end
	end
end

function spawn_bullet()
	local vx = player.v.y
	local vy = -player.v.x
	local x = player.x + (math.abs(vx) > 0 and math.abs(vx) / vx * 2 or 0)
	local y = player.y + (math.abs(vy) > 0 and math.abs(vy) / vy * 2 or 0)
	-- print('spawning bullet at ', x, y, vx, vy)
	-- print('player', player.x, player.y, player.v.x, player.v.y)
	bullets:spawn(x, y, vx, vy)
end

function love.load()
	time = 0
	math.randomseed(os.time())
	grid:load()
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
	bullets:update(dt)
	check_player_hit()
	grid:update(dt)
end

function love:draw()
	grid:draw()
end
