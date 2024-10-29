using Agents
using CairoMakie

@agent struct Ghost(GridAgent{2})
    type::String = "Ghost"
end

movimientos = [
    (0, 1),  
    (1, 0),  
    (0, -1), 
    (-1, 0)  
]

function agent_step!(agent, model)
    
    #randomwalk!(agent, model)
    #move = rand(movimientos_v)
    (dx, dy) = (0, 1)
    new_pos = (agent.pos[1] + dx, agent.pos[2] + dy) 
    move_agent!(agent, new_pos, model)
end

function initialize_model()
    space = GridSpace((50,50); periodic = false, metric = :manhattan)
    model = StandardABM(Ghost, space; agent_step!)
    add_agent!(Ghost, pos=(3, 3), model)
    return model
end

# model = initialize_model()
# a = add_agent!(Ghost, pos=(3, 3), model)