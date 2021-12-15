@testset "resource_management" begin
    rr = ResourceRequirement(:cpu => 1)
    rs = ResourceStatus(:cpu => 3)

    @test ResourceStatus(:cpu => 2) == rs - rr
    @test ResourceStatus(:cpu => 4) == rs + rr

    rc = ResourceCollector(:cpu => () -> 4)
    @test ResourceStatus(:cpu => 4) == rc()

end