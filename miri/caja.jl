module ModuloCaja

using HTTP
using JSON3
using Random

export Caja, create_caja, get_posicion_caja, set_estado_caja, get_estado_caja, start_server

mutable struct Caja
    posicion::Vector{Float64}
    angulo::Float64
    estado_caja::String
end

# Example box data storage
cajas = Dict{Int, Caja}()
caja_counter = 0

function create_caja(dimBoard, zonaDescarga)
    global caja_counter
    caja_counter += 1
    position = [rand() * 2 * dimBoard - dimBoard, rand() * (dimBoard - zonaDescarga) - (dimBoard - zonaDescarga), 0.0]
    caja = Caja(position, rand() * 2π, "esperando")
    cajas[caja_counter] = caja
    return caja_counter
end

function get_posicion_caja(id)
    return haskey(cajas, id) ? cajas[id].posicion : nothing
end

function get_estado_caja(id)
    return haskey(cajas, id) ? cajas[id].estado_caja : "not found"
end

function set_estado_caja(id, estado)
    if haskey(cajas, id)
        cajas[id].estado_caja = estado
        return "updated"
    end
    return "not found"
end

# Initialize some boxes on server start
function initialize_cajas()
    for i in 1:10  # Create 10 boxes as an example
        create_caja(250.0, 50.0)
    end
end

# Handle incoming requests for the box
function handle_caja_request(req)
    try
        body = String(req.body)
        json_data = JSON3.read(body)
        
        action = json_data["action"]
        id = json_data["id"]
        result = nothing
        
        if action == "get_posicion"
            result = get_posicion_caja(id)
        elseif action == "get_estado"
            result = get_estado_caja(id)
        elseif action == "set_estado"
            estado = json_data["estado"]
            result = set_estado_caja(id, estado)
        end
        
        return HTTP.Response(200, JSON3.write(Dict("result" => result)))
    catch e
        return HTTP.Response(500, "Error: $e")
    end
end

function start_server()
    initialize_cajas()  # Call this to create boxes before the server starts
    HTTP.serve(handle_caja_request, "127.0.0.1", 8082)
end

end  # End of module ModuloCaja