def _main(
        mv_dependency_graph, # Input: varchar[], where each element
                             # is a string of the form
                             # "module==version->dependency==version"
        ):                   # Returns:
                             # varchar[][], where each element is an array of
                             # strings of the form "module==version"
    """\
    Return all versions combos of each module so
    that they can form a valid graph.
    """
    from functools import lru_cache
    from typing import Set, List, Tuple, Dict, Generator, TypeVar
    # Helper types:
    Module = str
    Version = str
    VersionedModule = Tuple[Module, Version]
    Dependency = Module
    VersionedDependency = VersionedModule
    Digraph = Dict[Module, List[Dependency]]
    VersionedDigraph = Dict[VersionedModule, List[VersionedDependency]]

    GenericGraph = TypeVar("GenericGraph", Digraph, VersionedDigraph)

    #Helper functions:
    def _split_mv(_mv: str) -> VersionedModule:
        m_str, v_str = _mv.split("==")[:2]
        return Module(m_str), Version(v_str)

    def _parse_edge(_edge: str) -> Tuple[VersionedModule, VersionedDependency]:
        module, dependency = _edge.split("->")[:2]
        return _split_mv(module), _split_mv(dependency)

    def _unique_versioned_modules(_graph: VersionedDigraph
            ) -> Set[VersionedModule]:
        mvs = set()
        for module, dependencies in _graph.items():
            mvs.add(module)
            mvs.update(dependencies)
        return mvs

    @lru_cache(maxsize=None)
    def _node_dependencies(node: VersionedModule) -> Set[VersionedDependency]:
        node_dependencies = set(VERSIONED_GRAPH.get(node, []))
        return node_dependencies

    @lru_cache(maxsize=None)
    def _module_dependencies(module: Module) -> Set[Dependency]:
        module_dependencies = set(GRAPH.get(module, []))
        return module_dependencies

    def _parse_graph(_graph: List[str]) -> VersionedDigraph:
        edges = [_parse_edge(edge) for edge in _graph]
        graph = {}
        for module, dependency in edges:
            graph.setdefault(module, []).append(dependency)
        return graph

    def _unvers_graph(_graph: VersionedDigraph) -> Digraph:
        graph = {}
        for mv, dsv in _graph.items():
            graph.setdefault(mv[0], []).extend(d for d, _ in dsv)
        return graph

    def _module_versions(_uvm: Set[VersionedModule]
            ) -> Dict[Module, List[Version]]:
        versions = {}
        for module, version in _uvm:
            versions.setdefault(module, []).append(version)

        # Sort versions as newest first.
        for vs in versions.values():
            vs.sort(reverse=True)
        return versions

    def _join_subgraphs(_subgraphs: List[VersionedDigraph]
            ) -> VersionedDigraph:
        graph = {}
        for subgraph in _subgraphs:
            for module, dependencies in subgraph.items():
                graph.setdefault(module, []).extend(dependencies)
        return graph

    def _validate_subgraph(_subgraph: VersionedDigraph) -> bool:
        # Validate that the subgraph is valid.
        # That means that it contains a version of each unique module.
        return set(m for m, _ in _subgraph) == set(unique_modules) | {root}

    def _get_subgraph_versions(_subgraph: VersionedDigraph
            ) -> Dict[Module, Version]:
        # Return a dict of modules and their versions.
        versions: Dict[Module, Version] = {}
        for m,v in _unique_versioned_modules(_subgraph):
            versions[m] = v
        return versions

    def _order_from_root(_subgraph: VersionedDigraph,
                         root: VersionedModule) -> List[VersionedModule]:
        # Return a list of modules ordered from the root.
        # The root is the only module that does not have dependencies.
        # The rest of the modules are ordered by their dependencies.
        # If there is a cycle, raise an error.
        ordered: List[VersionedModule] = [root]
        nodes = set(_subgraph.keys())
        nodes.remove(root)
        raise NotImplementedError

    def _invert_graph(_graph: GenericGraph) -> GenericGraph:
        # Invert the (versioned) graph.
        # That means that the dependencies become the modules,
        # and the modules become the dependencies.
        inverted_graph = {}
        for module, dependencies in _graph.items():
            for dependency in dependencies:
                inverted_graph.setdefault(dependency, []).append(module)

        # Looks like pyright does not support generic type narrowing.
        return inverted_graph  # type:ignore

    # Parse input graph:
    VERSIONED_GRAPH: VersionedDigraph = _parse_graph(mv_dependency_graph)
    GRAPH: Digraph = _unvers_graph(VERSIONED_GRAPH)
    unique_versioned_modules = _unique_versioned_modules(VERSIONED_GRAPH)
    unique_modules = _module_versions(unique_versioned_modules)

    # Solution functions:
    def _leaf_modules(_graph: Digraph) -> Set[Module]:
        # Leaves only depend, and do not serve as dependencies.
        leaves = set(unique_modules)
        for _, dependencies in _graph.items():
            leaves.difference_update(dependencies)
        return leaves

    def _root_modules(_graph: Digraph) -> Set[Module]:
        # Roots only serve as dependencies, and do not depend.
        # Since this is SNOMED, there should be only one root.
        roots = set(unique_modules)
        for module, _ in _graph.items():
            roots.difference_update([module])
        return roots

    leaves = _leaf_modules(GRAPH)
    _roots = _root_modules(GRAPH)
    if len(_roots) != 1:
        raise ValueError("There should be only one root. Input is incorrect")
    root = _roots.pop()
    # print(f"Root: {root}")
    # print(f"Leaves: {leaves}")

    # Start building graphs from the leaves:
    def _graphs_from_leaves(
            _leaves: List[VersionedModule],
            _parent_graph: VersionedDigraph
            ) -> Generator[VersionedDigraph, None, None]:
        # Build graphs from the leaves.
        # The graphs will be built from the leaves to the root.
        for leaf in _leaves:
            subgraph: VersionedDigraph = _parent_graph.copy()
            leaf_deps_mv = list(_node_dependencies(leaf))
            leaf_deps_m = [m for m, _ in leaf_deps_mv]

            # Check if a conflicting module is already in the graph
            for node in subgraph:
                if node[0] in leaf_deps_m and node not in leaf_deps_mv:
                    # Graph already contains a different version of the module
                    # that the leaf depends on.
                    break
            else:  # Rare syntax: means that the loop did not break.
                # No conflicting module found in the graph.
                subgraph[leaf] = leaf_deps_mv
                if _validate_subgraph(subgraph):
                    # The subgraph is complete.
                    yield subgraph
                else:
                # Continue building the graph from the leaf's dependencies.
                    yield from _graphs_from_leaves(leaf_deps_mv, subgraph)

    # Build graphs from the leaves:
    versioned_leaves = [mv
                        for mv
                        in unique_versioned_modules
                        if mv[0] in leaves]
    G0 = next(_graphs_from_leaves(versioned_leaves, {}))
    return _module_versions(_unique_versioned_modules(G0))

if __name__ == "__main__":
    with open("graph.csv", "r") as f:
        lines = [line.replace('"', '') for line in f.read().splitlines()]
    import pstats
    import cProfile
    import json
    with cProfile.Profile() as pr:
        G = _main(lines)
        print(json.dumps(G, indent=4))
    stats = pstats.Stats(pr)
    stats.sort_stats(pstats.SortKey.TIME)
    stats.dump_stats("profile.pstats")
