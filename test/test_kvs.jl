if nprocs() < 2
    id_me = myid()
    id_other = addprocs(1)[1]

    using MessageUtils
    using Base.Test
end

for id in [id_me, id_other]
    t = kvspace(id)
    put!(t, 1, 10)
    put!(t, "Hello", "World")
    put!(t, 5.0, 50.0)

    @test isready(t, 1) == true
    @test fetch(t, 1) == 10
    @test fetch(t, 5.0) == 50.0
    @test fetch(t, "Hello") == "World"
    @test take!(t, 1) == 10   
    @test isready(t, 1) == false
    @test isready(t, 5.0) == true


    t = tspace(id)
    put!(t, (1, 10))
    put!(t, ("Hello", "World", "!"))
    put!(t, (5.0,))

    @test isready(t, 1) == true
    @test fetch(t, 1) == (1, 10)
    @test fetch(t, 5.0) == (5.0,)
    @test fetch(t, "Hello") == ("Hello", "World", "!")
    @test fetch(t, r".*") == ("Hello", "World", "!")
    @test take!(t, 1) == (1, 10)
    @test isready(t, 1) == false
    @test isready(t, 5.0) == true
end

