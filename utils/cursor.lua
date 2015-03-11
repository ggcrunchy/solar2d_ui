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
local sub = string.sub

-- Exports --
local M = {}

-- --
local FontData = setmetatable({}, { __mode = "k" })

--
local function GetWidth (proxy, text)
	proxy.text = text

	return proxy.width
end

--- DOCME
function M.GetCaretPosition (str, pos, proxy, sep)
	local size, text = str.size, str.text
	local data = FontData[str] or {}

	if size ~= proxy.size then
		proxy.size = size
	end

	FontData[str] = data

	if pos >= n then
		return GetWidth(proxy, text)
	else
		sep = sep or ";"

		local penult, last = sub(text, pos, pos), sub(text, pos + 1, pos + 1)
		local key = format("%i%s%s%s%s", size, sep, penult, sep, last)
		local koff, w = data[key], GetWidth(proxy, sub(text, 1, pos))

		if not koff then
			local wmc = GetWidth(proxy, sub(text, 1, pos + 1)) - GetWidth(proxy, last)

			koff = wmc - w
			data[key] = koff
		end

		return w + koff
	end
end

--- DOCME
function M.SetFont (str, proxy, font, size)
	str.font, proxy.font, FontData[str] = font, font

	if size then
		str.size, proxy.size = size, size
	end
end

-- Export the module.
return M