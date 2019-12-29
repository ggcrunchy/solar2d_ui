--- Utility for depth-first searches.

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
local setmetatable = setmetatable

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.GetPreorderNumber (algorithm, w)
    return algorithm.GetPreorderNumber(w)
end

local PreorderMT = { __mode = "k" }

local function DefAfterVisit () end

--- DOCME
function M.NewAlgorithm (opts)
    local algorithm = {}

    local preorder, low = setmetatable({}, PreorderMT)

    function algorithm.HasVisited (index)
        local pn = preorder[index] or low

        return pn > low, pn
    end

    function algorithm.GetPreorderNumber (w)
        return preorder[w] or low
    end

    local count = 0

    function algorithm.AddBeforeVisit (w)
        count = count + 1
        preorder[w] = count
    end

    function algorithm.Begin ()
        low = count
    end

	algorithm.DoAfterVisit = opts and opts.after_visit or DefAfterVisit -- n.b. can fall through

    return algorithm
end

--- DOCME
function M.VisitAdjacentVertices (algorithm, visit, revisit, graph, index, adj_iter, arg)
    for _, t in adj_iter(graph, index, arg) do
        local visited, preorder = algorithm.HasVisited(t)

        if visited then
            revisit(t, preorder, arg)
        else
            algorithm.AddBeforeVisit(t)
            visit(graph, t, adj_iter, arg)
			algorithm.DoAfterVisit(t, arg)
        end
    end
end

--- DOCME
function M.VisitAdjacentVertices_Once (algorithm, visit, graph, index, adj_iter, arg)
    for _, t in adj_iter(graph, index, arg) do
        if not algorithm.HasVisited(t) then
            algorithm.AddBeforeVisit(t)
            visit(graph, t, adj_iter, arg)
			algorithm.DoAfterVisit(t, arg)
        end
    end
end

local function DefAdjacencyIter (graph, index)
    return ipairs(graph[index])
end

local function AuxDefTopLevelIter (top_level_vertices, index)
    index = index + 1

    return top_level_vertices[index] and index, top_level_vertices, index
end

local function DefTopLevelIter (top_level_vertices)
    return AuxDefTopLevelIter, top_level_vertices, 0
end

local function AuxRoot (x, ok)
	if ok then
		return false, nil, x
	end
end

local function Root (root_vertex)
	return AuxRoot, root_vertex, true
end

local function AuxVisit (algorithm, visit, top_level_vertices, adj_iter, tl_iter, arg)
    adj_iter = adj_iter or DefAdjacencyIter

    algorithm.Begin()

    for _, graph, index in tl_iter(top_level_vertices, arg) do
        if not algorithm.HasVisited(index) then
            algorithm.AddBeforeVisit(index)
            visit(graph, index, adj_iter, arg)
			algorithm.DoAfterVisit(index)
        end
    end
end

--- DOCME
function M.VisitRoot (algorithm, visit, root, opts, arg)
	AuxVisit(algorithm, visit, root, opts and opts.adjacency_iter, Root, arg)
end

--- Perform a depth-first search, starting with a set of top-level vertices. Each vertex
-- must have some user-defined "index" that uniquely identifies it.
-- @param top_level_vertices Vertices to search.
-- @ptable[opt] opts Computation options, which may include:
--
-- * **adjacency\_iter**: If present, called as `for _, neighbor_index in adjacency_iter(graph, vertex_index) do`
-- to iterate through a vertex's neighbors, with _graph_ coming from the top level.
--
-- The default assumes that _top\_level\_vertices_ is an array such as `{}, {1,3}, {1,2}`, where each table
-- is a vertex, a vertex's index is its position in this array, and each vertex's array
-- part consists of its neighbor indices.
-- * **top\_level\_iter**: If present, called as `for _, graph, vertex_index in top_level_iter(top_level_vertices) do`
-- to get the top-level vertices and the subgraphs to which each belongs.
--
-- The default assumes the same structure as *adjacency\_iter* and will walk the whole array,
-- supplying it as _graph_ at each step.
function M.VisitTopLevel (algorithm, visit, top_level_vertices, opts, arg)
    local adj_iter, tl_iter

    if opts then
        adj_iter, tl_iter = opts.adjacency_iter, opts.top_level_iter
    end

	AuxVisit(algorithm, visit, top_level_vertices, adj_iter or DefAdjacencyIter, tl_iter or DefTopLevelIter, arg)
end

return M