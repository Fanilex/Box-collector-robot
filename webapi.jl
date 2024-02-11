# webapi.jl

include("caja.jl")
include("robot.jl")

using .ModuloRobot  # Asegúrate de que coincide con el nombre del módulo en robot.jl
using .ModuloCaja   # Asegúrate de que coincide con el nombre del módulo en caja.jl
using Genie, Genie.Renderer.Json, Genie.Requests
using UUIDs

# Parámetros de la simulación
dim_board = 250.0
zona_descarga = 50.0
margin = 20.0

# Gestión del estado global
instances = Dict()
paquetes = Dict()

# Ruta para inicializar la simulación
route("/simulation", method = POST) do
    num_robots = try parse(Int, jsonpayload()["num_robots"]) catch e 5 end
    num_packages = try parse(Int, jsonpayload()["num_packages"]) catch e 20 end

    # Crear ID de simulación
    id = string(uuid1())

    # Crear robots
    robots = [ModuloRobot.crearRobot(dim_board, zona_descarga, 5.0, i + 1, num_robots, margin)
              for i in 1:num_robots]

    # Crear cajas
    boxes = [ModuloCaja.crearCaja(dim_board, zona_descarga, margin) for _ in 1:num_packages]

    # Almacenar en instancias
    instances[id] = robots
    paquetes[id] = boxes

    # Devolver ID de simulación y estado inicial
    json(Dict(
        "id" => id,
        "robots" => [ModuloRobot.to_dict(robot) for robot in robots],
        "packages" => [ModuloCaja.to_dict(box) for box in boxes]
    ))
end

# Ruta para actualizar la simulación
route("/simulation/:id", method = POST) do
    id = payload(:id)
    if !haskey(instances, id)
        return json(Dict("error" => "Simulation not found")), 404
    end

    robots = instances[id]
    boxes = paquetes[id]

    # Actualizar cada robot
    for robot in robots
        ModuloRobot.update(robot, boxes)
    end

    # Devolver estado actualizado
    json(Dict(
        "robots" => [ModuloRobot.to_dict(robot) for robot in robots],
        "packages" => [ModuloCaja.to_dict(box) for box in boxes]
    ))
end

# Ruta para limpiar la simulación
route("/simulation/:id", method = DELETE) do
    id = payload(:id)
    delete!(instances, id)
    delete!(paquetes, id)
    json(Dict("status" => "deleted"))
end

# Configurar CORS
Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

# Iniciar servidor
up(8000)
