--- Implements a small DSL on top of the layout system, for formatting purposes.

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

-- Standard library imports --
local assert = assert
local ceil = math.ceil
local gsub = string.gsub
local sub = string.sub
local tonumber = tonumber

-- Modules --
local layout = require("corona_ui.utils.layout")

-- Corona globals --
local display = display

-- Cached module references --
local _EvalDims_
local _EvalPos_

-- Exports --
local M = {}

--
local function ParseNumber (arg, dim, can_fail)
	local num = tonumber(arg)

	if num then
		return num
	else
		local ok = sub(arg, -1) == "%"

		assert(ok or can_fail, "Invalid argument")

		num = ok and tonumber(sub(arg, 1, -2))

		return num and num * display[dim] / 100
	end
end

--- DOCME
function M.EvalDims (w, h)
	w = w and ceil(ParseNumber(w, "contentWidth")) or nil
	h = h and ceil(ParseNumber(h, "contentHeight")) or nil

	return w, h
end

-- IDEA: EvalDims_Object... could look for, say, text fields and calculate widths relative to those

-- --
local Command, Num1, Num2

-- --
local Dim

-- --
local N

--
local function RepToken (token)
	if not Command then
		Command = token
	else
		local num = ParseNumber(token, Dim)

		if Num1 then
			Num2 = num
		else
			Num1 = num
		end

		N = N + 1
	end
end

--
local function AuxEvalCoord (arg, choices, dim)
	Dim, N, Command, Num1, Num2 = dim, 0

	gsub(arg, "[^%s]+", RepToken, 3)

	--
	local choice = assert(choices[Command], "Unrecognized or missing command")

	assert(N <= choice[2], "Too many arguments")

	return choice[1]
end

--
local function EvalBasic (arg, choices, dim)
	return ParseNumber(arg, dim, true) or AuxEvalCoord(arg, choices, dim)(Num1, Num2)
end

--
local function ReverseBasic (func)
	return {
		function(delta)
			return func("100%", delta)
		end, 1
	}
end

-- --
local ChoicesX = {
	center = false, -- NYI
	from_right = ReverseBasic(layout.LeftOf),
	left_of = { layout.LeftOf, 2 },
	right_of = { layout.RightOf, 2 }
}

-- --
local ChoicesY = {
	center = false, -- NYI
	from_bottom = ReverseBasic(layout.Above),
	above = { layout.Above, 2 },
	below = { layout.Below, 2 }
}

--- DOCME
function M.EvalPos (x, y)
	x = x and EvalBasic(x, ChoicesX, "contentWidth")
	y = y and EvalBasic(y, ChoicesY, "contentHeight")

	return x or nil, y or nil
end

--
local function AuxProcessWidgetParams (params, t)
	local x, y, w, h = params.x, params.y, _EvalDims_(params.width, params.height)

	t.left, t.top, t.x, t.y = _EvalPos_(not x and params.left, not y and params.top)
	t.width, t.height = w or t.width, h or t.height

	return t, x, y
end

--- DOCME
function M.ProcessWidgetParams (params, t)
	local x, y

	if params then
		t, x, y = AuxProcessWidgetParams(params, t or {})
	end

	return t, x, y
end

--- DOCME
function M.ProcessWidgetParams_InPlace (params)
	local t, x, y

	if params then
		t, x, y = AuxProcessWidgetParams(params, params)
	end

	return t, x, y
end

--
local function EvalPut (object, arg, choices, coord)
	if arg then
		local dim = coord == "x" and "contentWidth" or "contentHeight"
		local num = ParseNumber(arg, dim, true)

		if num then
			object[coord] = num
		else
			AuxEvalCoord(arg, choices, dim)(object, Num1, Num2)
		end
	end
end

--
local function ReversePut (func)
	return {
		function(object, delta)
			func(object, "100%", delta)
		end, 1
	}
end

-- --
local PutChoicesX = {
	center = false, -- NYI
	from_right = ReversePut(layout.PutLeftOf),
	from_right_align = ReversePut(layout.RightAlignWith),
	left_align = { layout.LeftAlignWith, 2 },
	left_of = { layout.PutLeftOf, 2 },
	right_align = { layout.RightAlignWith, 2 },
	right_of = { layout.PutRightOf, 2 }
}

-- --
local PutChoicesY = {
	center = false, -- NYI
	above = { layout.PutAbove, 2 },
	bottom_align = { layout.BottomAlignWith, 2 },
	below = { layout.PutBelow, 2 },
	from_bottom = ReversePut(layout.PutAbove),
	from_bottom_align = ReversePut(layout.BottomAlignWith),
	top_align = { layout.TopAlignWith, 2 }
}

--- DOCME
function M.PutObjectAt (object, x, y)
	EvalPut(object, x, PutChoicesX, "x")
	EvalPut(object, y, PutChoicesY, "y")
end

-- Cache module members.
_EvalDims_ = M.EvalDims
_EvalPos_ = M.EvalPos

-- Export the module.
return M