using Agents
using CairoMakie
using Random

@agent struct Ghost(GridAgent{2})
    type::String = "Ghost"
end

function agent_step!(agent, model)
    (dx, dy) = (0, 1)
    new_pos = (agent.pos[1] + dx, agent.pos[2] + dy)
    move_agent!(agent, new_pos, model)
end

function initialize_model()
    space = GridSpace((50, 50); periodic = false, metric = :manhattan)
    model = StandardABM(Ghost, space; agent_step!)
    return model
end

function generate_random_boxes(num_boxes::Int)
    boxes = []
    for _ in 1:num_boxes
        x = rand(-450:450)  # Random x position within the OpenGL window
        y = rand(-270:270)  # Random y position within the OpenGL window
        push!(boxes, (x, y))  # Store the position as a tuple
    end
    return boxes
end

