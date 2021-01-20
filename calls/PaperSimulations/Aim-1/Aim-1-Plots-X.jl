#################################################################################################
# AIM 1: X
#################################################################################################
## Deps
using Distributed
@everywhere using StatsPlots
@everywhere using Distributions
@everywhere using DelimitedFiles
@everywhere using Plots.PlotMeasures

## Constants
const noise_levels = [0.5,1.0,1.5,2.0,2.5,3.0]
const data_dir = "/Users/jordiabante/OneDrive - Johns Hopkins/CpelNano/Data/Simulations/Aim-1"

# Thresholds
const mega_thrs = collect(-3.0:0.03:0.0)
const deepsig_thrs = collect(0.0:0.01:1.0)
const nano_thrs = vcat(collect(-400.0:10.0:-20.0),collect(-20.0:0.1:20.0),collect(20.0:10.0:400.0))

# Colors
const blnd_col = ["#999999","#E69F00","#56B4E9","#009E73","#F0E442","#0072B2","#D55E00","#CC79A7"]
const call_thrs = Dict("nanopolish" => nano_thrs, "deepsignal" => deepsig_thrs,"megalodon" => mega_thrs)
const cllr_color_code = Dict("nanopolish" => blnd_col[1],"deepsignal" => blnd_col[end], "megalodon" => blnd_col[2])
const s_color_cde = Dict(0.5=>blnd_col[1],1.0=>blnd_col[2],1.5=>blnd_col[3],2.0=>blnd_col[4],2.5=>blnd_col[5],3.0=>blnd_col[6])

## Default attributes
default(titlefont=(14,"arial"),guidefont=(16,"arial"),tickfont=(12,"arial"))

# Function to threshold calls
function thresh_calls(true_x,conf_x,thrs)

    # Init output vectors
    out_true_x = []
    out_conf_x = []

    # Compare confidence score to threshold to determine call
    @inbounds for i=1:length(true_x)

        if conf_x[i]=="n/a"
            # Fails to detect
            push!(out_conf_x,-1)
            push!(out_true_x,true_x[i])
        elseif conf_x[i] < thrs
            # Negative
            push!(out_conf_x, -1)
            push!(out_true_x, true_x[i])
        elseif conf_x[i] >= thrs
            # Positive
            push!(out_conf_x, 1)
            push!(out_true_x, true_x[i])
        else
            println("Something went wrong when thresholding calls ...")
        end

    end

    return out_true_x,out_conf_x

end


# Function to compute accuracy
function comp_accu(truth,pred) 

    # Return accuracy
    return sum(truth.==pred)/length(truth)

end

# Function to compute precision
function comp_prec(truth,pred)

    # Get positives
    pos_ind = pred .== 1

    # Get true positives
    true_pos = sum(truth[pos_ind].==pred[pos_ind])

    # Return precision
    return true_pos/sum(pos_ind)

end

# Function to compute sensitivity (recall, or true positive rate)
function comp_sens(truth,pred)

    # Get positives
    pos_ind = pred .== 1

    # Get true positives
    if length(truth[pos_ind]) != 0
        true_pos = sum(truth[pos_ind].==pred[pos_ind])
    else
        return 0.0
    end

    # Return sensitivity
    return true_pos/sum(truth.==1)

end

# Function to compute specificity (selectivity or true negative rate)
function comp_spec(truth,pred)

    # Get negatives
    neg_ind = pred .== -1

    # Get prediction & truth
    if length(truth[neg_ind]) != 0
        true_neg = sum(truth[neg_ind].==pred[neg_ind])
    else
        return 0.0
    end
    
    # Return specificity
    return true_neg/sum(truth.==-1)

end

function pmap_noise_ex(caller,s)
    
    # Print noise level
    println("Working on sigma=$(s)")

    # Read in 
    in_data = readdlm("$(data_dir)/$(caller)/gm12878_chr22_sigma_$(s)_$(caller)_tuples_wth_missed_sample.tsv")

    # Get data 
    true_x = in_data[:,1]
    pred_x = in_data[:,3]

    # Return tuple
    return comp_accu(true_x,pred_x),comp_prec(true_x,pred_x),comp_sens(true_x,pred_x),comp_spec(true_x,pred_x)

end

#################################################################################################
# Performance of methylation callers with X_{n}
#################################################################################################

# Init plots
p1 = plot(ylabel="Accuracy (%)",title="Performance callers X_{n}",ylim=(0,100));
p2 = plot(ylabel="Precision (%)",ylim=(0,100));
p3 = plot(ylabel="Sensitivity (%)",ylim=(0,100));
p4 = plot(xlabel="Gaussian Noise at signal-level (\\sigma)",ylabel="Specificity (%)",ylim=(0,100));

for caller in keys(cllr_color_code)

    # Print caller
    println("Working on $(caller)")

    # Get error in call
    pmap_out = pmap(s->pmap_noise_ex(caller,s),noise_levels)
    
    # Unravel pmap out
    accu_vec = [x[1] for x in pmap_out]
    prec_vec = [x[2] for x in pmap_out]
    sens_vec = [x[3] for x in pmap_out]
    spec_vec = [x[4] for x in pmap_out]

    # Update plot
    col = cllr_color_code[caller]
    plot!(p1,noise_levels,accu_vec*100,seriestype=:scatter,markershape=:circle,color=col,label=caller)
    plot!(p1,noise_levels,accu_vec*100,seriestype=:line,alpha=0.5,color=col,label="")
    plot!(p2,noise_levels,prec_vec*100,seriestype=:scatter,markershape=:circle,color=col,label="")
    plot!(p2,noise_levels,prec_vec*100,seriestype=:line,alpha=0.5,color=col,label="")
    plot!(p3,noise_levels,sens_vec*100,seriestype=:scatter,markershape=:circle,color=col,label="")
    plot!(p3,noise_levels,sens_vec*100,seriestype=:line,alpha=0.5,color=col,label="")
    plot!(p4,noise_levels,spec_vec*100,seriestype=:scatter,markershape=:circle,color=col,label="")
    plot!(p4,noise_levels,spec_vec*100,seriestype=:line,alpha=0.5,color=col,label="")

end

# Generate plot & store
plot(p1,p2,p3,p4,layout=(4,1),size=(600,1000),top_margin=10px,bottom_margin=10px,left_margin=20px,right_margin=20px)
savefig("$(data_dir)/Benchmark-Callers-X.pdf")