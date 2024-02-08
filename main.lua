local cos = math.cos
local sin = math.sin
local floor = math.floor
local random = math.random
local max = math.max
local sqrt = math.sqrt
local pi = math.pi
local file_mode = false
local frame_size_x = 800
local frame_size_y = 600
local frame_length = frame_size_x*frame_size_y
local depth_buffer = {}
local color_buffer = {}
local jump_buffer = {}
local function debug(...)
	io.stderr:write(..., '\n')
end
local function position_to_index(position_x, position_y)
	return position_x + frame_size_x*position_y
end
local function index_to_position(index)
	return index%frame_size_x, floor(index/frame_size_x)
end
local ffi = require('ffi')
ffi.cdef([[
#pragma pack(push, 1)
typedef struct {
	uint16_t type;
	uint32_t size;
	uint16_t reserved1;
	uint16_t reserved2;
	uint32_t offset;
	uint32_t header_size;
	int32_t width;
	int32_t height;
	uint16_t planes;
	uint16_t bits_per_pixel;
	uint32_t compression;
	uint32_t image_size;
	int32_t x_pixels_per_meter;
	int32_t y_pixels_per_meter;
	uint32_t colors_used;
	uint32_t colors_important;
} BMPHeader;
#pragma pack(pop)
]])
local header = ffi.new('BMPHeader', {
	type = 0x4D42; -- 'BM'
	size = 53 + 4*frame_length; -- File size
	reserved1 = 0;
	reserved2 = 0;
	offset = 54; -- Offset to image data
	header_size = 40; -- DIB Header size
	width = frame_size_x;
	height = frame_size_y;
	planes = 1;
	bits_per_pixel = 32; -- 32-bit BMP
	compression = 0; -- No compression
	image_size = 0; -- Size of image data (uncompressed)
	x_pixels_per_meter = 2835; -- 72 DPI
	y_pixels_per_meter = 2835; -- 72 DPI
	colors_used = 0; -- Number of colors in palette (0 for 32-bit)
	colors_important = 0; -- Number of important colors (usually ignored)
})
local capture_frame_when_file_mode = {}
capture_frame_when_file_mode[true] = function(frame_number)
	local buffer = ffi.new('uint32_t[?]', frame_length, color_buffer)
	local file = io.open(string.format('%04d', frame_number)..'.ppm', 'wb')
	file:write(ffi.string(header, ffi.sizeof(header)))
	file:write(ffi.string(buffer, ffi.sizeof(buffer)))
	file:close()
end
capture_frame_when_file_mode[false] = function()
	local buffer = ffi.new('uint32_t[?]', frame_length, color_buffer)
	io.write(ffi.string(header, ffi.sizeof(header)))
	io.write(ffi.string(buffer, ffi.sizeof(buffer)))
end
local capture_frame = capture_frame_when_file_mode[file_mode]
local function rgb_to_c32(r, g, b)
	local c32 = 0xff000000
	c32 = bit.bor(c32, bit.lshift(r, 16))
	c32 = bit.bor(c32, bit.lshift(g, 8))
	c32 = bit.bor(c32, b)
	return c32
end
local function draw_triangle(ox, oy, ix, iy, jx, jy)
	local oi = position_to_index(ox, oy)
	local ii = position_to_index(ox + ix, oy + iy)
	local ji = position_to_index(ox + jx, oy + jy)
	-- local pixel_position_x, pixel_position_y = index_to_position(pixel_index)
end
local function triq2_i(ox, oy, ax, ay, bx, by, px, py)
	return
		(bx*(oy - py) + by*(px - ox))/(ax*by - ay*bx),
		(ax*(py - oy) + ay*(ox - px))/(ax*by - ay*bx)
end
local function rasterize_triangle(ox, oy, ax, ay, bx, by)
	local gx = by/(ax*by - ay*bx)
	local gy = -ay/(ax*by - ay*bx)
	local py = oy
	while py < oy + max(ay, by) do
		py = py + 1
		local px = ox;
		local tx = (bx*(oy - py) + by*(px - ox))/(ax*by - ay*bx)
		local ty = (ax*(py - oy) + ay*(ox - px))/(ax*by - ay*bx)
		while px < ox + max(ax, bx) do
			px = px + 1
			if tx*ty and tx + ty < 1 then
				color_buffer[position_to_index(px, py)] = rgb_to_c32(255*ty, 0, 255*tx)
			end
			tx = tx + gx
			ty = ty + gy
		end
	end
