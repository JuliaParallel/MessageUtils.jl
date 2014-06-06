id_me = myid()
id_other = addprocs(1)[1]

using MessageUtils
using Base.Test

macro dbgtest(ex) 
    println("Testing $ex")
    @eval @test $ex
end

include("test_channel.jl")
include("test_ts.jl")
include("test_kvs.jl")
include("test_ct.jl")


