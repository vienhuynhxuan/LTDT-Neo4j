//step 1
with [1, 2, 5] as selection
match (v:Vertex)
where v.number in selection
with collect(v) as vertices
unwind vertices as v1
with
	v1,
    [v in vertices where v.number > v1.number] as v2s,
    vertices
unwind v2s as v2
call algo.shortestPath.stream(
	v1,
    v2,
    'cost',
    {relationshipQuery: 'LINK_TO'}
)
yield nodeId, cost
//step 2
with
	v1,
    v2,
    max(cost) as totalCost,
    collect(nodeId) as shortestHopNodeIds,
    vertices
merge (v1)-[r:SHORTEST_ROUTE_TO]-(v2)
set r.cost = totalCost
set r.shortestHopNodeIds = shortestHopNodeIds
with
	v1,
    v2,
    (size(vertices) - 1) as level,
    vertices
call apoc.path.expandConfig(
	v1,
    {
    	relationshipFilter: 'SHORTEST_ROUTE_TO',
        minLevel: level,
        maxLevel: level,
        whitelistNodes: vertices,
        terminatorNodes: [v2],
        uniqueness: 'NODE_PATH'
    }
)
YIELD path
WITH 
	nodes(path) as orderedVertices,
	[n in nodes(path) | id(n)] as ids, 
	reduce(cost = 0, x in relationships(path) | cost + x.cost) as totalCost,
	[r in relationships(path) | r.shortestHopNodeIds] as shortestRouteNodeIds 
ORDER BY totalCost LIMIT 1 
//step3
UNWIND range(0, size(orderedVertices) - 1) as index
UNWIND shortestRouteNodeIds[index] as shortestHopNodeId
WITH
	orderedVertices,
    totalCost,
    index,
    CASE
    	WHEN shortestRouteNodeIds[index][0] = ids[index]
        THEN tail(collect(shortestHopNodeId))
        ELSE tail(reverse(collect(shortestHopNodeId)))
        END as orderedHopNodeIds
ORDER BY index
UNWIND orderedHopNodeIds as orderedHopNodeId
MATCH (v:Vertex) where id(v) = orderedHopNodeId
RETURN
	[v in orderedVertices | v.number] as Id,
    [orderedVertices[0].number] + collect(v.number) as vertexRoute,
    totalCost
