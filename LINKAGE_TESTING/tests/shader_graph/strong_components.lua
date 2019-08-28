--- This module provides some helpers to find strong components in a graph.

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
local ipairs = ipairs

-- Exports --
local M = {}

--
--
--

local Preorder, Low = {}

local function GetPreorderNumber (index)
    local pn = Preorder[index] or Low

    return pn > Low, pn
end

local Stack, Top = {}, 0

local Path, Length = {}, 0

local Count = 0

local function AuxBuild (graph, adj_iter, ncomps, ids, w)
	Count = Count + 1
	Preorder[w] = Count

	Stack[Top + 1], Top = w, Top + 1
	Path[Length + 1], Length = w, Length + 1

	for _, t in adj_iter(graph, w) do
		local visited, cur = GetPreorderNumber(t)

		if not visited then
			ncomps = AuxBuild(graph, adj_iter, ncomps, ids, t)
		elseif not ids[t] then -- visited, but not yet assigned to a component?
			for j = Length, 1, -1 do
				if Preorder[Path[j]] <= cur then
					Length = j

					break
				end
			end
		end
	end

	if Path[Length] == w then -- nothing left to explore?
		Length = Length - 1

		repeat
			local v = Stack[Top]

			ids[v], Top = ncomps, Top - 1
		until v == w -- w being what we pushed up top
	 
		return ncomps + 1
	else
		return ncomps -- component not yet complete
	end
end

local function DefAdjacencyIter (graph, index)
    return ipairs(graph[index])
end

local function AuxDefTopLevelIter (n, gi)
    gi = gi + 1

    return gi <= n and gi or nil, gi
end

local function DefTopLevelIter (graph)
    return AuxDefTopLevelIter, #graph, 0
end

--- DOCME
-- @tparam Graph graph
-- @ptable[opt] opts
-- @treturn table ids
-- @treturn uint ncomps
function M.Gabow (graph, opts)
	local ncomps, adj_iter, tl_iter, ids = 0

    if opts then
        adj_iter, tl_iter, ids = opts.adjacency_iter, opts.top_level_iter, opts.out
    end

    Low, adj_iter, ids = Count, adj_iter or DefAdjacencyIter, ids or {}

	for _, index in (tl_iter or DefTopLevelIter)(graph) do
		if not GetPreorderNumber(index) then
			ncomps = AuxBuild(graph, adj_iter, ncomps, ids, index)
		end
	end

	return ids, ncomps
end

--- DOCME
-- @ptable ids
-- @uint v
-- @uint w
-- @treturn boolean X
function M.StronglyReachable (ids, v, w)
	return ids[v] == ids[w]
end

return M