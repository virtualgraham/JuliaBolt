using Test

include("../../src/io.jl")

@testset "ChunkedOuputBuffer Tests" begin

    @testset "test_should_start_empty" begin
        buffer = ChunkedOutputBuffer()
        @test view(buffer) == b""
    end

    @testset "test_should_be_able_to_set_max_chunk_size" begin
        buffer = ChunkedOutputBuffer(max_chunk_size=4)
        @test buffer.max_chunk_size == 4
    end

    @testset "test_small_data_should_be_directly_appended" begin
        buffer = ChunkedOutputBuffer()

        write(buffer, b"hello")
        
        @test view(buffer) == b"\x00\x05hello"
    end

    @testset "test_overflow_data_should_use_a_new_chunk" begin
        buffer = ChunkedOutputBuffer(max_chunk_size=6)

        write(buffer, b"over")
        write(buffer, b"flow")
        
        @test view(buffer) == b"\x00\x04over\x00\x04flow"
    end

    @testset "test_big_data_should_be_split_across_chunks" begin
        buffer = ChunkedOutputBuffer(max_chunk_size=2)

        write(buffer, b"octopus")
        
        @test view(buffer) == b"\x00\x02oc\x00\x02to\x00\x02pu\x00\x01s"
    end

    @testset "test_clear_should_clear_everything" begin
        buffer = ChunkedOutputBuffer()

        write(buffer, b"redacted")
        clear(buffer)
        
        @test view(buffer) == b""
    end

    @testset "test_cleared_buffer_should_be_reusable" begin
        buffer = ChunkedOutputBuffer()

        write(buffer, b"Windows")
        clear(buffer)
        write(buffer, b"Linux")
        
        @test view(buffer) == b"\x00\x05Linux"
    end

    @testset "test_should_be_able_to_force_chunks" begin
        buffer = ChunkedOutputBuffer()

        write(buffer, b"hello")
        chunk(buffer)
        write(buffer, b"world")
        chunk(buffer)
        
        @test view(buffer) == b"\x00\x05hello\x00\x05world"
    end

    @testset "test_should_be_able_to_force_empty_chunk" begin
        buffer = ChunkedOutputBuffer()

        write(buffer, b"hello")
        chunk(buffer)
        chunk(buffer)
        
        @test view(buffer) == b"\x00\x05hello\x00\x00"
    end
end