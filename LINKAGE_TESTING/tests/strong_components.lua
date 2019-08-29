--- Strong components test.

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

local strong_components = require("tests.shader_graph.strong_components")

local G = {
	{ what = "A" }, -- 1
	{ what = "2" }, -- 2
	{ what = "C" }, -- 3
	{ what = ":::" }, -- 4
	{ what = 3445 }, -- 5
	{ what = 3434 }, -- 6
	{ what = "DFDF" }, -- 7
	{ what = "+" }, -- 8
	{ what = {} }, -- 9
	{ what = function() end }, -- 10
	{ what = "3334" }
}

table.insert(G[1], 2) -- A -> 2
table.insert(G[1], 3) -- A -> 2, C
table.insert(G[3], 1) -- A -> 2, <-> C

table.insert(G[3], 4) -- A -> 2, <-> C -> :::
table.insert(G[4], 5) -- A -> 2, <-> C -> ::: -> 5
table.insert(G[5], 4) -- A -> 2, <-> C -> ::: <-> 5

table.insert(G[7], 8) -- DFDF -> +
table.insert(G[8], 9) -- DFDF -> + -> {}
table.insert(G[9], 10) -- DFDF -> + -> {} -> func()
table.insert(G[10], 11) -- DFDF -> + -> {} -> func() -> 3334
table.insert(G[11], 10) -- DFDF -> + -> {} -> func() <-> 3334
table.insert(G[11], 7) -- <3334> -> DFDF -> + -> {} -> func() <-> 3334 -> <DFDF>

local ids, n = strong_components.Gabow(G)

print("# strong components", n)

for i = 0, n - 1 do
	print("Component: ", i)
	print("")
	
	for j = 1, #G do
		if ids[j] == i then
			print("    ", G[j].what)
		end
	end
end