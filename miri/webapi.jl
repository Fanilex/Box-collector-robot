# webapi.jl
using HTTP
using JSON3

# Include the agent modules
include("caja.jl")
include("robot.jl")

# Import modules
const ModuloCaja = Main.ModuloCaja
const ModuloRobot = Main.ModuloRobot

function handle_request(req)
    try
        body = String(req.body)
        json_data = JSON3.read(body)
        
        result = nothing  # Default result in case of an unknown request
        if json_data["agent"] == "robot"
            if json_data["action"] == "get_posicion"
                robot_id = json_data["id"]
                result = ModuloRobot.get_posicion(robot_id)
            elseif json_data["action"] == "get_estado"
                robot_id = json_data["id"]
                result = ModuloRobot.get_estado_robot(robot_id)
            elseif json_data["action"] == "get_angulo"
                robot_id = json_data["id"]
                result = ModuloRobot.get_angulo(robot_id)
            elseif json_data["action"] == "update"
                robot_id = json_data["id"]
                ModuloRobot.update(robot_id)
                result = "updated"
            elseif json_data["action"] == "transportar"
                robot_id = json_data["parameters"]["robot"]
                caja_id = json_data["parameters"]["caja"]
                ModuloRobot.transportar(robot_id, caja_id)
                result = "transported"
            end
        elseif json_data["agent"] == "caja"
            if json_data["action"] == "get_posicion"
                caja_id = json_data["id"]
                result = ModuloCaja.get_posicion_caja(caja_id)
            elseif json_data["action"] == "get_estado"
                caja_id = json_data["id"]
                result = ModuloCaja.get_estado_caja(caja_id)
            elseif json_data["action"] == "get_angulo"
                caja_id = json_data["id"]
                result = ModuloCaja.get_angulo_caja(caja_id)
            end
        else
            return HTTP.Response(400, "Unknown agent or action")
        end
        
        # Check if result was set and return response
        if isnothing(result)
            return HTTP.Response(404, "Action not handled in Julia server")
        else
            return HTTP.Response(200, JSON3.write(Dict("result" => result)))
        end
    catch e
        println("Error processing request: $e")
        return HTTP.Response(500, "Internal server error: $e")
    end
end

# Start the HTTP server
HTTP.serve(handle_request, "127.0.0.1", 8080)