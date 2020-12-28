##################################################################################################
## Methylation calls structure & associated methods
##################################################################################################

# Output files
mutable struct OutputFiles
    theta_file::String                  # THETA
    ex_file::String                     # E[X]
    exx_file::String                    # E[XX]
    mml_file::String                    # MML
    nme_file::String                    # NME
    OutputFiles() = new()
    OutputFiles(out_dir,out_prefix) = new(
        "$(out_dir)/$(out_prefix)_theta.txt",
        "$(out_dir)/$(out_prefix)_ex.txt",
        "$(out_dir)/$(out_prefix)_exx.txt",
        "$(out_dir)/$(out_prefix)_mml.txt",
        "$(out_dir)/$(out_prefix)_nme.txt"
    )
end

# CpelNano Configuration
mutable struct CpelNanoConfig
    min_cov::Float64                    # Minimum average coverage
    min_grp_dist::Int64                 # Minimum distance between CpG groups
    max_size_subreg::Int64              # Maximum size subregion
    size_an_reg::Int64                  # Average size analysis region
    max_em_init::Int64                  # Maximum number of EM initializations used
    max_em_iters::Int64                 # Maximum number of iterations in each EM instance
    out_dir::String                     # Output directory
    out_prefix::String                  # Output prefix
    informme_mode::Bool                 # Partition genome in the same way informME does
    matched::Bool                       # Matched or unmatched comparison
    filter::Bool                        # Filter hypothesis for more power
    min_pval::Bool                      # Include regions with not enough data for p-val<0.05
    caller::String                      # Methylation caller used
    bed_reg::String                     # Path to bed file with regions of interest
    verbose::Bool                       # Print intermediate results
    trim::NTuple{4,Int64}               # Trimming of reads
    pe::Bool                            # Paired end (used if BS data)
    out_files::OutputFiles              # Name of output files
    # Init methods
    CpelNanoConfig() = new(10.0,10,250,3000,10,20,"./","cpelnano",false,false,false,false,"nanopolish","",
        false,(0,0,0,0),false,OutputFiles("./","cpelnano"))
    CpelNanoConfig(min_cov,max_size_subreg,size_an_reg,max_em_init,max_em_iters) = 
        new(min_cov,10,max_size_subreg+1,size_an_reg,max_em_init,max_em_iters,"","",
        false,false,false,false,"nanopolish","",false,(0,0,0,0),false,OutputFiles("",""))
end

##################################################################################################
## Methylation calls structure & associated methods
##################################################################################################

# BAM file
struct AlignTemp
    strand::String                  # Methylation call strand
    R1::BAM.Record                  # First record from left to right
    R2::BAM.Record                  # Second record from left to right
end

mutable struct AllAlignTemps
    paired::Bool                    # Boolean indicating if record has pair
    templates::Array{AlignTemp,1}   # All alignment templates mapping to a region
end

# Structure for matrices
mutable struct LogGs
    pp::Vector{Float64}                                 # Series of log(g1(+x_p))
    pm::Vector{Float64}                                 # Series of log(g1(-x_p))
    qp::Vector{Float64}                                 # Series of log(g2(+x_q))
    qm::Vector{Float64}                                 # Series of log(g2(-x_q))
    # Init Methods
    LogGs() = new([],[],[],[])
end

# Structure for expectations
mutable struct Expectations
    ex::Vector{Float64}                                 # Vector E[X]
    exx::Vector{Float64}                                # Vector E[XX]
    # Init Methods
    Expectations() = new([],[])
end

# Structure for matrices
mutable struct TransferMat
    u1::Vector{Float64}                                 # Vector u1
    uN::Vector{Float64}                                 # Vector uN
    Ws::Vector{Array{Float64,2}}                        # Series of W matrices
    log_gs::LogGs                                       # log(g_i(±⋅))
    # Init Methods
    TransferMat() = new([],[],[],LogGs())
end

# Structure for methylation call at CpG site
mutable struct MethCallCpgGrp
    obs::Bool                                           # Binary vector indicating if observed
    log_pyx_u::Float64                                  # log p(y|x=-1) as computed by pore model
    log_pyx_m::Float64                                  # log p(y|x=+1) as computed by pore model
    # Init methods
    MethCallCpgGrp() = new(false,NaN,NaN)
    MethCallCpgGrp(log_pyx_u,log_pyx_m) = new(true,log_pyx_u,log_pyx_m)
end

# Structure for CpG groups
mutable struct CpgGrp
    # Coordinates
    grp_int::UnitRange{Int64}                           # Genomic interval of CpG group
    cpg_ind::UnitRange{Int64}                           # CpG indices for given group
    # Init methods
    CpgGrp(grp_int,cpg_ind) = new(grp_int,cpg_ind)
end

