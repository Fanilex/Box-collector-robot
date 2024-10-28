using Agents
using CairoMakie

@agent struct Ghost(GridAgent{2})
    type::String = "Ghost"
end

function agent_step!(agent, model)
    
    randomwalk!(agent, model)
end

function initialize_model()
    space = GridSpace((50,50); periodic = false, metric = :manhattan)
    model = StandardABM(Ghost, space; agent_step!)
    add_agent!(Ghost, pos=(3, 3), model)
    return model
end

# model = initialize_model()
# a = add_agent!(Ghost, pos=(3, 3), model)