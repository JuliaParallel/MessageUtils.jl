id_me = myid()
id_other = addprocs(1)[1]

using SyncObjects
using Base.Test


c = channel()
put(c, 1)
put(c, "Hello")
put(c, 5.0)

@test isready(c) == true
@test fetch(c) == 1
@test fetch(c) == 1   # Should not have been popped previously
@test take(c) == 1   
@test take(c) == "Hello"   
@test fetch(c) == 5.0
@test take(c) == 5.0
@test isready(c) == false

# same test mixed with another worker...
c = channel(id_other)
put(c, 1)
remotecall_fetch(id_other, ch -> put(ch, "Hello"), c)
put(c, 5.0)

@test isready(c) == true
@test remotecall_fetch(id_other, ch -> fetch(ch), c) == 1
@test fetch(c) == 1   # Should not have been popped previously
@test take(c) == 1   
@test remotecall_fetch(id_other, ch -> take(ch), c) == "Hello"
@test fetch(c) == 5.0
@test remotecall_fetch(id_other, ch -> take(ch), c) == 5.0
@test remotecall_fetch(id_other, ch -> isready(ch), c) == false
@test isready(c) == false

for id in [id_me, id_other]
    t = kvspace(id)
    put(t, 1, 10)
    put(t, "Hello", "World")
    put(t, 5.0, 50.0)

    @test isready(t, 1) == true
    @test fetch(t, 1) == 10
    @test fetch(t, 5.0) == 50.0
    @test fetch(t, "Hello") == "World"
    @test take(t, 1) == 10   
    @test isready(t, 1) == false
    @test isready(t, 5.0) == true


    t = tspace(id)
    put(t, (1, 10))
    put(t, ("Hello", "World", "!"))
    put(t, (5.0,))

    @test isready(t, 1) == true
    @test fetch(t, 1) == (1, 10)
    @test fetch(t, 5.0) == (5.0,)
    @test fetch(t, "Hello") == ("Hello", "World", "!")
    @test fetch(t, r".*") == ("Hello", "World", "!")
    @test take(t, 1) == (1, 10)
    @test isready(t, 1) == false
    @test isready(t, 5.0) == true
end


