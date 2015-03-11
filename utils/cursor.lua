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

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- --
local Offsets = setmetatable({}, { __mode = "k" })

--
local function GetChar (text, pos)
	return sub(text, pos, pos)
end

--
local function GetKey (size, penult, last, sep)
	return format("%i%s%s%s%s", size, sep, penult, sep, last)
end

--
local function GetWidth (proxy, text)
	proxy.text = text

	return proxy.width
end
TT={}
--
local function GetOffset (offsets, proxy, key, most, full, last)--text, proxy, key, penult, last, pos)
	local koff, most_w = offsets[key], GetWidth(proxy, most)--GetWidth(proxy, sub(text, 1, pos))

--	if not koff then
		local full_w, last_w = GetWidth(proxy, full), GetWidth(proxy, last)--sub(text, 1, pos + 1)), GetWidth(proxy, last)
		local most_w_offseted = full_w - last_w
TT[1]={"MOST, W", most, most_w}
TT[2]={"FULL, W", full, full_w}
TT[3]={"MOST_W_OFF", most_w_offseted}
		koff = most_w_offseted - most_w
--print("KOFF", penult, last, koff, key, pos)
		offsets[key] = koff
--	end

	return koff
--	return most_w - koff
end

--- DOCME
function M.GetPosition (str, pos, proxy, sep)
	local text = str.text
	local n = #text
if false then--not AAA then
	AAA=true
local ca, cz = string.byte("a"), string.byte("z")
local CA, CZ = string.byte("A"), string.byte("Z")
local nn=0
for ii = 1, 2 do
	local ilo, ihi
	if ii == 1 then
		ilo, ihi = ca, cz
	else
		ilo, ihi = CA, CZ
	end
	for i = ilo, ihi do
		local ic = string.char(i)
		local iw = GetWidth(proxy, ic)
		for jj = 1, 2 do
			local jlo, jhi
			if jj == 1 then
				jlo, jhi = ca, cz
			else
				jlo, jhi = CA, CZ
			end
			for j = jlo, jhi do
				local jc = string.char(j)
				local jw = GetWidth(proxy, jc)
				local sumw = GetWidth(proxy, ic .. jc)
				if iw + jw ~= sumw then
					print("DISCREP at", ic, jc, iw, jw, sumw)
					nn=nn+1
				end
			end
		end
	end
end
print("N DISC", nn)
print("WSP", GetWidth(proxy, " "))
end
	if n == 0 then
		return 0
	else
		local offsets, size, penult, last, most, full, a, b = Offsets[str], str.size

		proxy.size = size

		--
		if pos == 0 then
			return 0
			--[[
			penult, last = " ", GetChar(text, 1)
			most, a, b = last, " ", last]]
		elseif pos >= n then
		return GetWidth(proxy, text)
		--[[
			penult, last = GetChar(text, n), " "
			most, a, b = text, text, " "
			]]
		else
			penult, last, most = GetChar(text, pos), GetChar(text, pos + 1), sub(text, 1, pos)
			full = sub(text, 1, pos + 1)
		end

		--
		local key, most_w = GetKey(size, penult, last, sep or ";"), GetWidth(proxy, most)
local aa=offsets[key]
		local koff = offsets[key] or GetOffset(offsets, proxy, key, most, full or (a .. b), last)
if true then--not aa then
print("POS", pos)
print("KEY", key)
for i = 1, #TT do
	print(unpack(TT[i]))
end
print("KOFF, POSITION", koff, most_w - koff)
print("PENULT, LAST", penult, last)
print("CURSOR", most_w - koff)
print("")
end
		return most_w + koff -- tOffset(offsets, text, proxy, key, penult, last, pos)
	end
end

--
local function AuxNewText (func, ...)
	local str, proxy = func(...), func(...)

	Offsets[str], proxy.isVisible = {}, false

	return str, proxy
end

--- DOCME
function M.NewEmbossedText (...)
	return AuxNewText(display.newEmbossedText, ...)
end

--- DOCME
function M.NewText (...)
	return AuxNewText(display.newText, ...)
end

-- Export the module.
return M