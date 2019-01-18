using Test
using Sockets

include("../../src/JuliaBolt.jl")

using .JuliaBolt

# these tests are completed using a Neo4j Community Edition server 
# running on the local machine with the default user "neo4j" and the 
# password set to "password"

@testset "Connection Tests" begin

    @testset "test_connection_open_close" begin
        connection = bolt_connect("localhost", 7687, auth=("neo4j", "password"))
        @test isa(connection, Connection)
        bolt_close(connection)
    end
    
    @testset "test_connection_simple_run" begin
        records = []
        metadata = Dict()
        connection = bolt_connect("localhost", 7687, auth=("neo4j", "password"))
        bolt_run(connection, "RETURN 1", Dict(), on_success=(response, result)->merge!(metadata, result))
        bolt_pull_all(connection, on_success=(response, result)->merge!(metadata, result), on_records=(response, result)->append!(records, result))
        bolt_sync(connection)
        
        @test records == [[1]]

        bolt_close(connection)
    end

    @testset "test_multiple_chunk_response" begin
        b = ones(UInt8, 16365)
        records = []
        metadata = Dict()
        connection = bolt_connect("localhost", 7687, auth=("neo4j", "password"))
        
        bolt_run(connection, "CREATE (a) SET a.foo = \$x RETURN a", Dict("x"=>b), on_success=(_, result)->merge!(metadata, result))
        bolt_pull_all(connection, on_success=(_, result)->merge!(metadata, result), on_records=(_, result)->append!(records, result))
        bolt_sync(connection)
    
        foo = records[1][1][3]["foo"]
                
        @test b == foo

        bolt_close(connection)
    end


    @testset "test_return_1" begin
        records = []
        metadata = Dict()
        connection = bolt_connect("localhost", 7687, auth=("neo4j", "password"))
        
        bolt_run(connection, "RETURN \$x", Dict("x"=>1), on_success=(_, result)->merge!(metadata, result))
        bolt_pull_all(connection, on_success=(_, result)->merge!(metadata, result), on_records=(_, result)->append!(records, result))
        bolt_sync(connection)
    
        @test records == [[1]]

        bolt_close(connection)
    end

    @testset "test_return_1_in_tx" begin
        records = []
        metadata = Dict()
        connection = bolt_connect("localhost", 7687, auth=("neo4j", "password"))
        bolt_begin(connection, on_success=(_, result)->merge!(metadata, result))
        bolt_run(connection, "RETURN \$x", Dict("x"=>1), on_success=(_, result)->merge!(metadata, result))
        bolt_pull_all(connection, on_success=(_, result)->merge!(metadata, result), on_records=(_, result)->append!(records, result))
        bolt_commit(connection, on_success=(_, result)->merge!(metadata, result))
        bolt_sync(connection)
    
        @test records == [[1]]
        @test startswith(metadata["bookmark"], "neo4j:bookmark:")
        @test metadata["fields"] == ["\$x"]
        @test isa(metadata["t_first"], Integer)
        @test isa(metadata["t_last"], Integer)
        @test metadata["type"] == "r"

        bolt_close(connection)
    end

    @testset "test_begin_with_timeout" begin
        records = []
        metadata = Dict()
        cx1 = bolt_connect("localhost", 7687, auth=("neo4j", "password"))
        
        bolt_run(cx1, "CREATE (a:Node)")
        bolt_discard_all(cx1)
        bolt_sync(cx1)

        cx2 = bolt_connect("localhost", 7687, auth=("neo4j", "password"))
        
        bolt_begin(cx1, on_failure=(_, f)->println(f))
        bolt_run(cx1, "MATCH (a:Node) SET a.property = 1", on_failure=(_, f)->println(f))
        bolt_sync(cx1)
        
        bolt_begin(cx2, timeout=1, on_failure=(_, f)->println(f))
        bolt_run(cx2, "MATCH (a:Node) SET a.property = 2", on_failure=(_, f)->println(f))

        @test_throws TransientError bolt_sync(cx2)

        bolt_close(cx1)
        bolt_close(cx2)
    end

    @testset "test_run_with_timeout" begin
        cx1 = bolt_connect("localhost", 7687, auth=("neo4j", "password"))
        
        bolt_run(cx1, "CREATE (a:Node)")
        bolt_discard_all(cx1)
        bolt_sync(cx1)

        cx2 = bolt_connect("localhost", 7687, auth=("neo4j", "password"))
        
        bolt_begin(cx1, on_failure=(_, f)->println(f))
        bolt_run(cx1, "MATCH (a:Node) SET a.property = 1", on_failure=(_, f)->println(f))
        bolt_sync(cx1)
        
        bolt_run(cx2, "MATCH (a:Node) SET a.property = 2", timeout=1, on_failure=(_, f)->println(f))

        @test_throws TransientError bolt_sync(cx2)

        bolt_close(cx1)
        bolt_close(cx2)
    end
end