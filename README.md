SyncObjects.jl
==============

channels(), tspaces(), kvspaces() and more

`channel()` which returns a RemoteRef to a channel
`tspace()` which returns a RemoteRef to a tspace, i.e., a tuple space
`kvspace()` which returns a RemoteRef to a kvspace, i.e., a dict

`tspace` and `kvspace` are inspired by http://en.wikipedia.org/wiki/Linda_(coordination_language)

A `channel` can have a type and length associated with it. `put` blocks only when full, `take` only when empty. It is a queue.

A `tspace` can store tuples, where the first element is a key. 
`take(rr, key)` will block till an element matching key becomes available in the tspace. 
The key can be a `Regex` object, in which case, it blocks till a match is found. 
The space itself is a queue so that any match is ordered as a FIFO. 
`fetch`, `isready`, `take` all accept a `key` parameter and the entire tuple is returned.

A `kvspace` is like a dict, only exact matches are allowed in `take` and any duplicates in `put` results in an overwrite. 
`put` is of the form `put(rr, key, value)`. 
`fetch`, `isready`, `take` all accept a `key` parameter and the associated value is returned.
