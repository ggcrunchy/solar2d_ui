--- Menu entries.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Modules --
local menu = require("corona_ui.widgets.menu")

-- Corona globals --
local display = display

--
--
--

-- TEMP!
local Rect = RR
local NewNode = NN
local CommitRect = CR
-- /TEMP!

local function OneArg (title, how)
	return function()
		local group = Rect(title)

		NewNode(group, "delete")
		NewNode(group, "lhs", "x", how, "sync")
		NewNode(group, "rhs", "result", how)
		CommitRect(group, display.contentCenterX, 75)
	end
end

local function TwoArgs (title, how)
	return function()
		local group = Rect(title)

		NewNode(group, "delete")
		NewNode(group, "lhs", "x", how, "sync")
		NewNode(group, "lhs", "y", how)
		NewNode(group, "rhs", "result", how)
		CommitRect(group, display.contentCenterX, 75)
	end
end

--[[
local xyzw = { "x", "y", "z", "w" }

local float = { "x", xyzw }

local vec2 = {
	"x", xyzw,
	"y", xyzw
}

local vec3 = {
	"x", xyzw,
	"y", xyzw,
	"z", xyzw
}

local vec4 = {
	"x", xyzw,
	"y", xyzw,
	"z", xyzw,
	"w", xyzw
}

local dd = menu.Menu{
	columns = vec4, column_sep = 2, column_width = 35, is_dropdown = true
}
]]

do
	local input = Rect("Input")

	NewNode(input, "rhs", "texCoord", "vec2", "sync")
	CommitRect(input, 75, 75)
end

do
	local input = Rect("Output")

	NewNode(input, "lhs", "color", "vec4", "sync")
	CommitRect(input, display.contentWidth - 75, 75)
end

--[[
local dd = menu.Menu{
	columns = vec4, column_sep = 2, column_width = 35, is_dropdown = true
}
]]

local name_to_builder, builders = {}, {
	Common = {
		abs = OneArg("abs(x)", "?v"),
		ceil = OneArg("ceil(x)", "?v"),
		clamp = function() end,
		floor = OneArg("floor(x)", "?v"),
		fract = OneArg("fract(x)", "?v"),
		max = TwoArgs("max(x, y)", "?v"),
		min = TwoArgs("min(x, y)", "?v"),
		mod = function() end,
		sign = OneArg("sign(x)", "?v"),
		smoothstep = function() end,
		step = function() end
	}, Exponential = {
		exp = OneArg("exp(x)", "?v"),
		exp2 = OneArg("exp2(x)", "?v"),
		inversesqrt = OneArg("inversesqrt(x)", "?v"),
		log2 = OneArg("log2(x)", "?v"),
		pow = TwoArgs("pow(x, y)", "?v"),
		sqrt = OneArg("sqrt(x)", "?v")
	}, Geometric = {
		cross = function() end,
		distance = function() end,
		dot = function() end,
		faceforward = function() end,
		length = function() end,
		normalize = function() end,
		reflect = function() end,
		refract = function() end
	}, Miscellaneous = {
		degrees = OneArg("degrees(x)", "?v"),
		matrixCompMult = function() end,
		radians = OneArg("radians(x)", "?v")
	}, Operators = {
		["X + Y"] = TwoArgs("x + y", "?v"),
		["X - Y"] = TwoArgs("x - y", "?v"),
		["X * Y"] = TwoArgs("x * y", "?v"),
		["X / Y"] = TwoArgs("x / y", "?v"),
		["X < Y"] = function() end,
		["X <= Y"] = function() end,
		["X > Y"] = function() end,
		["X >= Y"] = function() end,
		["X == Y"] = function() end,
		["X != Y"] = function() end,
		["X && Y"] = function() end,
		["X || Y"] = function() end,
		["X ^^ Y"] = function() end,
		["B ? X : Y"] = function() end,
		["!X"] = function() end,
		["-X"] = OneArg("-x", "?v"),
		["++X"] = OneArg("++x", "?v"),
		["X++"] = OneArg("x++", "?v"),
		["(X)"] = OneArg("(x)", "?v"),
		["X.xyzw"] = function() end
	}, Trigonometric = {
		acos = OneArg("acos(x)", "?v"),
		asin = OneArg("asin(x)", "?v"),
		atan = OneArg("atan(x)", "?v"), -- TODO: y over x
		atan2 = TwoArgs("atan(y, x)", "?v"),
		cos = OneArg("cos(x)", "?v"),
		sin = OneArg("sin(x)", "?v"),
		tan = OneArg("tan(x)", "?v")
	}, ["Vector Relational"] = {
		all = function() end,
		any = function() end,
		greaterThan = function() end,
		greaterThanEqual = function() end,
		lessThan = function() end,
		lessThanEqual = function() end,
		equal = function() end,
		["not"] = function() end,
		notEqual = function() end
	}, Texture = {
		texture2D = function() end
	}
}

-- swizzle(1,2,3,4)
-- casts...
-- color(rgb,rgba)
-- arith, min, max, fract, step, smoothstep, abs, ceil, floor, mod, clamp
-- normalize(2,3,4), dot(...), distance(...), length(...)
-- cos, sin, etc.
-- texture sample

-- x, y, z, w
-- xx, xy, xz, xw, yx, yy, yz, yw, zx, zy, zz, zw, wx, wy, wz, ww
-- xxx, xxy, etc.
-- xyzw, etc.
-- ^^ picker wheels?
-- 2 from 1/1
-- 3 from 2/1, 1/2, 1/1/1
-- 4 from 1/1/1/1, 1/3, 2/2, 3/1, 1/2/1, 1/1/2, 2/1/1
-- matrices...
-- color picker
-- sample -> normal
-- convolve, etc.

-- wildcard logic...
	-- tend to have all objects of one type (T)
	-- exceptions are either floats, or float or T
	-- in a couple cases, we have a few in the float or T camp, but choosing so in one case streamlines the others
	-- more generally, once we pin down some T or float, the rest follow
	-- should be possible to narrow this down to a few rules
	-- the process ought to be reversible, i.e. when all relevant nodes go vacant, re-wildcardify

-- OneToOneVector(name, code) -- T -> T
-- TwoToOneVector(name, code) -- T, T -> T
-- OneThenFloatableVector(name, code) -- T, float | T -> T: max(), min(), mod()
-- smoothstep()
-- clamp()
-- mix()
-- faceforward()
-- refract()
-- cross()
-- length()
-- TwoToFloatVector(name, code) -- T, T -> float: distance(), dot()
-- texture2D() etc.
-- matrix from etc.
-- vector from etc.
-- decompose matrix, vector as etc.

local pre_columns = {}

for cname, group in pairs(builders) do
	local column = { name = cname }

	for name, builder in pairs(group) do
		column[#column + 1] = name
		name_to_builder[name] = builder
	end

	table.sort(column)

	pre_columns[#pre_columns + 1] = column
end

table.sort(pre_columns, function(c1, c2) return c1.name < c2.name end)

local columns = {}

for _, column in ipairs(pre_columns) do
	columns[#columns + 1] = column.name
	columns[#columns + 1] = column

	column.name = nil
end

local get_name = menu.Menu{ columns = columns }

get_name:addEventListener("menu_item", function(event)
	local name = columns[event.column * 2][event.index]
	local builder = name_to_builder[name]

	builder()
end)