# Structure for methylation observation vectors in a region
mutable struct RegStruct
    # Processed
    proc::Bool                                          # Determines if region has been processed
    # Chromosome properties
    chr::String                                         # Chromosome of the region
    chrst::Int64                                        # Start position of region (1-based)
    chrend::Int64                                       # End position of region (1-based)
    N::Int64                                            # Number of CpG sites in region
    L::Int64                                            # Number of CpG groups in region
    Nl::Vector{Float64}                                 # Number of CpG sites per group
    ρn::Vector{Float64}                                 # Vector of density ρ per CpG site
    ρl::Vector{Float64}                                 # Vector of density ρ per CpG group
    dn::Vector{Float64}                                 # Vector of d(n,n+1) per CpG site
    dl::Vector{Float64}                                 # Vector of d(l,l+1) per CpG group
    cpg_pos::Vector{Int64}                              # CpG site positions
    cpg_grps::Vector{CpgGrp}                            # CpG groups intervals
    cpg_occ::Vector{Bool}                               # Vector indicating subregions w/ CG groups
    # Data
    m::Int64                                            # Number of observations
    calls::Vector{Vector{MethCallCpgGrp}}               # Set of meth calls vecs in a region
    # Output
    ϕhat::Vector{Float64}                               # Estimated parameter vector ϕ
    Z::Float64                                          # Partition function evaluated @ ϕ
    ∇logZ::Vector{Float64}                              # Gradient of log likelihood @ ϕhat
    mml::Vector{Float64}                                # Mean methylation level
    nme::Float64                                        # Normalized methylation entropy
    nme_vec::Vector{Float64}                            # Normalized methylation entropy vector
    Σmat::UpperTriangular{Float64,Array{Float64,2}}     # Covariance matrix
    # Transfer matrix
    tm::TransferMat                                     # Arrays for transfer matrix methods
    # Expectations
    eXs::Expectations                                   # Expectations of estimation region
    # Init Methods
    RegStruct() = new(false,
        "",0,0,0,0,[],[],[],[],[],[],[],[],
        0,[],
        [],NaN,[],[],NaN,[],UpperTriangular(fill(NaN,(1,1))),
        TransferMat(),
        Expectations()
    )
    RegStruct(calls) = new(false,
        "",0,0,0,0,[],[],[],[],[],[],[],[],
        length(calls),calls,
        [],NaN,[],[],NaN,[],UpperTriangular(fill(NaN,(1,1))),
        TransferMat(),
        Expectations()
    )
end

# Struct methods
get_depth_ith_cpg(i::Int64,calls::Vector{Vector{MethCallCpgGrp}})::Float64 = sum([x[i].obs for x in calls])
get_ave_depth(reg::RegStruct)::Float64 = sum([get_depth_ith_cpg(i,reg.calls) for i=1:reg.L])/reg.L
is_grp_obs(i::Int64,calls::Vector{Vector{MethCallCpgGrp}})::Float64 = any([x[i].obs for x in calls] .== true)
perc_gprs_obs(reg::RegStruct)::Float64 = sum([is_grp_obs(i,reg.calls) for i=1:reg.L])/reg.L

##################################################################################################
## Hypothesis testing structs
##################################################################################################

# Structure for α-subregion used in testing
mutable struct SubregStatTestStruct
    # Fields
    proc::Bool                                          # Test done
    tmml_test::NTuple{2,Float64}                        # Pair (Tmml,Pmml)
    tnme_test::NTuple{2,Float64}                        # Pair (Tnme,Pnme)
    tpdm_test::NTuple{2,Float64}                        # Pair (Tpdm,Ppdm)
    # Init Methods
    SubregStatTestStruct() = new(false,(NaN,NaN),(NaN,NaN),(NaN,NaN))
end

# Structure for analysis region used in testing
mutable struct RegStatTestStruct
    # Fields
    id::String                                          # Analysis region ID
    chr::String                                         # Chromosome of analysis region
    chrst::Int64                                        # Start position of region (1-based)
    chrend::Int64                                       # End position of region (1-based)
    reg_tests::NTuple{2,Float64}                        # Region test
    subreg_cpg_occ::Vector{Bool}                        # Binary vector with subregion occupancy
    subreg_coords::Vector{NTuple{2,Int64}}              # Coordinates of α-subregions
    subreg_tests::Vector{SubregStatTestStruct}          # Subregion tests
    # Init method 1
    RegStatTestStruct() = new()
    # Init method 2
    function RegStatTestStruct(reg_id,cpg_occ)
        # Init
        reg = new()
        reg.id = reg_id
        reg_data = split(reg_id,"_")
        reg.chr = reg_data[1]
        reg.chrst = parse(Int,reg_data[2])
        reg.chrend = parse(Int,reg_data[3])
        reg.subreg_cpg_occ = cpg_occ
        reg.subreg_tests = Vector{SubregStatTestStruct}()
        return reg
    end
end