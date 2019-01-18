using Test

include("../../src/io.jl")

@testset "MessageFrame Tests" begin

    @testset "test_should_be_able_to_read_int" begin
        frame = MessageFrame(Base.view(Array(b"\x00\x03ABC\x00\x00"), :), Tuple{Integer, Integer}[(2,5)])

        values = [read_int(frame) for _ in 1:4]
        
        @test values == [65, 66, 67, -1]
    end

    @testset "test_should_be_able_to_read_int_across_chunks" begin
        frame = MessageFrame(Base.view(Array(b"\x00\x03ABC\x00\x03DEF\x00\x00"), :), Tuple{Integer, Integer}[(2, 5), (7, 10)])

        values = [read_int(frame) for _ in 1:7]
        
        @test values == [65, 66, 67, 68, 69, 70, -1]
    end

    @testset "test_should_be_able_to_read_one" begin
        frame = MessageFrame(Base.view(Array(b"\x00\x03ABC\x00\x00"), :), Tuple{Integer, Integer}[(2, 5)])

        value = read(frame, 1)
        
        @test value == b"A"
        @test typeof(value) <: SubArray
    end

    @testset "test_should_be_able_to_read_some" begin
        frame = MessageFrame(Base.view(Array(b"\x00\x03ABC\x00\x00"), :), Tuple{Integer, Integer}[(2, 5)])

        value = read(frame, 2)
        
        @test value == b"AB"
        @test typeof(value) <: SubArray
    end
    
    @testset "test_should_be_able_to_read_all" begin
        frame = MessageFrame(Base.view(Array(b"\x00\x03ABC\x00\x00"), :), Tuple{Integer, Integer}[(2, 5)])

        value = read(frame, 3)
        
        @test value == b"ABC"
        @test typeof(value) <: SubArray
    end

    @testset "test_should_read_empty_if_exhausted" begin
        frame = MessageFrame(Base.view(Array(b"\x00\x03ABC\x00\x00"), :), Tuple{Integer, Integer}[(2, 5)])
        value = read(frame, 3)
        
        value = read(frame, 3)
        
        @test value == b""
    end 

    @testset "test_should_be_able_to_read_beyond" begin
        frame = MessageFrame(Base.view(Array(b"\x00\x03ABC\x00\x00"), :), Tuple{Integer, Integer}[(2, 5)])
       
        value = read(frame, 4)
        
        @test value == b"ABC"
    end 

    @testset "test_should_be_able_to_read_across_chunks" begin
        frame = MessageFrame(Base.view(Array(b"\x00\x03ABC\x00\x03DEF\x00\x00"), :), Tuple{Integer, Integer}[(2, 5), (7, 10)])
       
        value = read(frame, 4)
        
        @test value == b"ABCD"
    end 

    @testset "test_should_be_able_to_read_all_across_chunks" begin
        frame = MessageFrame(Base.view(Array(b"\x00\x03ABC\x00\x03DEF\x00\x00"), :), Tuple{Integer, Integer}[(2, 5), (7, 10)])
       
        value = read(frame, 6)
        
        @test value == b"ABCDEF"
    end 
end
