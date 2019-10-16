--- UI cursor functionality.

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
local format = string.format
local gmatch = string.gmatch
local sub = string.sub

-- Modules --
local layout = require("corona_ui.utils.layout")

-- Corona globals --
local display = display

-- Cached module references --
local _GetPosition_XY_

-- Exports --
local M = {}

--
--
--

--
local function GetChar (text, pos)
	return sub(text, pos, pos)
end

--
local function GetWidth (proxy, text)
	proxy.text = text

	return proxy.width
end

--
local function ComputeOffset (proxy, penult, last)
	local pw = GetWidth(proxy, penult)
	local both_w = pw + GetWidth(proxy, last)
	local last2_w = GetWidth(proxy, penult .. last)

	return last2_w - both_w, pw
end

--
local function GetOffset (offsets, proxy, text, pos, size, sep)
	sep = sep or ";"

	local penult, last, pw = GetChar(text, pos), GetChar(text, pos + 1)
	local key = format("%i%s%s%s%s", size, sep, penult, sep, last)
	local koff = offsets[key]

	if koff then
		return koff
	else
		return ComputeOffset(proxy, penult, last)
	end
end

-- --
local Offsets = {}

-- --
local Proxies = {}

--- DOCME
-- @tparam TextObject str
-- @uint pos
-- @string[opt=";"] sep
-- @treturn uint P
function M.GetOffset (str, pos, sep)
	local text = str.text
	local n = #text

	if n == 0 or pos == 0 then
		return 0
	else
		local proxy, size = Proxies[str], str.size

		proxy.size = size

		if pos >= n then
			return GetWidth(proxy, text)
		else
			local koff, pw = GetOffset(Offsets[str], proxy, text, pos, size, sep)

			if pos > 1 or not pw then
				pw = GetWidth(proxy, sub(text, 1, pos))
			end

			return pw + koff
		end
	end
end

--- DOCME
-- @tparam TextObject str
-- @number x
-- @number y
-- @string[opt=";"] sep
-- @treturn uint P
function M.GetPosition_XY (str, x, y, sep)
	local left = layout.LeftOf(str)

	if x < left then
		return 0
	else
		local proxy, size, text = Proxies[str], str.size, str.text

		proxy.size = size

		if x >= layout.RightOf(str) then
			return GetWidth(proxy, text)
		else
			x = x - left

			local pos, substr, prev = 0, ""

			for char in gmatch(text, ".") do
				if prev then
					substr = substr .. char

					local w = GetWidth(proxy, substr) + ComputeOffset(proxy, prev, char)

					if x < w then
						return pos
					else
						pos = pos + 1
					end
				end

				prev = char
			end

			return pos
		end
	end
end

--- DOCME
-- @tparam TextObject str
-- @number x
-- @number y
-- @string[opt=";"] sep
-- @treturn uint P
function M.GetPosition_GlobalXY (str, x, y, sep)
	x, y = str.parent:contentToLocal(x, y)

	return _GetPosition_XY_(str, x, y, sep)
end

--- DOCME
-- @tparam TextObject str
-- @treturn ?|TextObject|nil X
function M.GetProxy (str)
	return Proxies[str]
end

--
local function Cleanup (event)
	Offsets[event.target], Proxies[event.target] = nil
end

--
local function AuxNewText (func, ...)
	local str, proxy = func(...), func(...)

	Offsets[str], Proxies[str], proxy.isVisible = {}, proxy, false

	str:addEventListener("finalize", Cleanup)

	return str, proxy
end

--- DOCME
-- @param ...
-- @treturn TextObject str
-- @treturn TextObject proxy
function M.NewEmbossedText (...)
	return AuxNewText(display.newEmbossedText, ...)
end

--- DOCME
-- @param ...
-- @treturn TextObject str
-- @treturn TextObject proxy
function M.NewText (...)
	return AuxNewText(display.newText, ...)
end

_GetPosition_XY_ = M.GetPosition_XY

return M