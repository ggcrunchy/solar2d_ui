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
local boxes = require("tests.shader_graph.boxes")
local code_gen = require("tests.shader_graph.code_gen")
local interface = require("tests.shader_graph.interface")
local menu = require("corona_ui.widgets.menu")

-- Corona globals --
local display = display

--
--
--

-- Exports --
local M = {}

--
--
--

local BoxGroup = display.newGroup()

local function DefZero (vtype)
	return vtype ~= "float" and vtype .. "(0.)" or "0."
end

local function OneArg (title, how, wildcard_type, scheme)
	return function()
		local group = interface.Rect(title, wildcard_type, title, scheme)

		interface.NewNode(group, "delete")
		interface.NewNode(group, "lhs", "x", how, "sync")
		interface.NewNode(group, "rhs", "result", how)
		interface.CommitRect(group, display.contentCenterX, 75)

		BoxGroup:insert(group)
	end
end

local X_Scheme = { x = DefZero }

local function OneArgWV (title)
	return OneArg(title, "?", "vector", X_Scheme)
end

local function TwoArgs (title, how, wildcard_type, scheme)
	return function()
		local group = interface.Rect(title, wildcard_type, title, scheme)

		interface.NewNode(group, "delete")
		interface.NewNode(group, "lhs", "x", how, "sync")
		interface.NewNode(group, "lhs", "y", how)
		interface.NewNode(group, "rhs", "result", how)
		interface.CommitRect(group, display.contentCenterX, 75)

		BoxGroup:insert(group)
	end
end

local XY_Scheme = { x = DefZero, y = DefZero }

local function TwoArgsWV (title)
	return TwoArgs(title, "?", "vector", XY_Scheme)
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

function M.Init ()

--[[
local dd = menu.Menu{
	columns = vec4, column_sep = 2, column_width = 35, is_dropdown = true
}
]]

local name_to_builder, builders = {}, {
	Common = {
		abs = OneArgWV("abs(x)"),
		ceil = OneArgWV("ceil(x)"),
		clamp = function() end, -- TODO: three args, two can be float | wild
		floor = OneArgWV("floor(x)"),
		fract = OneArgWV("fract(x)"),
		max = TwoArgsWV("max(x, y)"), -- TODO: y float | wild
		min = TwoArgsWV("min(x, y)"), -- TODO: ditto 
		mod = TwoArgsWV("mod(x, y)"), -- TODO: ditto
		sign = OneArgWV("sign(x)"),
		smoothstep = function() end, -- TODO: three args, two can be float | wild
		step = TwoArgsWV("step(x, y)") -- TODO: x float | wild
	}, Exponential = {
		exp = OneArgWV("exp(x)"),
		exp2 = OneArgWV("exp2(x)"),
		inversesqrt = OneArgWV("inversesqrt(x)"),
		log2 = OneArgWV("log2(x)"),
		pow = TwoArgsWV("pow(x, y)"),
		sqrt = OneArgWV("sqrt(x)")
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
		degrees = OneArgWV("degrees(x)"),
		matrixCompMult = function() end,
		radians = OneArgWV("radians(x)")
	}, Operators = {
		["X + Y"] = TwoArgsWV("x + y"),
		["X - Y"] = TwoArgsWV("x - y"),
		["X * Y"] = TwoArgsWV("x * y"),
		["X / Y"] = TwoArgsWV("x / y"),
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
		["-X"] = OneArgWV("-x"),
		["++X"] = OneArgWV("++x"),
		["X++"] = OneArgWV("x++"),
		["X.xyzw"] = function() end
	}, Trigonometric = {
		acos = OneArgWV("acos(x)"),
		asin = OneArgWV("asin(x)"),
		atan = OneArgWV("atan(x)"), -- TODO: y over x
		atan2 = TwoArgsWV("atan(y, x)"),
		cos = OneArgWV("cos(x)"),
		sin = OneArgWV("sin(x)"),
		tan = OneArgWV("tan(x)")
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
		-- ^^^ These might call for some cleverness, since we have two types to resolve but one
		-- determines the other, i.e. vecX -> bvecX and vice versa; any hard type reachable by
		-- either of the two should hold the whole thing together; the bvec part is always the
		-- output, so maybe some sort of ghost "transformer" object in between?
		-- Nesting the bvec node in the vec one might be worth considering too, as that case will
		-- probably come up eventually
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

local get_name = menu.Menu{ columns = columns, column_width = 135 }

get_name:addEventListener("menu_item", function(event)
	local name = columns[event.column * 2][event.index]
	local builder = name_to_builder[name]

	builder()
end)

local h = get_name:GetHeadingHeight()
local cont = display.newContainer(display.contentWidth, display.contentHeight - h)

cont.anchorChildren = false
cont.anchorX, cont.anchorY = 0, 0

cont:insert(BoxGroup)
cont:insert(interface.GetBackGroup())
cont:translate(0, h)
cont:toBack()

interface.SetDragDimensions(nil, cont.height)

do
	local input = interface.Rect("Input")

	interface.NewNode(input, "rhs", "texCoord", "vec2", "sync")
	interface.CommitRect(input, 75, 75)
	code_gen.SetExportedName(input, "texCoord")

	BoxGroup:insert(input)
end

do
	local output = interface.Rect("Output", nil, "return color;", { color = "vec4(1.)" })

	interface.NewNode(output, "lhs", "color", "vec4", "sync")
	interface.CommitRect(output, display.contentWidth - 75, 75)
	boxes.PutLastInLine(output)

	BoxGroup:insert(output)
end

end

return M