end
local function square(x, y)
	return x*x + y*y
end
local function dot(ax, ay, bx, by)
	return ax*ay + bx*by
end
local function normalize(x, y)
	local l = sqrt(x*x + y*y)
	return x/l, y/l
end
for pixel_index = 0, frame_length do
	color_buffer[pixel_index] = 0 -- Transparent
end
local function complex_multiply(ax, ay, bx, by)
	return ax*bx - ay*by, ax*by + ay*bx
end
local function draw_boid(x, y, r)

end
local boids = {}
local boid = {}
local function get_closest_neighbor(inboid)
	local px, py = inboid.get_position()
	local l, v = 1, 1/0
	for i = 1, #boids do
		local otherboid = boids[i]
		if inboid ~= otherboid then
			local ox, oy = otherboid.get_position()
			local c = square(ox - px, oy - py)
			if c < v then
				v = c
				l = i
			end
		end
	end
	return boids[l]
end
local separation_distance = 5
local function get_forces(inboid)
	local fx, fy = 0, 0
	local px, py = inboid.get_position()
	local vx, vy = inboid.get_velocity()
	local l, v = 1, 1/0
	for i = 1, #boids do
		local otherboid = boids[i]
		if inboid ~= otherboid then
			local ox, oy = otherboid.get_position()
			local ovx, ovy = otherboid.get_velocity()
			local dx, dy = ox - px, oy - py
			local dis = sqrt(dx*dx + dy*dy)
			if dis == 0 then dis = 1 end
			fx = fx + dx/dis
			fy = fy + dy/dis
			fx = fx - 80*dx/(dis*dis)
			fy = fy - 80*dy/(dis*dis)
			fx = fx + 20*(ovx - vx)/dis
			fx = fx + 20*(ovx - vx)/dis
			local c = square(dx, dy)
			if c < v then
				v = c
				l = i
			end
		end
	end
	return fx, fy
end
function boid.new()
	local px
	local py
	if random() < 0.5 then
		px = random(200, 400)
		py = random(200, 400)
	elseif random() < 0.5 then
		px = random(350, 400)
		py = random(100, 300)
	else
		px = random(10, 60)
		py = random(500, 600)
	end
	local r = 0
	local R = 2*pi*random()
	local vx = cos(R)
	local vy = sin(R)
	local col = random(1, 2^32 - 1)
	local self = {}
	function self.step(dt)
		px = px + dt*vx
		py = py + dt*vy
		local fx, fy, afx, afy = get_forces(self)
		vx = vx + dt*(0.0001*fx)
		vy = vy + dt*(0.0001*fy)
		vx, vy = normalize(vx, vy)
		--vx = cos(r)
		--vy = sin(r)
		--local ox, oy = get_closest_neighbor(self).get_position()
		--local dx, dy = ox - px, oy - py
		--local dis = sqrt(dx*dx + dy*dy)
		--print(dis)
		--r = r + dot(-vy, vx, dx/dis, dy/dis)*dt
		-- obstacle avoidance
		-- velocity matching
		-- steer towards average flocks
		-- try to form an alpha lattice (same distance from each other)
	end
	function self.get_velocity()
		return vx, vy
	end
	function self.get_position()
		return px, py
	end
	function self.render()
		local i = floor(px)
		local j = floor(py)
		color_buffer[position_to_index(i, j)] = col
		--rasterize_triangle(floor(px), floor(py), floor(20*rx), floor(20*ry), floor(20*rx), -floor(20*ry))
	end
	return self
end
for i = 1, 300 do
	boids[i] = boid.new()
end
for frame_number = 1, 1000 do
	for pixel_index = 0, frame_length do
		color_buffer[pixel_index] = 0 -- Transparent
	end
	-- local ox, oy = complex_multiply(200, 300, 1, 0)
	-- local ax, ay = complex_multiply(50, 0, cos(0.1*frame_number), sin(0.1*frame_number))
	-- local bx, by = complex_multiply(0, 100, cos(0.1*frame_number), sin(0.1*frame_number))
	-- rasterize_triangle(floor(ox), floor(oy), floor(ax), floor(ay), floor(bx), floor(by))
	-- [[
	for i = 1, #boids do
		boids[i].step(4)
		boids[i].render()
	end
	capture_frame(frame_number)
end