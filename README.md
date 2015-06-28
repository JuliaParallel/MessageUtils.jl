MessageUtils
============

A collection of utilities for messaging

Channels
--------

Channels are like RemoteRefs, execpt that they are modelled as a queue and hence can hold
more than one message.

`channel(pid=myid(); T=Any, sz=1000)` constructs a channel on process `pid`, holds objects of
type `T` with a maximum number of entries `sz`.

The `channel` constructor returns an object reference of type `SyncObjRef{RemoteChannel}`
which can be passed around safely across processes.

`isready(c)`, `fetch(c)`, `take!(c)` and `put!(c, v)` have the same behaviour as the `RemoteRef`
equivalents.

`fetch` and `take!` block if there are no elements.

`put!` blocks if the channel already has `sz` elements present.

`fetch`, `take!` and `put!` all accept an optional `keyword` argument `timeout` which specifies
the maximum number of seconds to block. If the request cannot be fulfilled within the requested
time a `MUtilTimeOutEx` exception is thrown.


TSpaces
-------

TSpaces are tuple spaces. They store tuples, the first element of each tuple is a key
to the tuple.

The tuples are stored as a queue and duplicates are allowed.

`tspace(pid=myid(); sz=1000)` constructs a new tuple space and returns
a `SyncObjRef{RemoteTSpace}`

`put!(ts, v::Tuple)` adds a tuple `v` into the space `ts`.

`isready(ts,k)`, `fetch(ts, k)` and `take!(ts, k)` all require the key `k` to be specified when
used on a tuple space `ts`. It is matched against the first element of the tuples in the space.

If `k` is a `Regex` object, it is matched against all tuples where the firest element is a
`String`

`fetch`, `take!` and `put!` all accept an optional `keyword` argument `timeout` which specifies
the maximum number of seconds to block. If the request cannot be fulfilled within the requested
time a `MUtilTimeOutEx` exception is thrown.


KVSpaces
--------

This is a key-value store.

`kvspace(pid=myid(); sz=1000)` constructs a new key-value space and returns
a `SyncObjRef{RemoteKVSpace}`. Duplicates are not allowed. A `put!` with an existing key
overwrites the existing value

`put!(kvs, k, v)` adds key `k` and value `v` into the space `kvs`.

`isready(kvs,k)`, `fetch(kvs, k)` and `take!(kvs, k)` all require the key `k` to be specified when
used on a kv space `kvs`.

`fetch`, `take!` and `put!` all accept an optional `keyword` argument `timeout` which specifies
the maximum number of seconds to block. If the request cannot be fulfilled within the requested
time a `MUtilTimeOutEx` exception is thrown.


ctasks - Tasks with Channels
----------------------------

ctasks are named tasks with channels. The channels are used for messaging with the task.

`ctask(f::Function; pid=myid(), name="")` returns a `CTask` object that can be passed around
processors.

`f` is the function lanuched on processor `pid`. The ctask runs till function `f` terminates.
If `name` is specified, the task is addressable by name. The name-ctask mapping is stored in
a KV Space on pid 1.

Every ctask has two channels associated with it. One for incoming messages and one for outbound
messages.

The following functions can be used to send/recv messages from these channels.

`put!(msg::Tuple)` appends a message to a tasks outbound channel

`put!(ct::CTask, msg::Tuple)` appends a message to task `ct`'s inbound channel

`put!(ctname::String, msg::Tuple)` appends a message to task addressed by `ctname`'s inbound channel

`take!()` pops a message from the current tasks inbound channel

`take!(ct::CTask)` pops a message from task `ct`'s outbound channel

`take!(ctname::String)` pops a message from the task addressed by `ctname`'s outbound channel

The pipelining operator `|>` can be used to send a message to a task. For example:

`(:test_msg, "Hello") |> ct` will add the tuple `(:test_msg, "Hello")` to `ct`'s inbound channel

`put!`, `take!` both accept an optional `keyword` argument `timeout` which specifies
the maximum number of seconds to block. If the request cannot be fulfilled within the requested
time a `MUtilTimeOutEx` exception is thrown.

Note: The Julia 0.3 compatible version has `send`/`recv` in place of `put!`/`take`. 
This has been renamed in 0.4 for consistency.  
