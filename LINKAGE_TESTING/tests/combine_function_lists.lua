--- Combine function lists unit test.

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
local FS = require("tektite_core.table.meta")

--
--
--

local proto

do
	proto = {
		e = function()
			print("e!")
		end
	}
	
	local fs = FS.CombineFunctionLists({
		e = function()
			print("e2!")
		end
	}, proto)

	print("BASIC COMBINATION")

	fs.e()

	print("")
end

local proto2

do
	proto2 = FS.CombineFunctionLists({}, proto, {
		before = {
			e = function()
				print("e0!")
			end
		}
	})

	print("COMBINATION + BEFORE")

	proto2.e()

	print("")
end

do
	local fs = FS.CombineFunctionLists({
		e = function()
			print("e again!")
		end
	}, proto2)

	print("COMBINATION WITH SEQUENCE")

	fs.e()

	print("")
end

local proto3

do
	proto3 = {
		e = function()
			print("e, suppressed!")
		end,

		f = function()
			print("f!")
		end
	}

	local fs = FS.CombineFunctionLists({
		f = function()
			print("f again!")
		end
	}, proto3, {
		instead = {
			e = function()
				print("e for real")
			end
		}
	})
		

	print("COMBINATION + REPLACEMENT")

	fs.e()
	fs.f()

	print("")
end

do
	local fs = FS.CombineFunctionLists({}, proto3, {
		around = {
			e = function(other)
				print("e around")

				other()
			end
		}
	})
		

	print("COMBINATION WITH AROUND")

	fs.e()

	print("")
end