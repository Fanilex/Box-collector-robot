include("caja.jl")
include("robot.jl")

using .ModuloRobot  # Ensure this matches the module name in robot.jl
using .ModuloCaja   # Ensure this matches the module name in caja.jl
using Genie, Genie.Renderer.Json, Genie.Requests
using UUIDs

# Global state management
instances = Dict()
paquetes = Dict()

# Initialize simulation route
route("/simulation", method = POST) do
    num_robots = try
        parse(Int, jsonpayload()["num_robots"])
    catch
        5  # Default number of robots
    end
    num_packages = try
        parse(Int, jsonpayload()["num_packages"])
    catch
        20  # Default number of packages
    end

    # Create simulation ID
    id = string(uuid1())
    
    # Parámetros de la simulación
    dim_board = 250.0
    zona_descarga = 50.0
    total_lanes = 5
    margin = 20.0
    
    # Create robots
    robots = [ModuloRobot.crearRobot(dim_board, zona_descarga, 5.0, i + 1, num_robots, total_lanes, margin)
          for i in 1:num_robots]


    # Create packages
    boxes = [ModuloCaja.crearCaja(dim_board, zona_descarga, margin) for _ in 1:num_packages]

    
    # Store in instances
    instances[id] = robots
    paquetes[id] = boxes
    
    # Return simulation ID and initial state
    json(Dict(
        "id" => id,
        "robots" => [(
            position = ModuloRobot.get_posicion(robot),
            angle = ModuloRobot.get_angulo(robot),
            state = ModuloRobot.get_estado_robot(robot)
        ) for robot in robots],
        "packages" => [ModuloCaja.to_dict(box) for box in boxes]
    ))
end

# Update simulation route
route("/simulation/:id", method = POST) do
    id = payload(:id)
    if !haskey(instances, id)
        return json(Dict("error" => "Simulation not found")), 404
    end
    
    robots = instances[id]
    boxes = paquetes[id]
    
    # Update simulation with the boxes list
    for robot in robots
        ModuloRobot.update(robot, boxes)  # Pass `boxes` as the second argument
        
        if ModuloRobot.get_estado_robot(robot) == "buscar"
            for box in boxes
                if ModuloCaja.get_estado_caja(box) != "esperando"
                    continue
                end
                
                robot_pos = ModuloRobot.get_posicion(robot)
                box_pos = ModuloCaja.get_posicion_caja(box)
                dist = sqrt((robot_pos[1] - box_pos[1])^2 + (robot_pos[2] - box_pos[2])^2)
                
                println("Distance to box: ", dist)  # Debug: Check distance
                
                if dist < 10
                    println("Collision detected! Transporting box...")  # Debug: Collision log
                    ModuloRobot.transportar(robot, box)
                    println("Box picked up by robot")  # Confirm the robot has picked up the box
                    break
                end
            end
        end
    end
    
    # Return updated state
    json(Dict(
        "robots" => [(
            position = ModuloRobot.get_posicion(robot),
            angle = ModuloRobot.get_angulo(robot),
            state = ModuloRobot.get_estado_robot(robot)
        ) for robot in robots],
        "packages" => [ModuloCaja.to_dict(box) for box in boxes]
    ))
end

# Clean up route
route("/simulation/:id", method = DELETE) do
    id = payload(:id)
    delete!(instances, id)
    delete!(paquetes, id)
    json(Dict("status" => "deleted"))
end

# Configure CORS
Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

# Start server
up(8000)
