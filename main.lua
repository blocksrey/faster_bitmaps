local file_mode = false

local frame_size_x = 800
local frame_size_y = 600
local frame_length = frame_size_x*frame_size_y

local depth_buffer = {}
local color_buffer = {}
local jump_buffer = {}


local function debug(...)
	io.stderr:write(..., "\n")
end

local function position_to_index(position_x, position_y)
	return position_x + frame_size_x*position_y
end

local function index_to_position(index)
	return index%frame_size_x, math.floor(index/frame_size_x)
end






local ffi = require("ffi")

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

local header = ffi.new("BMPHeader", {
	type = 0x4D42; -- "BM"
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
	local buffer = ffi.new("uint32_t[?]", frame_length, color_buffer)

	local file = io.open(string.format("%04d", frame_number)..".ppm", "wb")
	file:write(ffi.string(header, ffi.sizeof(header)))
	file:write(ffi.string(buffer, ffi.sizeof(buffer)))
	file:close()
end

capture_frame_when_file_mode[false] = function()
	local buffer = ffi.new("uint32_t[?]", frame_length, color_buffer)

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

	--local pixel_position_x, pixel_position_y = index_to_position(pixel_index)
end

local function triq2_i(ox, oy, ax, ay, bx, by, px, py)
	return
		(bx*(oy - py) + by*(px - ox))/(ax*by - ay*bx),
		(ax*(py - oy) + ay*(ox - px))/(ax*by - ay*bx)
end

local function rasterize_triangle(ox, oy, ax, ay, bx, by)
	local gx =  by/(ax*by - ay*bx)
	local gy = -ay/(ax*by - ay*bx)

	local py = oy

	while py < oy + math.max(ay, by) do
		py = py + 1

		local px = ox;

		local tx = (bx*(oy - py) + by*(px - ox))/(ax*by - ay*bx)
		local ty = (ax*(py - oy) + ay*(ox - px))/(ax*by - ay*bx)

		while px < ox + math.max(ax, bx) do
			px = px + 1

			if tx*ty and tx + ty < 1 then
				color_buffer[position_to_index(px, py)] = rgb_to_c32(255*ty, 0, 255*tx)
			end

			tx = tx + gx
			ty = ty + gy
		end
	end
end




for pixel_index = 0, frame_length do
	color_buffer[pixel_index] = 0 -- Transparent
end





local function complex_multiply(ax, ay, bx, by)
	return ax*bx - ay*by, ax*by + ay*bx
end



for frame_number = 1, 100 do
	for pixel_index = 0, frame_length do
		color_buffer[pixel_index] = 0 -- Transparent
	end

	local ox, oy = complex_multiply(200, 300, 1, 0)
	local ax, ay = complex_multiply(50, 0, math.cos(0.1*frame_number), math.sin(0.1*frame_number))
	local bx, by = complex_multiply(0, 100, math.cos(0.1*frame_number), math.sin(0.1*frame_number))

	rasterize_triangle(math.floor(ox), math.floor(oy), math.floor(ax), math.floor(ay), math.floor(bx), math.floor(by))

	--[[
	local pixel_index = 1

	while pixel_index <= frame_length do
		if jump_buffer[pixel_index] then
			pixel_index = jump_buffer[pixel_index]
		end

		color_buffer[pixel_index] = rgb_to_c32(20, 0, 0)

		pixel_index = pixel_index + 1
	end
	]]

	capture_frame(frame_number)
end