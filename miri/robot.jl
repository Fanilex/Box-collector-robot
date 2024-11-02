module ModuloRobot

using HTTP
using JSON3
using Random
using LinearAlgebra

export Robot, create_robot, update_robot, transportar, soltar
export get_estado_robot, get_posicion, get_angulo, start_server

mutable struct Robot
    dimBoard::Float64
    zonaDescarga::Float64
    posicion::Vector{Float64}
    estado_robot::String
    contador::Int
    puntoCarga::Vector{Float64}
    caja_recogida::Union{Nothing, Int}
    angulo::Float64
    velocidad::Float64
end

# Example robot data storage
robots = Dict{Int, Robot}()
robot_counter = 0

function create_robot(dimBoard, zonaDescarga, vel)
    global robot_counter
    robot_counter += 1
    position = [rand() * 2 * dimBoard - dimBoard, rand() * 2 * dimBoard - dimBoard, 0.0]
    robot = Robot(dimBoard, zonaDescarga, position, "buscar", 0, zeros(3), nothing, rand() * 2π, vel)
    robots[robot_counter] = robot
    return robot_counter
end

function get_posicion(id)
    return haskey(robots, id) ? robots[id].posicion : nothing
end

function get_estado_robot(id)
    return haskey(robots, id) ? robots[id].estado_robot : "not found"
end

function get_angulo(id)
    return haskey(robots, id) ? robots[id].angulo : nothing
end

function update_robot(id)
    if !haskey(robots, id)
        return "Robot not found"
    end
    robot = robots[id]
    # Update logic for the robot (for example, move forward)
    robot.posicion[1] += cos(robot.angulo) * robot.velocidad
    robot.posicion[2] += sin(robot.angulo) * robot.velocidad
    return "updated"
end

function transportar(id, caja_id)
    if !haskey(robots, id)
        return "Robot not found"
    end
    robot = robots[id]
    robot.caja_recogida = caja_id
    robot.estado_robot = "caja_recogida"
    return "transporting"
end

# Initialize some robots on server start
function initialize_robots()
    for i in 1:5  # Create 5 robots as an example
        create_robot(250.0, 50.0, 3.0)
    end
end

# Handle incoming requests for the robot
function handle_robot_request(req)
    try
        body = String(req.body)
        json_data = JSON3.read(body)
        
        action = json_data["action"]
        id = json_data["id"]
        result = nothing
        
        if action == "get_posicion"
            result = get_posicion(id)
        elseif action == "get_estado"
            result = get_estado_robot(id)
        elseif action == "get_angulo"
            result = get_angulo(id)
        elseif action == "update"
            result = update_robot(id)
        elseif action == "transportar"
            caja_id = json_data["caja_id"]
            result = transportar(id, caja_id)
        end
        
        return HTTP.Response(200, JSON3.write(Dict("result" => result)))
    catch e
        return HTTP.Response(500, "Error: $e")
    end
end

function start_server()
    initialize_robots()  # Call this to create robots before the server starts
    HTTP.serve(handle_robot_request, "127.0.0.1", 8081)
end

end  # End of module ModuloRobot