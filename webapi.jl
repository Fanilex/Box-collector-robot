include("agents.jl")
using Genie, Genie.Renderer.Json, Genie.Requests, HTTP
using UUIDs


instances = Dict()


route("/simulations", method = POST) do
   payload = jsonpayload()

   model = initialize_model()
   id = string(uuid1())
   instances[id] = model

   agents = []
   for ghost in allagents(model)
       push!(agents, ghost)
   end

   json(Dict("Location" => "/simulations/$id", "agents" => agents))
end

route("/simulations/:id") do
    println(payload(:id))
    model = instances[payload(:id)]
    run!(model, 1)
    agents = []
    for ghost in allagents(model)
        push!(agents, ghost)
    end
    
    json(Dict("agents" => agents))
end

Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

up()

