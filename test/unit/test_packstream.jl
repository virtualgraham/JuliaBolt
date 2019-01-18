using Test
using Mmap
using DataStructures

include("../../src/io.jl")
include("../../src/strpack.jl")

function packb(values)
    stream_out = IOBuffer()
    packer = Packer(stream_out)   
    for value in values
        pack(packer, value)
    end
    return take!(stream_out)
end

function assert_packable(value, packed_value)
    stream_out = IOBuffer()
    packer = Packer(stream_out)
    packer.supports_bytes = true
    pack(packer, value)
    packed = take!(stream_out)

    @test packed == packed_value

    unpacker = Unpacker()
    unpacker.source = MessageFrame(Base.view(packed, :), Tuple{Integer, Integer}[(0, length(packed))])
    unpacked = unpack(unpacker)

    @test unpacked == value
end

@testset "PackStream Tests" begin

    @testset "test_none" begin
        assert_packable(nothing, b"\xC0")
    end
    
    @testset "test_boolean" begin
        assert_packable(true, b"\xC3")
        assert_packable(false, b"\xC2")
    end

    @testset "test_negative_tiny_int" begin
        for z in -16:-1
            assert_packable(z, UInt8[z + 0x100])
        end
    end
    
    @testset "test_positive_tiny_int" begin
        for z in 0:127
            assert_packable(z, UInt8[z])
        end
    end

    @testset "test numbers using known byte strings" begin
        @testset "test_positive_int16" begin
            z = 32767
            expected = b"\xc9\x7f\xff"
            assert_packable(z, expected)
        end

        @testset "test_negative_int16" begin
            z = -32768
            expected = b"\xc9\x80\x00"
            assert_packable(z, expected)
        end

        @testset "test_positive_int32" begin
            e = 30
            z = 2 ^ e
            expected = b"\xca@\x00\x00\x00"
            assert_packable(z, expected)
        end

        @testset "test_negative_int32" begin
            e = 30
            z = -(2 ^ e + 1)
            expected = b"\xca\xbf\xff\xff\xff"
            assert_packable(z, expected)
        end

        @testset "test_positive_int64" begin
            e = 62
            z = 2^e
            expected = b"\xcb@\x00\x00\x00\x00\x00\x00\x00"
            assert_packable(z, expected)
        end

        @testset "test_negative_int64" begin
            e = 62
            z = -(2 ^ e + 1)
            expected = b"\xcb\xbf\xff\xff\xff\xff\xff\xff\xff"
            assert_packable(z, expected)
        end

        @testset "test_zero_float64" begin
            zero = 0.0
            expected = b"\xc1\x00\x00\x00\x00\x00\x00\x00\x00"
            assert_packable(zero, expected)
        end

        @testset "test_tau_float64" begin
            tau = 2 * pi
            expected = b"\xc1@\x19!\xfbTD-\x18"
            assert_packable(tau, expected)
        end

        @testset "test_positive_float64" begin
            e = 99.0
            r = 2.0 ^ e + 0.5
            expected = b"\xc1F \x00\x00\x00\x00\x00\x00"
            assert_packable(r, expected)
        end

        @testset "test_negative_float64" begin
            e = 99.0
            r = -(2.0 ^ e + 0.5)
            expected = b"\xc1\xc6 \x00\x00\x00\x00\x00\x00"
            assert_packable(r, expected)
        end
    end

    @testset "test numbers using struct_pack" begin
        @testset "test_positive_int16" begin
            for z in 128:32767
                expected = vcat(b"\xC9", struct_pack(Int16(z)))
                assert_packable(z, expected)
            end
        end

        @testset "test_negative_int16" begin
            for z in -32768:-129
                expected = vcat(b"\xC9", struct_pack(Int16(z)))
                assert_packable(z, expected)
            end
        end

        @testset "test_positive_int32" begin
            for e in 15:30
                z = 2 ^ e
                expected = vcat(b"\xCA", struct_pack(Int32(z)))
                assert_packable(z, expected)
            end
        end

        @testset "test_negative_int32" begin
            for e in 15:30
                z = -(2 ^ e + 1)
                expected = vcat(b"\xCA", struct_pack(Int32(z)))
                assert_packable(z, expected)
            end
        end

        @testset "test_positive_int64" begin
            for e in 31:62
                z = 2^e
                expected = vcat(b"\xCB", struct_pack(Int64(z)))
                assert_packable(z, expected)
            end
        end

        @testset "test_negative_int64" begin
            for e in 31:62
                z = -(2^e + 1)
                expected = vcat(b"\xCB", struct_pack(Int64(z)))
                assert_packable(z, expected)
            end
        end

        @testset "test_zero_float64" begin
            zero = 0.0
            expected = vcat(b"\xC1", struct_pack(Float64(zero)))
            assert_packable(zero, expected)
        end

        @testset "test_tau_float64" begin
            tau = 2 * pi
            expected = vcat(b"\xC1", struct_pack(Float64(tau)))
            assert_packable(tau, expected)
        end

        @testset "test_positive_float64" begin
            for e in 0:99
                r = 2.0 ^ e + 0.5
                expected = vcat(b"\xC1", struct_pack(Float64(r)))
                assert_packable(r, expected)
            end
        end

        @testset "test_negative_float64" begin
            for e in 0:99
                r = -(2.0 ^ e + 0.5)
                expected = vcat(b"\xC1", struct_pack(Float64(r)))
                assert_packable(r, expected)
            end
        end
    end

    @testset "test_empty_bytes" begin
        assert_packable(UInt8[], b"\xCC\x00")
    end

    @testset "test_bytes_8" begin
        assert_packable(Array{UInt8}(b"hello"), b"\xCC\x05hello")
    end

    @testset "test_bytes_16" begin
        b = zeros(UInt8, 40000)
        assert_packable(b, vcat(b"\xCD\x9C\x40", b))
    end

    @testset "test_bytes_32" begin
        b = zeros(UInt8, 80000)
        assert_packable(b, vcat(b"\xCE\x00\x01\x38\x80", b))
    end

    @testset "test_empty_string" begin
        assert_packable("", b"\x80")
    end

    @testset "test_tiny_string" begin
        assert_packable("hello", b"\x85hello")
    end

    @testset "test_string_8" begin
        t = repeat("A", 40)
        assert_packable(t, vcat(b"\xD0\x28", Array{UInt8}(t)))
    end

    @testset "test_string_16" begin
        t = repeat("A", 40000)
        assert_packable(t, vcat(b"\xD1\x9C\x40", Array{UInt8}(t)))
    end

    @testset "test_string_32" begin
        t = repeat("A", 80000)
        assert_packable(t, vcat(b"\xD2\x00\x01\x38\x80", Array{UInt8}(t)))
    end

    @testset "test_unicode_string" begin
        t = "héllö"
        b = Array{UInt8}("héllö")
        assert_packable(t, vcat(UInt8[0x80 + length(b)], b))
    end

    @testset "test_empty_list" begin
        assert_packable([], b"\x90")
    end

    @testset "test_list_8" begin
        l = fill(1, 40)
        assert_packable(l, vcat(b"\xD4\x28", fill(0x01, 40)))
    end

    @testset "test_list_16" begin
        l = fill(1, 40000)
        assert_packable(l, vcat(b"\xD5\x9C\x40", fill(0x01, 40000)))
    end

    @testset "test_list_32" begin
        l = fill(1, 80000)
        assert_packable(l, vcat(b"\xD6\x00\x01\x38\x80", fill(0x01, 80000)))
    end

    @testset "test_nested_lists" begin
        assert_packable([[[]]], b"\x91\x91\x90")
    end

    @testset "test_list_stream" begin
        packed_value = b"\xD7\x01\x02\x03\xDF"
        unpacked_value = [1, 2, 3]
        stream_out = IOBuffer()
        packer = Packer(stream_out)
        pack_list_stream_header(packer)
        pack(packer, 1)
        pack(packer, 2)
        pack(packer, 3)
        pack_end_of_stream(packer)
        packed = take!(stream_out)

        @test packed == packed_value

        unpacker = Unpacker()
        unpacker.source = MessageFrame(Base.view(packed, :), Tuple{Integer, Integer}[(0, length(packed))])
        unpacked = unpack(unpacker)

        @test unpacked == unpacked_value
    end

    @testset "test_empty_map" begin
        assert_packable(Dict(), b"\xA0")
    end
    
    @testset "test_tiny_map" begin
        d = OrderedDict([("A",1),("B",2)])
        assert_packable(d, b"\xA2\x81A\x01\x81B\x02")
    end

    @testset "test_map_8" begin
        d = OrderedDict([("A$(i)", 1) for i in 0:39])
        b = [packb(("A$(i)", 1)) for i in 0:39]
        assert_packable(d, vcat(b"\xD8\x28", vcat(b...)))
    end

    @testset "test_map_16" begin
        d = OrderedDict([("A$(i)", 1) for i in 0:39999])
        b = [packb(("A$(i)", 1)) for i in 0:39999]
        assert_packable(d, vcat(b"\xD9\x9C\x40", vcat(b...)))
    end

    @testset "test_map_32" begin
        d = OrderedDict([("A$(i)", 1) for i in 0:79999])
        b = [packb(("A$(i)", 1)) for i in 0:79999]
        assert_packable(d, vcat(b"\xDA\x00\x01\x38\x80", vcat(b...)))
    end
    
    @testset "test_map_stream" begin
        packed_value = b"\xDB\x81A\x01\x81B\x02\xDF"
        unpacked_value = Dict("A"=>1,"B"=>2)
        stream_out = IOBuffer()
        packer = Packer(stream_out)
        pack_map_stream_header(packer)
        pack(packer, "A")
        pack(packer, 1)
        pack(packer, "B")
        pack(packer, 2)
        pack_end_of_stream(packer)
        packed = take!(stream_out)

        @test packed == packed_value

        unpacker = Unpacker()
        unpacker.source = MessageFrame(Base.view(packed, :), Tuple{Integer, Integer}[(0, length(packed))])
        unpacked = unpack(unpacker)

        @test unpacked == unpacked_value
    end

    @testset "test_illegal_signature" begin
        @test_throws MethodError assert_packable(Structure(b"XXX", []), b"\xB0XXX")
    end
    
    @testset "test_empty_struct" begin
        assert_packable(Structure(UInt8('X')), b"\xB0X")
    end   
    
    @testset "test_tiny_struct" begin
        assert_packable(Structure(UInt8('Z'), ["A", 1]), b"\xB2Z\x81A\x01")
    end   

    @testset "test_illegal_value_type" begin
        @test_throws MethodError assert_packable(v"1.0.0", b"\xB0XXX")
    end
end