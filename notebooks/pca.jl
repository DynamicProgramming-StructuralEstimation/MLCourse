### A Pluto.jl notebook ###
# v0.17.2

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 8bd459cb-20bb-483e-a849-e18caae3beef
begin
    using Pkg
	Pkg.activate(joinpath(Pkg.devdir(), "MLCourse"))
    using MLCourse, MLJ, DataFrames, MLJMultivariateStatsInterface, OpenML,
    Plots, LinearAlgebra, Statistics, Random, CSV, MLJLinearModels
    chop(x, eps = 1e-12) = abs(x) > eps ? x : zero(typeof(x))
end

# ╔═╡ 1c3aa1be-c58a-4eb9-a192-ddfffa8a2c56
using TSne

# ╔═╡ b97724e4-d7b0-4085-b88e-eb3c5bcbe441
begin
    using PlutoUI
    PlutoUI.TableOfContents()
end

# ╔═╡ 31bcc3f0-88c1-4035-b0de-b4217623dc22
md"# Reconstructing a Generative Model with PCA

Let us assume a given data set ``X`` with ``p`` predictors was generated by some mixture of ``q \leq p`` hidden (=unobserved) predictors. Under some conditions PCA can recover these unobserved predictors from the data set ``X``.

## An Artificial Toy Example

In this example we generate 2-dimensional (hidden = unobserved) data and project it to 3 dimensions. This 3-dimensional input is our measured data that we take as input for PCA. We will find that PCA recovers in this case the original data."

# ╔═╡ e24cff15-a966-405a-b083-4b86be09c6f1
begin
    Random.seed!(17)
    h = [1.5 .5] .* randn(500, 2) # 2D data with higher variance along first dimension
    G = [-.3 .4 .866
         .885 .46 .1]             # projection matrix to 3D
    x = h * G                     # projected data
end;

# ╔═╡ 9e60bd23-bd0e-4311-a059-a39a70143307
let
	plotly()
	p1 = scatter(h[:, 1], h[:, 2], aspect_ratio = 1,
                 xlabel = "H₁", ylabel = "H₂",
                 label = "h", title = "original (hidden) 2D data")
	p2 = scatter3d(x[:, 1], x[:, 2], x[:, 3], markersize = 1,
                   xlabel = "X₁", ylabel = "X₂", zlabel = "X₃",
                   title = "measured 3D data")
	plot(p1, p2, layout = (1, 2), legend = false)
end

# ╔═╡ a0bb0a63-67e2-414e-a3f0-b76875c1295d
m1 = fit!(machine(PCA(), x));

# ╔═╡ 4439f803-e70f-4231-82e9-88bb574498f4
ĥ = MLJ.transform(m1, x);

# ╔═╡ e38cdfcf-362f-4e6e-81a2-e58334bb8d5f
let
    gr()
    scatter(h[:, 1], h[:, 2],
            xlabel = "H₁", ylabel = "H₂",
            aspect_ratio = 1, label = "original hidden data")
    scatter!(ĥ.x1, ĥ.x2, label = "reconstructed hidden data", markersize = 3)
end

# ╔═╡ 16843059-269e-4557-a4b9-5d7034f99ba8
md"We can see that the reconstructed hidden data almost perfectly matches the true hidden data. We can also see that the transposed of the reconstructed projection matrix `fitted_params(m1).projection` is close to the projection matrix `G` we used."

