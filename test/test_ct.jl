if nprocs() < 2
    addprocs(1)
    using MessageUtils
end


function foo()
    while true
        m = take!()
#        println("recd : ", m)
        put!((:response, m))
    end
end

ct = ctask(foo)

(1,2,3) |> ct
(1,3) |> ct

remotecall_fetch(2, ct -> take!(ct), ct)
take!(ct)

ctn = ctask(foo; name="testct")

("Hello", ) |> "testct"
("World", 1, 2) |> "testct"

remotecall_fetch(2, ()->take!("testct"))
take!("testct")

