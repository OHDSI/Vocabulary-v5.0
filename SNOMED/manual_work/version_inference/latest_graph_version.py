def _main(
        mv_dependency_graph, # Input: varchar[], where each element
                             # is a string of the form
                             # "module==version->dependency==version"
        ):                   # Returns:
                             # varchar[][], where each element is an array of
                             # strings of the form "module==version"
    """\
    Return all versions combos of each module
so that they can form a valid graph.
    """
    from functools import lru_cache
    from typing import Set, List, Tuple, Dict, Generator
    # Helper types:
    Module = str
    Version = str
    VersionedModule = Tuple[Module, Version]
    Dependency = Module
    VersionedDependency = VersionedModule
    Digraph = Dict[Module, List[Dependency]]
    VersionedDigraph = Dict[VersionedModule, List[VersionedDependency]]

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
        node_dependencies = set(ALL_VERSIONED_GRAPH.get(node, []))
        return node_dependencies

    @lru_cache(maxsize=None)
    def _module_dependencies(module: Module) -> Set[Dependency]:
        module_dependencies = set(GRAPH.get(module, []))
        return module_dependencies

    def _try_add_node(_subgraph: VersionedDigraph,
            _mv: VersionedModule) -> bool:
        # WARNING: This function mutates!
        node_dependencies = _node_dependencies(_mv)
        module_dependencies = _module_dependencies(_mv[0])
        subgraph_modules = [m for m, _ in _subgraph]

        # Speed hack:
        #if not module_dependencies.issubset(subgraph_modules):
        #    return False

        if node_dependencies.issubset(_subgraph):
            _subgraph[_mv] = list(node_dependencies)
            return True
        return False

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
        return set(m for m, _ in _subgraph) == set(unique_modules)

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

    # Parse input graph:
    ALL_VERSIONED_GRAPH: VersionedDigraph = _parse_graph(mv_dependency_graph)
    GRAPH: Digraph = _unvers_graph(ALL_VERSIONED_GRAPH)
    unique_versioned_modules = _unique_versioned_modules(ALL_VERSIONED_GRAPH)
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
        raise ValueError("There should be only one root.")
    root = _roots.pop()
    print(f"Root: {root}")

    def _build_mv_subgraphs() -> List[VersionedDigraph]:

        root_sg: VersionedDigraph = {}
        def _build_subgraph(_parent_subgraph: VersionedDigraph
                ) -> Generator[VersionedDigraph, None, None]:

            # If the subgraph is valid, yield it.
            if _validate_subgraph(_parent_subgraph):
                yield _parent_subgraph
                # Stop iterating if the subgraph is valid.
                return

            # Otherwise, try to add a node if possible
            _subgraph = _parent_subgraph.copy()
            while True:
                changes = False
                for module in GRAPH:
                    if module in [m for m, _ in _subgraph]:
                        continue
                    for version in unique_modules[module]:
                        if _try_add_node(_subgraph, (module, version)):
                            changes = True
                            yield from _build_subgraph(_subgraph)
                if not changes:
                    break

        return list(_build_subgraph(root_sg))

    # Build subgraphs:
    subgraphs = _build_mv_subgraphs()
    return subgraphs


if __name__ == "__main__":
    with open("graph.csv", "r") as f:
        lines = [line.replace('"', '') for line in f.read().splitlines()]
    import pstats
    import cProfile
    with cProfile.Profile() as pr:
        print(_main(lines))
    stats = pstats.Stats(pr)
    stats.sort_stats(pstats.SortKey.TIME)
    stats.dump_stats("profile.pstats")