# ╔═╡ 6e033717-5815-4ffe-b991-81b72b99df9f
(fitted_params(m1).projection', G)

# ╔═╡ b25687fc-aa11-4843-9a89-31c4c9b5bc23
md"This example is specifically constructed for PCA to succeed. The conditions on which success relies are
1. the original data set has the largest variance along ``H_1``. You can change the data set such that it has higher variance along dimension ``H_2``. What happens in this case?
2. The rows of the projection matrix `G` have norm 1. What happens if you multiply the original `G` by 2?
3. `x` was obtained by linear transformation with `G` from `h`.
"

# ╔═╡ 14bfdb2d-fd71-4c62-8823-6e292a424bf5
md"## Reconstructing Spike Trains

Here is a more realistic - but still artificial - example. Let us assume we were interested in the activity of 2 neurons somewhere in a brain, firing at different moments in time an action potential with a shape that is characteristic for the neuron (see blue and red curve in the figure below). Each one of three electrodes that are placed in the brain tissue near these two neurons sense the two neurons in a way that depends on the relative positions of the electrodes and the neurons. The goal is to reconstruct from the measurements at the electrodes the activity of the neurons.
"

# ╔═╡ f6117412-f6d8-41d7-9524-dc25fc891deb
begin
    s1(t) = t < 0 ? 0 : (exp(-t/.2) - exp(-t/.01)) * sin(10*t)
    s2(t) = t < 0 ? 0 : (exp(-t/.5) - exp(-t/.3)) * sin(4*t)
end;

# ╔═╡ 9da3a52e-23ca-4ce4-8524-0abeb4be2306
let
    gr()
    t = -1:.02:3
    plot(t, s1.(t), label = "spike of neuron 1",
         xlabel = "time [arbitrary units]", ylabel = "voltage [arbitrary units]")
    plot!(t, s2.(t), label = "spike of neuron 2",
         xlabel = "time [arbitrary units]", ylabel = "voltage [arbitrary units]")
end

# ╔═╡ 00e15b1c-a12d-4ac2-b3c6-6fece1abef31
begin
    v1 = sum(s1.((0:.02:1000) .- ts) for ts in unique(rand(0:2:1000, 200))) .+ 1e-2*randn(50001)
	v2 = sum(s2.((0:.02:1000) .- ts) for ts in unique(rand(0:2:1000, 200))) .+ 1e-2*randn(50001)
end;

# ╔═╡ 60ba84d8-4f48-4d8a-b695-11edbe91ccc8
let
    gr()
    p1 = plot(v1, xlim = (0, 1000), title = "unobserved spike train",
              label = "v1", xlabel = "time", ylabel = "voltage")
    p2 = plot(v2, xlim = (0, 1000), label = "v2", xlabel = "time", ylabel = "voltage")
    p3 = scatter(v1, v2, aspect_ratio = 1,
                 label = nothing, xlabel = "v1", ylabel = "v2")
    plot(plot(p1, p2, layout = (2, 1)), p3, layout = (1, 2))
end

# ╔═╡ b256ff25-431a-4c47-8195-d958d3d28c56
sdata = [v2 v1] * G;

# ╔═╡ abb36d40-ad0e-442c-ab87-b15837a2541c
md"In the figure above you see on the left some time steps of our artificially generated neural activity patterns. Each dot in the figure on the right shows the voltages of the two neurons at a given moment in time.
We assume now that the electrodes measure `sdata`, which is obtained by mixing the originial data in three different ways; think of the 3 columns of `G` as the mixing coefficients. In reality the dependence of the electrode signal on the neural activity might not be as simple as we assume here."

# ╔═╡ e81b5dee-dffb-4a4c-b471-0974599fd87d
let
    gr()
    p1 = plot(sdata[:, 1], xlim = (0, 1000), title = "measured signal",
              label = "electrode 1",
              xlabel = "time", ylabel = "voltage", c = :black)
    p2 = plot(sdata[:, 2], xlim = (0, 1000), label = "electrode 2",
              xlabel = "time", ylabel = "voltage", c = :black)
    p3 = plot(sdata[:, 3], xlim = (0, 1000), label = "electrode 3",
              xlabel = "time", ylabel = "voltage", c = :black)
    p4 = scatter3d(sdata[:, 1], sdata[:, 2], sdata[:, 3],
                   xlabel = "electrode 1" , ylabel = "electrode 2",
                   zlabel = "electode 3", label = nothing, c = :black)
    plot(plot(p1, p2, p3, layout = (3, 1)),
         p4, layout = (1, 2), size = (700, 500))
end

# ╔═╡ 48528bf7-8a40-4773-944c-54d0446a5cac
sma = fit!(machine(PCA(mean = 0), sdata));

# ╔═╡ 9a5e0976-1c0e-45fc-855e-b0fbec801e8c
srec = MLJ.transform(sma, sdata);

# ╔═╡ b5d2986e-3723-4463-ab05-cc176aea60d8
let
	gr()
	p1 = plot(v1, label = "original v1")
	plot!(srec.x1, label = "reconstruction v1", xlim = (0, 1000))
	p2 = plot(v2, label = "original v2")
	plot!(srec.x2, label = "reconstruction v2", xlim = (0, 1000))
    p3 = scatter(v1, v2, label = "original")
	scatter!(srec.x1, srec.x2, aspect_ratio = 1, label = "reconstruction")
	plot(plot(p1, p2, layout = (2, 1)), p3, layout = (1, 2))
end

# ╔═╡ eb421c10-a023-4faa-bcfb-374b8ebb9c38
md"Also here we see that PCA recovers the original activity patterns. Note that the almost perfect reconstruction relies again on the three conditions specified in the previous section."

# ╔═╡ c1262304-6846-4811-ae82-397863255415
md"""# PCA Finds the Directions of Largest Variance

In the figure below you see a visualization of the variance along the first, second or third principal component (loading vectors ``\phi_1, \phi_2, \phi_3``). The colored lines are parallel to the loading vector you pick in the dropdown menu. They go from each data point to the "center"-plane that goes through the origin ``(0, 0, 0)`` and stands perpendicular to the picked component (loading vector). **The length of the line that starts at data point ``i`` is given by the score ``z_{ij}`` for principal component ``j``**. The average squared length of these lines is the variance along the chosen principal component.
"""

# ╔═╡ f9a506bb-6bdf-48aa-8f81-8fb6de078533
@bind pc Select(["1 PC", "2 PC", "3 PC"])

# ╔═╡ 2b73abbb-8cef-4da0-b4cf-b640fe0ad102
md"The `PCA` function in `MLJ` has three important keyword arguments as explained in the doc string (see Live docs). If the keyword argument `pratio = 1` all principal components are computed."

# ╔═╡ 45ee714c-9b73-492e-9422-69f27be79de2
md"The report of a `PCA` machine returns the number of dimensions `indim` of the data. the number of computed principal components `outdim`, the total variance `tvar` and the `mean` of the data set, together with the variances `principalvars` along the computed principal components. The sum of the variances `principalvars` is given in `tprincipalvar` and the rest in `tresidualvar = tvar - tprincipalvar`. If you change the `pratio` to a lower value above you will see that not all principal components are computed."

# ╔═╡ ecc77003-c138-4ea9-93a7-27df46aa1e89
md"Biplots are useful to see loadings and scores at the same time. The scores of each data point are given by the coordinates of the numbers plotted in gray when reading the bottom and the left axis. For example, the score for point 22 would be approximately (0, 4.8). The loadings are given by the red labels (not the tips of the arrows) when reading the top and the right axis. For examples the loadings of the first principal component are approximately (0.95, 0.1, 0.28) (see also `fitted_params` above)."

# ╔═╡ 18ad4980-2960-4ea9-8c9a-bf17cd3546ff
function data_generator(; seed = 71,  N = 100, rng = MersenneTwister(seed))
	h = [2.5 1.5 .8] .* randn(rng, N, 3)
    a1 = rand(); a2 = rand()
	G = [1 0 0
         0 cos(a1) -sin(a1)
         0 sin(a1) cos(a1)] * [cos(a2) 0 sin(a2)
                               0       1   0
                               -sin(a2) 0 cos(a2)]
	x = h * G
end;

# ╔═╡ b2688c20-a578-445f-a5c4-335c85931862
pca_data = data_generator(seed = 241);

# ╔═╡ 927627e0-9614-4234-823d-eb2e13229784
pca = fit!(machine(PCA(pratio = 1), DataFrame(pca_data, :auto)));

# ╔═╡ c7935f29-21f3-414a-b013-a1abd0f9f502
fitted_params(pca) # shows the loadings as columns

# ╔═╡ b52d72e3-64a3-4b7e-901b-3512b97aec23
report(pca)

# ╔═╡ 89406c26-7cba-4dd2-a6a3-8d572b440e01
biplot(pca)

# ╔═╡ 743477bb-6cf0-419e-814b-e774738e8d89
m2 = fit!(machine(PCA(maxoutdim = 2), pca_data));

# ╔═╡ 4a8188a0-c809-4014-9fef-cf6b5f830b1b
begin
    function pc_vectors(m)
        proj = fitted_params(m).projection
        a1 = proj[:, 1]
        a2 = proj[:, 2]
        a3 = cross(a1, a2)
        a3 ./= norm(a3)
        (a1, a2, a3)
    end
    function pca_plane(x, y, m)
        _, _, a3 = pc_vectors(m)
        a3 ./= a3[3]
        -a3[1]*x-a3[2]*y
    end
    pca_plane(x, y) = pca_plane(x, y, m2)
end;

# ╔═╡ 884a7428-2dd4-4091-b889-3acfbfa45d5b
let
    plotly()
    scatter3d(pca_data[:, 1], pca_data[:, 2], pca_data[:, 3],
              markersize = 1, label = nothing)
    a = pc_vectors(m2)
    col = [:red, :green, :orange]
    k = Meta.parse(pc[1:1])
    var = 0.
    for i in 1:size(pca_data, 1)
        s = pca_data[i, :]
        e = s - (a[k]'*s) * a[k]
        plot3d!([s[1], e[1]], [s[2], e[2]], [s[3], e[3]],
                color = col[k], w = 4, label = nothing)
    end
    plot3d!(xlim = (-7, 7), ylim = (-7, 7), zlim = (-7, 7), aspect_ratio = 1)
end


# ╔═╡ df9a5e8d-0692-44e4-8fd0-43e8643c4b7c
md"# PCA Finds Linear Subspaces Closest to the Data

The `fitted_params` of a `PCA` machine contain as columns the the principal component vectors. The first two components span a plane (see figure below). This plane is closest to the data in the sense that the average squared distance to each data point is minimal. There is no other plane that would be closer to the data points."

# ╔═╡ d3e5ca43-f70e-4a11-a3c9-fc0755179e4c
let
    plotly()
    scatter3d(pca_data[:, 1], pca_data[:, 2], pca_data[:, 3], markersize = 1, label = "data")
    a1, a2, a3 = pc_vectors(m2)
    a1 *= 2; a2 *= 2
    wireframe!(-8:.1:8, -8:.1:8, pca_plane,
               label = nothing, w = 1)
    plot3d!([-a1[1], a1[1]], [-a1[2], a1[2]], [-a1[3], a1[3]],
            c = :red, w = 10, label = "PC1")
    plot3d!([-a2[1], a2[1]], [-a2[2], a2[2]], [-a2[3], a2[3]],
            c = :green, arrow = true, w = 10, label = "PC2")
    for i in 1:size(pca_data, 1)
        s = pca_data[i, :]
        e = s - (a3'*s) * a3
        plot3d!([s[1], e[1]], [s[2], e[2]], [s[3], e[3]],
                color = :orange, label = i == 1 ? "distance to plane" : nothing, w = 4)
    end
    plot3d!()
end

# ╔═╡ 936570b9-43da-4c32-b15a-d595f690b1a6
md"
## Reconstructions of the Data

With ``X`` the ``100\times 3``-dimensional matrix of the original data, the reconstruction is given by ``X\Phi_L\Phi_L^T = Z_L\Phi_L^T`` with ``\Phi_L`` the ``3\times L``-dimensional matrix constructed from the first ``L`` loading vectors as columns. The reconstructions are closest to the original data while being forced to vary only along the first ``L`` principal components.

Reconstruction using the first $(@bind firstkpc Select(string.(1:3))) component(s).
"

# ╔═╡ 9032ad56-123c-4585-9b67-c94e5ecb3899
let
    plotly()
    scatter3d(pca_data[:, 1], pca_data[:, 2], pca_data[:, 3],
              markersize = 1, label = "data")
    a1, a2, a3 = pc_vectors(m2)
    ϕ = if firstkpc == "1"
        a1
    elseif firstkpc == "2"
        [a1 a2]
    else
        [a1 a2 a3]
    end
    rec = pca_data * ϕ * ϕ'
    scatter3d!(rec[:, 1], rec[:, 2], rec[:, 3], legend = false,
               markersize = 1, label = "reconstruction")
end


# ╔═╡ a8188f31-204a-406f-96a2-86768918a2f9
md"## PCA for Visualization"

# ╔═╡ 265594dd-ba59-408a-925a-c2a173343df7
wine = OpenML.load(187) |> DataFrame;

# ╔═╡ 51720585-09c8-40bb-8ec2-c2f25804d731
X = float.(select(wine, Not(:class)))

# ╔═╡ d45faa6b-706b-4990-80d9-32acc001b242
mwine = fit!(machine(@pipeline(Standardizer(), PCA()), X));

# ╔═╡ 6c8c86f0-02ec-4ce7-9d16-1b4865c344df
let
	gr()
	biplot(mwine)
end

# ╔═╡ e72c09e3-91cb-4455-9880-628428730efe
md"### Scaling the Data Matters!!!"

# ╔═╡ 9f6b1079-209f-4a24-96c8-81bdcf8bfc32
mwine2 = machine(PCA(pratio = 1), X) |> fit!;

# ╔═╡ 7eac92b8-0639-46b8-966e-cbf44de7ee86
let
	gr()
	biplot(mwine2)
end


# ╔═╡ ab17ef21-ea29-4d62-b14e-b87cffc0a1f9
md"# PCA Decorrelates

A principal component analysis can be performed by computing the covariance matrix ``X^T X`` and its eigenvalues. In the cell below you can see that the covariance matrix is not diagonal and that the eigenvalues (divided by ``n-1``) correspond to the variances along the different principal components.
"

# ╔═╡ da99f084-522b-4969-a65c-31d1548d3073
let
	X = pca_data .- mean(pca_data, dims = 1) # subtract the mean of each column
	(XtX = X'X, eigen_values = eigvals(X'X))
end

# ╔═╡ d88509c3-51ca-4ff9-9c1f-c3e13ec0e133
report(pca).principalvars * (size(pca_data, 1) - 1)

# ╔═╡ 615a823f-32df-469d-b2a3-e9d2c35e36a7
md"An interesting property of the scores is that their covariance matrix is diagonal, with the eigenvalues of ``X^TX`` on the diagonal. Hence we call PCA a decorrelating transformation."

# ╔═╡ ded0e6cd-e969-47d5-81cf-e2a967bc0a34
let
    mach = fit!(machine(PCA(pratio = 1), pca_data))
    Z = MLJ.matrix(MLJ.transform(mach, pca_data))
    (ZtZ = chop.(Z'*Z),) # chop sets values close to zero to zero.
end

# ╔═╡ 9724b203-ae86-4cb6-afec-68e26c01ab83
md"## PCA for Denoising"

# ╔═╡ 715a0e0c-5105-4fee-8b93-03a966a1bd8e
data = let t = 0:.1:8
    Random.seed!(1)
    DataFrame(hcat([rand((sin, cos)).(t) .+ .2*randn(length(t))
				    for _ in 1:2000]...)', :auto)
end;

# ╔═╡ 95ba7abd-c425-46d4-8382-fedec7ed58f6
let
    gr()
	plot(Array(data[1, :]))
	for i in 2:20
		plot!(Array(data[i, :]))
	end
	plot!(legend = false, xlabel = "time", ylabel = "voltage", title = "raw data")
end

# ╔═╡ d2bfdda4-4496-4daa-bcb5-51d9a7519823
mdenoise = fit!(machine(PCA(maxoutdim = 2, mean = 0), data));

# ╔═╡ 694ad552-3088-4872-bed5-89b4dfc67219
report(mdenoise)

# ╔═╡ c54b4211-36aa-4d7c-8e7a-c67cf5bdabdc
reconstruction = MLJ.inverse_transform(mdenoise, MLJ.transform(mdenoise, data));

# ╔═╡ b9383ef0-8499-4e56-a8d6-606ec128676c
let
	plot(Array(reconstruction[1, :]))
	for i in 2:20
		plot!(Array(reconstruction[i, :]))
	end
# 	plot!(s1.(0:.02:3), w = 2)
# 	plot!(s2.(0:.02:3), w = 2)
# 	plot!(s3.(0:.02:3), w = 2)
    plot!(legend = false, xlabel = "time", ylabel = "voltage",
          title = "denoised reconstruction")
end

# ╔═╡ af03d989-b19f-44ac-a275-d8af57bbeaeb
md"## PCA for Compression"

# ╔═╡ 026a362d-3234-409b-b9cb-e6a2a50c6a0d
faces = OpenML.load(41083) |> DataFrame;

# ╔═╡ e967a9cb-ad95-4bd2-8fbd-491dc6fe0475
let
    gr()
    plot(Gray.(vcat([[hcat([[reshape(Array(faces[j*8 + i, 1:end-1]), 64, 64)' ones(64)] for i in 1:8]...); ones(8*65)'] for j in 0:5]...)), ticks = false)
end

# ╔═╡ 0cb282aa-81d4-408d-a919-0d28cdbb7bed
pca_faces = fit!(machine(PCA(), faces[:, 1:end-1]));

# ╔═╡ c70b5212-a823-4ff8-937d-10919efc766c
let
    vars = report(pca_faces).principalvars ./ report(pca_faces).tvar
    p1 = plot(vars, label = nothing, yscale = :log10,
              xlabel = "component", ylabel = "proportion of variance explained")
    p2 = plot(cumsum(vars),
              label = nothing, xlabel = "component",
              ylabel = "cumulative prop. of variance explained")
    plot(p1, p2, layout = (1, 2), size = (700, 400))
end

# ╔═╡ 0742ea40-1895-48f4-b149-d472397e83d0
let
    pcs = fitted_params(pca_faces).projection
    scale = x -> (x .- minimum(x)) ./ (maximum(x) - minimum(x))
    plots = []
    for i in [1:5; size(pcs, 2)-4:size(pcs, 2)]
        push!(plots, plot(Gray.(scale(reshape(pcs[:, i], 64, 64))'),
                          title = "PC $i"))
    end
    plot(plots..., layout = (2, 5), showaxis = false, ticks = false)
end

# ╔═╡ 7c020b97-384d-43fc-af1c-a4bf75a6f06c
md"cumulative proportion of variance explained $(@bind pratio Slider(.9:.001:.999, show_value = true))"

# ╔═╡ cddfed10-7c9c-47b0-83fc-b3322da522ed
begin
    first_few_pc_faces = fit!(MLJ.machine(PCA(pratio = pratio), faces[:, 1:end-1]))
    npc = size(fitted_params(first_few_pc_faces).projection, 2)
    md"Using the first ``L = ``$npc components. The compression ratio is ``\frac{n\times p}{(p+n)\times L}`` = $(round(400*64^2/((64^2 + 400)*npc), sigdigits = 2))."
end

# ╔═╡ 03f92562-7419-4d8e-baa2-67f5b021219e
md"Image number $(@bind imgid Select(string.(1:nrow(faces))))"

# ╔═╡ 8e466825-0c84-41c7-93c6-e3cc81a60ef5
let
    gr()
    i = Meta.parse(imgid)
    p1 = plot(Gray.(reshape(Array(faces[i, 1:end-1]), 64, 64)'),
              ticks = false, title = "orginal")
    p2 = plot(Gray.(reshape(Array(MLJ.inverse_transform(first_few_pc_faces,
                                                       MLJ.transform(first_few_pc_faces,
                                                                     faces[i:i,1:end-1]))), 64, 64)'), ticks = false, title = "reconstruction")
    plot(p1, p2, layout = (1, 2), size = (700, 500))
end


# ╔═╡ 218d4c11-45a1-4d92-8b48-d08251804638
md"## PCA Applied to the Weather Data"

# ╔═╡ 0943f000-a148-4470-ae5e-9d8d39cd8207
begin
    weather = CSV.read(joinpath(@__DIR__, "..", "data", "weather2015-2018.csv"),
                       DataFrame);
    weather = select(weather, (x -> match(r"direction", x) == nothing && match(r"time", x) == nothing).(names(weather)))
end

# ╔═╡ 2e86337e-9fb8-4dd9-ac96-c1177e7ebd16
weather_mach = fit!(machine(@pipeline(Standardizer(), PCA()), weather));

# ╔═╡ 24179171-3992-4253-88a5-15ccdbb26e13
let
    gr()
    p1 = biplot(weather_mach)
    p2 = biplot(weather_mach, pc = (3, 4))
    plot(p1, p2, layout = (1, 2), size = (700, 400))
end

# ╔═╡ 8bc5f5b1-cda1-4018-a215-5a1900c2a9d2
let
    vars = report(weather_mach).pca.principalvars ./ report(weather_mach).pca.tprincipalvar
    p1 = plot(vars, label = nothing, yscale = :log10,
              xlabel = "component", ylabel = "proportion of variance explained")
    p2 = plot(cumsum(vars),
              label = nothing, xlabel = "component",
              ylabel = "cumulative prop. of variance explained")
    plot(p1, p2, layout = (1, 2), size = (700, 400))
end

# ╔═╡ d44be4c6-a409-421a-8e68-39fa752db4c0
md"# Limitations of PCA"

# ╔═╡ d3b769d7-ec71-4496-926a-e838c3b50c2a
begin
    Random.seed!(123)
    eight_clouds = DataFrame(vcat([[.5 .5 20] .* randn(50, 3) .+ [x y 0]
                             for y in (-2, 2), x in (-6, -2, 2, 6)]...), :auto);
    eight_clouds = MLJ.transform(fit!(machine(Standardizer(), eight_clouds)))
end;

# ╔═╡ 67395b94-46bd-43e5-9e12-0bd921de8203
let
    gr()
    c = vcat([fill(i, 50) for i in 1:8]...)
    p0 = scatter3d(eight_clouds.x1, eight_clouds.x2, eight_clouds.x3,
                   c = c, title = "original 3D data")
    p1 = scatter(eight_clouds.x1, eight_clouds.x2, c = c,
                 xlabel = "x", ylabel = "y", title = "projection onto X-Y")
    pc = MLJ.transform(fit!(machine(PCA(maxoutdim = 2), eight_clouds)))
    p2 = scatter(pc.x1, pc.x2, xlabel = "PC 1", ylabel = "PC 2", c = c,
                 title = "PCA projection")
    plot(p0, p1, p2, layout = (1, 3), legend = false, size = (700, 400))
end

# ╔═╡ e4302d86-5e4f-4c56-bdca-8b4eed2af47c
tsne_proj = tsne(Array(eight_clouds), 2, 0, 2000, 50.0);

# ╔═╡ 6b319dbe-c626-4294-92b6-cab574aabfb0
let
    gr()
    scatter(tsne_proj[:, 1], tsne_proj[:, 2], legend = false,
            c = vcat([fill(i, 50) for i in 1:8]...))
end

# ╔═╡ 716da1a0-266f-41ec-8ef3-a2593ac7b74b
Markdown.parse("Also for real data PCA sometimes fails to find the clusters in
the data. We demonstrate this here with the MNIST data set.

```julia
mnist_x, mnist_y = let df = OpenML.load(554) |> DataFrame
    coerce!(df, :class => Multiclass)
    coerce!(df, Count => MLJ.Continuous)
    select(df, Not(:class)),
    df.class
end

mnist_pca = fit!(machine(PCA(maxoutdim = 2), mnist_x));

let
    mnist_proj = MLJ.transform(mnist_pca)
    scatter(mnist_proj.x1, mnist_proj.x2, c = Int.(int(mnist_y)), legend = false,
            xlabel = \"PC 1\", ylabel = \"PC 2\")
end
```
$(MLCourse.embed_figure("mnist_pca.png"))

The dots are colored according to their MNIST class label.

Looking at this it may appear puzzling that K-Means found somewhat reasonable
clusters in the MNIST dataset.

However, let us look at a TSne dimensionality reduction:

```julia
tsne_proj_mnist = tsne(Array(mnist_x[1:5000, :]), 2, 50, 1000, 20)
scatter(tsne_proj_mnist[:, 1], tsne_proj_mnist[:, 2],
        c = Int.(int(mnist_y[1:5000])),
        xlabel = \"TSne 1\", ylabel = \"TSne 2\",
        legend = false)
```
$(MLCourse.embed_figure("mnist_tsne.png"))

Here the images with different class labels are more clearly grouped into different clusters.
")

# ╔═╡ 3087540f-19e1-49cb-9b3b-c23207775ea7
md"# Principal Component Regression"

# ╔═╡ 60c37ce2-50d7-426f-9dd8-597878425f9c
pcr_data_x, pcr_data_y = let p1 = 10, p2 = 50, n = 120
	hidden = randn(n, p1)
	β = randn(p1)
	y = hidden * β .+ .1 * randn(n)
	transformation = randn(p1, p2)
	x = hidden * transformation .+ .1 * randn(n, p2)
	DataFrame(x, :auto), y
end;

# ╔═╡ 42aa3526-bd02-41fa-aae5-b5a8f3355b86
begin
	train_idx = rand((true, false), 120)
	test_idx = (!).(train_idx)
end;

# ╔═╡ 422026f0-8c87-471a-af51-ba6273f293b2
mach1 = fit!(machine(MLJLinearModels.LinearRegressor(),
		             pcr_data_x[train_idx, :],
		             pcr_data_y[train_idx]));

# ╔═╡ 3148b8bd-63fc-4052-a899-656d2c2057f8
rmse(predict(mach1, pcr_data_x[test_idx, :]), pcr_data_y[test_idx])

# ╔═╡ 434f1616-e028-4043-9aef-049e490525f5
mach2 = fit!(machine(@pipeline(PCA(), MLJLinearModels.LinearRegressor()),
		             pcr_data_x[train_idx, :],
		             pcr_data_y[train_idx]));

# ╔═╡ 9283a9d2-355b-439b-98b6-d8491904eb05
rmse(predict(mach2, pcr_data_x[test_idx, :]), pcr_data_y[test_idx])

# ╔═╡ eea3f7f8-83ab-4942-9017-504f340ad95b
md"""# Exercises

## Conceptual

**Exercise 1**

(a) The figure below shows 2-dimensional data points. Let us perform PCA on this dataset, i.e. estimate graphically the principal component loadings ``\phi_{11}, \phi_{21}, \phi_{12}, \phi_{22}``. *Hint*: start with determining graphically the direction of the first and the second principal component and normalize the direction vectors afterwards.

$(Random.seed!(818); let x = ([6 4] .* randn(400, 2)) * [-1 1
                                      -2 -.01]
    scatter(x[:, 1], x[:, 2], xlim = (-32, 32), ylim = (-16, 16),
            aspect_ratio = 1, legend = false, xlabel = "X₁", ylabel = "X₂")
  end)

(b) In the figure below you see the scores of ``n = 40`` measuments and the loadings of a principal component analysis. How many features ``p`` were measured in this data set?

$(Random.seed!(17); let data = DataFrame(Array(DataFrame(X1 = 6*randn(40), X2 = 4 * randn(40), X3 = randn(40)*2, X4 = randn(40)*2)) * randn(4, 4), :auto)
    biplot(fit!(machine(PCA(), data)))
end
)

(c) Estimate from the figure in (b) the loadings of the first two principal components and the scores of data point 35.

**Exercise 2**
The figures show biplots of principal component analysis applied to 30 three-dimensional points.

$(Random.seed!(123); let d = DataFrame(randn(30, 2) * randn(2, 3) .+ randn(30, 3) * 1e-6, :auto)
    p = fit!(machine(PCA(pratio = 1, mean = 0), d))
    plot(biplot(p), biplot(p, pc = (1, 3)), layout = (1, 2), size = (700, 350))
end)

(a) In which direction does this dataset have the highest variance? Give your answer as a vector with coefficients determined approximately from the figure.

(b) Is the two-dimensional plane that is closest to the data parallel to the plane spanned by x1 and x3? Justify your answer with a few words.

(c) How large approximately is the proportion of variance explained by the third component?


**Exercise 3** In this exercise you will explore the connection between PCA and SVD.

(a) In the lecture we said that the first principal component is the eigenvector ``\phi_1`` with the largest eigenvalue ``\lambda_1`` of the matrix ``X^T X``. From linear algebra you know that a real, symmetric matrix ``A`` can be diagonalized such that ``A = W \Lambda W^T`` holds, where ``\Lambda`` is a diagonal matrix that contains the eigenvalues and ``W`` is an orthogonal matrix that satisfies ``W^T W = I``, where ``I`` is the identity matrix. The columns of ``W`` are the eigenvectors of ``A``. Let us assume we have found the diagonalization ``X^T X = W \Lambda W^T``. Multiply this equation from the right with ``W`` and show that the columns of ``W`` contain the eigenvectors of ``X^T X``.

(b) The singular value decomposition (SVD) of ``X`` is ``X = U\Sigma V^T`` where ``U`` and ``V`` are orthogonal matrices and ``\Sigma`` is a diagonal matrix. Use the singular value decomposition to express the right-hand-side of ``X^TX = ...`` in terms of ``U``, ``V`` and ``\Sigma``, show how ``U, V, \Sigma, W`` and ``\Lambda`` relate to each other and prove the statements on slide 11 of the lecture. *Hint*: the product of two diagonal matrices is again a diagonal matrix.


## Applied

**Exercise 1** Look at the following three artificial data sets.

```julia
data1 = DataFrame(randn(50, 2) * randn(2, 3), :auto)
data2 = DataFrame(randn(50, 2) * randn(2, 3) .+ 0.5*randn(50, 3), :auto)
data3 = DataFrame(randn(50, 2) * randn(2, 10), :auto)
```

(a) Plot the datasets `data1` and `data2` with `scatter3d`. *Hint:* Plots can be displayed with different plotting backends. If you run `plotly()` in a cell of your notebook you switch to the interactive but slow plotly backendend. If you want a non-interactive but fast backend, run `gr()`.

(b) Write down your expectations on the curve of proportion of variance
explained for the tree datasets.

(c) Perform PCA and plot the proportion of variance explained.

**Exercise 2** In this exercise we look at a food consumption dataset with the relative
consumption of certain food items in European countries. The
numbers represent the percentage of the population consuming that food type.
You can load the data with
```julia
using CSV, DataFrames
data = CSV.read(download(\"https://openmv.net/file/food-consumption.csv\"), DataFrame)
```

(a) Perform PCA on this dataset and produce a two biplots: one with PC1 versus
PC2 and another with PC1 versus PC3. *Hint*: before applying PCA you may have to deal with missing data (see notebook on transformations) and convert integers to floating point numbers with `coerce!(data, Count => Continuous)`.

(b) Which are the important variables in the first three components?

(c) What does it mean for a country to have a high score in the first component?
Pick one country that has a high score in the first component and verify that
this country does indeed have this interpretation.

**Exercise 3**
Take a random image e.g.
```julia
using FileIO, Plots
img = FileIO.load(download(\"http://kenia.pordescubrir.com/wp-content/uploads/2008/08/windsurf.jpg\"))
```
Transform it to grayscale with `Gray.(img)` and to a data frame with
`DataFrame(float.(real.(Gray.(img))), :auto)`.

The goal is to compress this image with PCA.
To do so, treat each row of this image as a single data point.

(a) Perform PCA on this data.

(b) Reconstruct the image with as many principal components needed to explain 99% of variance.

(c) How many numbers are needed to store the image in this compressed form?

(d) How big is the compression factor?

"""

# ╔═╡ b574a023-21e4-4ae2-a198-7c9962368713
MLCourse.list_notebooks(@__FILE__)


# ╔═╡ 147f9c9c-72dd-4003-90b1-33fd68d762ce
MLCourse.footer()

# ╔═╡ Cell order:
# ╠═8bd459cb-20bb-483e-a849-e18caae3beef
# ╟─31bcc3f0-88c1-4035-b0de-b4217623dc22
# ╠═e24cff15-a966-405a-b083-4b86be09c6f1
# ╟─9e60bd23-bd0e-4311-a059-a39a70143307
# ╠═a0bb0a63-67e2-414e-a3f0-b76875c1295d
# ╠═4439f803-e70f-4231-82e9-88bb574498f4
# ╟─e38cdfcf-362f-4e6e-81a2-e58334bb8d5f
# ╟─16843059-269e-4557-a4b9-5d7034f99ba8
# ╠═6e033717-5815-4ffe-b991-81b72b99df9f
# ╟─b25687fc-aa11-4843-9a89-31c4c9b5bc23
# ╟─14bfdb2d-fd71-4c62-8823-6e292a424bf5
# ╠═f6117412-f6d8-41d7-9524-dc25fc891deb
# ╟─9da3a52e-23ca-4ce4-8524-0abeb4be2306
# ╟─00e15b1c-a12d-4ac2-b3c6-6fece1abef31
# ╟─60ba84d8-4f48-4d8a-b695-11edbe91ccc8
# ╠═b256ff25-431a-4c47-8195-d958d3d28c56
# ╟─abb36d40-ad0e-442c-ab87-b15837a2541c
# ╟─e81b5dee-dffb-4a4c-b471-0974599fd87d
# ╠═48528bf7-8a40-4773-944c-54d0446a5cac
# ╠═9a5e0976-1c0e-45fc-855e-b0fbec801e8c
# ╟─b5d2986e-3723-4463-ab05-cc176aea60d8
# ╟─eb421c10-a023-4faa-bcfb-374b8ebb9c38
# ╟─c1262304-6846-4811-ae82-397863255415
# ╠═b2688c20-a578-445f-a5c4-335c85931862
# ╟─f9a506bb-6bdf-48aa-8f81-8fb6de078533
# ╟─884a7428-2dd4-4091-b889-3acfbfa45d5b
# ╟─2b73abbb-8cef-4da0-b4cf-b640fe0ad102
# ╠═927627e0-9614-4234-823d-eb2e13229784
# ╠═c7935f29-21f3-414a-b013-a1abd0f9f502
# ╟─45ee714c-9b73-492e-9422-69f27be79de2
# ╠═b52d72e3-64a3-4b7e-901b-3512b97aec23
# ╟─ecc77003-c138-4ea9-93a7-27df46aa1e89
# ╠═89406c26-7cba-4dd2-a6a3-8d572b440e01
# ╟─743477bb-6cf0-419e-814b-e774738e8d89
# ╟─18ad4980-2960-4ea9-8c9a-bf17cd3546ff
# ╟─4a8188a0-c809-4014-9fef-cf6b5f830b1b
# ╟─df9a5e8d-0692-44e4-8fd0-43e8643c4b7c
# ╟─d3e5ca43-f70e-4a11-a3c9-fc0755179e4c
# ╟─936570b9-43da-4c32-b15a-d595f690b1a6
# ╟─9032ad56-123c-4585-9b67-c94e5ecb3899
# ╟─a8188f31-204a-406f-96a2-86768918a2f9
# ╠═265594dd-ba59-408a-925a-c2a173343df7
# ╠═51720585-09c8-40bb-8ec2-c2f25804d731
# ╠═d45faa6b-706b-4990-80d9-32acc001b242
# ╟─6c8c86f0-02ec-4ce7-9d16-1b4865c344df
# ╟─e72c09e3-91cb-4455-9880-628428730efe
# ╠═9f6b1079-209f-4a24-96c8-81bdcf8bfc32
# ╟─7eac92b8-0639-46b8-966e-cbf44de7ee86
# ╟─ab17ef21-ea29-4d62-b14e-b87cffc0a1f9
# ╠═da99f084-522b-4969-a65c-31d1548d3073
# ╠═d88509c3-51ca-4ff9-9c1f-c3e13ec0e133
# ╟─615a823f-32df-469d-b2a3-e9d2c35e36a7
# ╠═ded0e6cd-e969-47d5-81cf-e2a967bc0a34
# ╟─9724b203-ae86-4cb6-afec-68e26c01ab83
# ╠═715a0e0c-5105-4fee-8b93-03a966a1bd8e
# ╟─95ba7abd-c425-46d4-8382-fedec7ed58f6
# ╠═d2bfdda4-4496-4daa-bcb5-51d9a7519823
# ╠═694ad552-3088-4872-bed5-89b4dfc67219
# ╠═c54b4211-36aa-4d7c-8e7a-c67cf5bdabdc
# ╟─b9383ef0-8499-4e56-a8d6-606ec128676c
# ╟─af03d989-b19f-44ac-a275-d8af57bbeaeb
# ╠═026a362d-3234-409b-b9cb-e6a2a50c6a0d
# ╟─e967a9cb-ad95-4bd2-8fbd-491dc6fe0475
# ╠═0cb282aa-81d4-408d-a919-0d28cdbb7bed
# ╠═c70b5212-a823-4ff8-937d-10919efc766c
# ╟─0742ea40-1895-48f4-b149-d472397e83d0
# ╟─7c020b97-384d-43fc-af1c-a4bf75a6f06c
# ╟─cddfed10-7c9c-47b0-83fc-b3322da522ed
# ╟─03f92562-7419-4d8e-baa2-67f5b021219e
# ╟─8e466825-0c84-41c7-93c6-e3cc81a60ef5
# ╟─218d4c11-45a1-4d92-8b48-d08251804638
# ╠═0943f000-a148-4470-ae5e-9d8d39cd8207
# ╠═2e86337e-9fb8-4dd9-ac96-c1177e7ebd16
# ╟─24179171-3992-4253-88a5-15ccdbb26e13
# ╟─8bc5f5b1-cda1-4018-a215-5a1900c2a9d2
# ╟─d44be4c6-a409-421a-8e68-39fa752db4c0
# ╠═d3b769d7-ec71-4496-926a-e838c3b50c2a
# ╟─67395b94-46bd-43e5-9e12-0bd921de8203
# ╠═1c3aa1be-c58a-4eb9-a192-ddfffa8a2c56
# ╠═e4302d86-5e4f-4c56-bdca-8b4eed2af47c
# ╟─6b319dbe-c626-4294-92b6-cab574aabfb0
# ╟─716da1a0-266f-41ec-8ef3-a2593ac7b74b
# ╟─3087540f-19e1-49cb-9b3b-c23207775ea7
# ╠═60c37ce2-50d7-426f-9dd8-597878425f9c
# ╠═42aa3526-bd02-41fa-aae5-b5a8f3355b86
# ╠═422026f0-8c87-471a-af51-ba6273f293b2
# ╠═3148b8bd-63fc-4052-a899-656d2c2057f8
# ╠═434f1616-e028-4043-9aef-049e490525f5
# ╠═9283a9d2-355b-439b-98b6-d8491904eb05
# ╟─eea3f7f8-83ab-4942-9017-504f340ad95b
# ╟─b97724e4-d7b0-4085-b88e-eb3c5bcbe441
# ╟─b574a023-21e4-4ae2-a198-7c9962368713
# ╟─147f9c9c-72dd-4003-90b1-33fd68d762ce
