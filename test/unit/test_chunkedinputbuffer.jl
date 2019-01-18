using Test

include("../../src/io.jl")

@testset "ChunkedInputBuffer Tests" begin
    
    @testset "test_should_start_empty" begin
        buffer = ChunkedInputBuffer()
        @test length(view(buffer)) == 0
    end

    @testset "test_should_be_able_to_set_capacity" begin
        buffer = ChunkedInputBuffer(capacity=10)
        @test capacity(buffer) == 10
    end

    @testset "test_should_be_able_to_load_data" begin
        buffer = ChunkedInputBuffer()
        load(buffer, b"\x00\x05hello")
        @test view(buffer) == b"\x00\x05hello"
    end 

    @testset "test_should_be_able_to_load_multiple_times" begin
        buffer = ChunkedInputBuffer()
        
        load(buffer, b"\x00\x05hello")
        load(buffer, b"\x00\x05world")
        
        @test view(buffer) == b"\x00\x05hello\x00\x05world"
    end 

    @testset "test_should_be_able_to_load_after_discard" begin
        buffer = ChunkedInputBuffer()
        
        load(buffer, b"\x00\x05hello\x00\x00")
        frame_message(buffer)
        frame = buffer.frame

        @test frame.panes == [(2,7)]

        discard_message(buffer)
        load(buffer, b"\x00\x07bonjour\x00\x00")
        frame_message(buffer)
        frame = buffer.frame

        @test frame.panes == [(2, 9)]
    end

    @testset "test_should_auto_extend_on_load" begin
        buffer = ChunkedInputBuffer(capacity=10)
        load(buffer, b"\x00\x05hello")

        load(buffer, b"\x00\x07bonjour")
        
        @test capacity(buffer) == 16
    end

    @testset "test_should_start_with_no_frame" begin
        buffer = ChunkedInputBuffer()
        load(buffer, b"\x00\x05hello\x00\x00")
        load(buffer, b"\x00\x07bonjour\x00\x00")
        
        @test buffer.frame == nothing
    end

    @testset "test_should_be_able_to_frame_message" begin
        buffer = ChunkedInputBuffer(capacity=10)
        load(buffer, b"\x00\x05hello\x00\x00")
        load(buffer, b"\x00\x07bonjour\x00\x00")
        
        framed = frame_message(buffer)

        @test framed
        @test buffer.frame.panes == [(2, 7)]
    end  

    @testset "test_should_be_able_to_frame_empty_message" begin
        buffer = ChunkedInputBuffer()
        load(buffer, b"\x00\x00")

        framed = frame_message(buffer)
        
        @test framed
        @test buffer.frame.panes == []
    end
    
    @testset "test_should_not_be_able_to_frame_empty_buffer" begin
        buffer = ChunkedInputBuffer()

        framed = frame_message(buffer)
        
        @test !framed
    end

    @testset "test_should_not_be_able_to_frame_partial_message" begin
        buffer = ChunkedInputBuffer()
        load(buffer, b"\x00\x05hello")

        framed = frame_message(buffer)
        
        @test !framed
    end

    @testset "test_should_be_able_to_discard_message" begin
        buffer = ChunkedInputBuffer()
        load(buffer, b"\x00\x05hello\x00\x00")
        load(buffer, b"\x00\x07bonjour\x00\x00")
        frame_message(buffer)

        discard_message(buffer)
        
        @test buffer.frame == nothing
    end

    @testset "test_should_be_able_to_discard_empty_message" begin
        buffer = ChunkedInputBuffer()
        load(buffer, b"\x00\x00")
        frame_message(buffer)

        discard_message(buffer)
        
        @test buffer.frame == nothing
    end

    @testset "test_discarding_message_should_move_read_pointer" begin
        buffer = ChunkedInputBuffer()
        load(buffer, b"\x00\x05hello\x00\x00")
        load(buffer, b"\x00\x07bonjour\x00\x00")
        frame_message(buffer)
        discard_message(buffer)
        
        framed = frame_message(buffer)

        @test framed
        @test buffer.frame.panes == [(2,9)]
    end

    @testset "test_should_be_able_to_frame_successive_messages_without_discarding" begin
        buffer = ChunkedInputBuffer()
        load(buffer, b"\x00\x05hello\x00\x00")
        load(buffer, b"\x00\x07bonjour\x00\x00")
        frame_message(buffer)
        
        framed = frame_message(buffer)

        @test framed
        @test buffer.frame.panes == [(2,9)]
    end

    @testset "test_discarding_message_should_not_recycle_buffer" begin
        buffer = ChunkedInputBuffer()
        load(buffer, b"\x00\x05hello\x00\x00")
        load(buffer, b"\x00\x07bonjour\x00\x00")
        frame_message(buffer)
        
        discard_message(buffer)

        @test view(buffer) == b"\x00\x05hello\x00\x00\x00\x07bonjour\x00\x00"
    end

    @testset "test_should_not_be_able_to_frame_message_if_empty" begin
        buffer = ChunkedInputBuffer()
        
        @test !frame_message(buffer)
    end

    @testset "test_should_not_be_able_to_frame_message_if_incomplete" begin
        buffer = ChunkedInputBuffer()
        load(buffer, b"\x00\x05hello")
        
        @test !frame_message(buffer)
    end
    
    @testset "test_should_be_able_to_frame_message_if_complete" begin
        buffer = ChunkedInputBuffer()
        load(buffer, b"\x00\x05hello\x00\x00")
        
        @test frame_message(buffer)
    end
    
    @testset "test_should_be_able_to_frame_message_if_complete_with_more" begin
        buffer = ChunkedInputBuffer()
        load(buffer, b"\x00\x05hello\x00\x00\x00\x05world\x00\x00")
        
        @test frame_message(buffer)
    end
end