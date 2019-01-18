using Test
using Sockets
using Base.Threads

include("../../src/JuliaBolt.jl")

using .JuliaBolt

@testset "Connection Tests" begin

    @testset "test_conn_timedout" begin
        address = (ip"127.0.0.1", UInt16(7687))
        connection = Connection(1, address, FakeSocket(address), max_connection_lifetime=0)
        @test timedout(connection)
    end
    
    @testset "test_conn_not_timedout_if_not_enabled" begin
        address = (ip"127.0.0.1", UInt16(7687))
        connection = Connection(1, address, FakeSocket(address), max_connection_lifetime=-1)
        @test !timedout(connection)
    end

    @testset "test_conn_not_timedout" begin
        address = (ip"127.0.0.1", UInt16(7687))
        connection = Connection(1, address, FakeSocket(address), max_connection_lifetime=999999999)
        @test !timedout(connection)
    end
    
end


mutable struct TestRig
    pool::Union{ConnectionPool, Nothing}
    TestRig() = new(nothing)
end

@testset "ConnectionPool Tests" begin
    function connector(address; kwargs...)
        return QuickConnection(FakeSocket(address))
    end
    
    function setUp(t::TestRig)
        t.pool = ConnectionPool(connector, (ip"127.0.0.1", UInt16(7687)))
    end

    function tearDown(t::TestRig)
        JuliaBolt.close(t.pool)
    end

    testRig = TestRig()

    function assert_pool_size(address, expected_active, expected_inactive, _pool=nothing)
        if _pool == nothing
            _pool = testRig.pool
        end

        connections = nothing
        try
            connections = _pool.connections[address]
        catch e
            println("-----", e)
            @test expected_active == 0
            @test expected_inactive == 0
            return
        end

        println("+++++")
        @test expected_active == length([cx for cx in connections if cx.in_use])
        @test expected_inactive == length([cx for cx in connections if !cx.in_use])
    end
    
    @testset "test_can_acquire" begin
        setUp(testRig)
        address = (ip"127.0.0.1", UInt16(7687))
        connection = acquire_direct(testRig.pool, address)
        @test connection.address == address
        assert_pool_size(address, 1, 0)
        tearDown(testRig)
    end

    @testset "test_can_acquire_twice" begin
        setUp(testRig)
        address = (ip"127.0.0.1", UInt16(7687))
        connection_1 = acquire_direct(testRig.pool, address)
        connection_2 = acquire_direct(testRig.pool, address)
        @test connection_1.address == address
        @test connection_2.address == address
        @test connection_1 != connection_2
        assert_pool_size(address, 2, 0)
        tearDown(testRig)
    end

    @testset "test_can_acquire_two_addresses" begin
        setUp(testRig)
        address_1 = (ip"127.0.0.1", UInt16(7687))
        address_2 = (ip"127.0.0.1", UInt16(7474))
        connection_1 = acquire_direct(testRig.pool, address_1)
        connection_2 = acquire_direct(testRig.pool, address_2)
        @test connection_1.address == address_1
        @test connection_2.address == address_2
        assert_pool_size(address_1, 1, 0)
        assert_pool_size(address_2, 1, 0)
        tearDown(testRig)
    end

    @testset "test_can_acquire_and_release" begin
        setUp(testRig)
        address = (ip"127.0.0.1", UInt16(7687))
        connection = acquire_direct(testRig.pool, address)
        assert_pool_size(address, 1, 0)
        release(testRig.pool, connection)
        assert_pool_size(address, 0, 1)
    end

    @testset "test_releasing_twice" begin
        setUp(testRig)
        address = (ip"127.0.0.1", UInt16(7687))
        connection = acquire_direct(testRig.pool, address)
        release(testRig.pool, connection)
        assert_pool_size(address, 0, 1)
        release(testRig.pool, connection)
        assert_pool_size(address, 0, 1)
    end

    @testset "test_cannot_acquire_after_close" begin
        setUp(testRig)
        address = (ip"127.0.0.1", UInt16(7687))
        pool = ConnectionPool((a)->QuickConnection(FakeSocket(a)), address)
        JuliaBolt.close(pool)
        @test_throws ErrorException acquire_direct(pool, address)
    end

    @testset "test_in_use_count" begin
        setUp(testRig)
        address = (ip"127.0.0.1", UInt16(7687))
        @test in_use_connection_count(testRig.pool, address) == 0
        
        connection = acquire_direct(testRig.pool, address)
        @test in_use_connection_count(testRig.pool, address) == 1

        release(testRig.pool, connection)
        @test in_use_connection_count(testRig.pool, address) == 0
    end

    @testset "test_max_conn_pool_size" begin
        address = (ip"127.0.0.1", UInt16(7687))
        pool = ConnectionPool(connector, address, max_connection_pool_size=1, connection_acquisition_timeout=0)
        connection = acquire_direct(pool, address)
        @test in_use_connection_count(pool, address) == 1
        @test_throws ErrorException acquire_direct(pool, address)
        @test in_use_connection_count(pool, address) == 1
    end

    # @testset "test_multithread" begin
    #     address = (ip"127.0.0.1", UInt16(7687))
    #     pool = ConnectionPool(connector, address, max_connection_pool_size=5, connection_acquisition_timeout=10)

    #     connections = Vector(undef, 10)
        
    #     @threads for i in 1:10
    #         connections[i] = acquire_direct(pool, address)
    #     end
        
    #     assert_pool_size(address, 5, 0, pool)
        
    #     @threads for i in 1:10
    #         release(pool, connections[i])
    #     end
        
    #     assert_pool_size(address, 0, 5, pool)
    # end
end