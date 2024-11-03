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
    num_robots = try parse(Int, jsonpayload()["num_robots"]) catch e 5 end
    num_packages = try parse(Int, jsonpayload()["num_packages"]) catch e 20 end

    # Create simulation ID
    id = string(uuid1())
  
    # Initialize robots and packages
    dim_board = 250.0
    zona_descarga = 50.0
    robots = [ModuloRobot.crearRobot(dim_board, zona_descarga, 5.0, i + 1, num_robots, num_robots, 20.0)
              for i in 1:num_robots]
    boxes = [ModuloCaja.crearCaja(dim_board, zona_descarga, 20.0) for _ in 1:num_packages]
  
    instances[id] = robots
    paquetes[id] = boxes
  
    # Use to_dict to serialize
    json(Dict(
        "id" => id,
        "robots" => [ModuloRobot.to_dict(robot) for robot in robots],
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
        ModuloRobot.update(robot, boxes)
    end

    # Use to_dict to serialize each robot with the num_boxes_in_stacks
    json(Dict(
        "robots" => [ModuloRobot.to_dict(robot) for robot in robots],
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
