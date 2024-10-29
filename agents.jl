using Agents
using CairoMakie


@agent struct Ghost(GridAgent{2})
    id::Int
    type::String = "Ghost"
end

function agent_step!(agent, model)
  
   #randomwalk!(agent, model)
   #move = rand(movimientos_v)
   (dx, dy) = (0, 1)
   new_pos = (agent.pos[1] + dx, agent.pos[2] + dy)
   move_agent!(agent, new_pos, model)
end


function initialize_model()
   space = GridSpace((50, 50); periodic = false, metric = :manhattan)
   model = StandardABM(Ghost, space; agent_step!)


   # Add 5 agents horizontally aligned at positions (x, 3) with different x values
   for i in 1:5
       add_agent!(Ghost, pos=(3 + i * 2, 3), model)
   end

   robots = [
        Robot(1, v1)
        Robot(2, v2)
        Robot(3, v3)
        Robot(4, v4)
        Robot(5, v5)
   ]

   return model
end

