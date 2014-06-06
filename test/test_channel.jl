if nprocs() < 2
    id_me = myid()
    id_other = addprocs(1)[1]

    using MessageUtils
    using Base.Test
end

c = channel()
put!(c, 1; timeout=10.0)
put!(c, "Hello")
put!(c, 5.0)

@test isready(c) == true
@test fetch(c) == 1
@test fetch(c) == 1   # Should not have been popped previously
@test take!(c) == 1   
@test take!(c) == "Hello"   
@test fetch(c) == 5.0
@test take!(c) == 5.0
@test isready(c) == false

# Channels of a particular type
c = channel(T=Int)
@test_throws ErrorException put!(c, "Hello")
@test_throws ErrorException put!(c, 5.0)


# same test mixed with another worker...
c = channel(id_other)
put!(c, 1)
remotecall_fetch(id_other, ch -> (rr = put!(ch, "Hello"); rr), c)
put!(c, 5.0)

@test isready(c) == true
@test remotecall_fetch(id_other, ch -> fetch(ch), c) == 1
@test fetch(c) == 1   # Should not have been popped previously
@test take!(c) == 1   
@test remotecall_fetch(id_other, ch -> take!(ch), c) == "Hello"
@test fetch(c) == 5.0
@test remotecall_fetch(id_other, ch -> take!(ch), c) == 5.0
@test remotecall_fetch(id_other, ch -> isready(ch), c) == false
@test isready(c) == false


