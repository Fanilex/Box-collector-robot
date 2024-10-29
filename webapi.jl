using Genie, Genie.Renderer.Json, Agents, Random, UUIDs

# Estructura de agentes
mutable struct Caja <: AbstractAgent
    id::Int
    pos::Tuple{Int, Int}
end

mutable struct Robot <: AbstractAgent
    id::Int
    pos::Tuple{Int, Int}
    target_pos::Tuple{Int, Int}
end


# Función para mover el robot hacia la caja
function move_robot!(robot::Robot, model)
    dx = sign(robot.target_pos[1] - robot.pos[1])
    dy = sign(robot.target_pos[2] - robot.pos[2])
    robot.pos = (robot.pos[1] + dx, robot.pos[2] + dy)
end

# Inicializar modelo de la simulación
function initialize_model()
    space = GridSpace((20, 20), periodic = false)
    model = ABM(Any, space)

    # Crear un robot y una caja en posiciones aleatorias
    robot = Robot(1, (1, 1), (rand(1:20), rand(1:20)))
    caja = Caja(1, (rand(1:20), rand(1:20)))
    robot.target_pos = caja.pos

    # Agregar agentes al modelo
    add_agent!(robot, model)
    add_agent!(caja, model)

    return model
end

# Diccionario para almacenar instancias de simulaciones
instances = Dict{String, ABM}()

# Ruta para iniciar una nueva simulación
route("/simulations", method = POST) do
    id = string(uuid1())
    model = initialize_model()
    instances[id] = model

    agents = []
    for agent in allagents(model)
        push!(agents, Dict("id" => agent.id, "type" => typeof(agent), "position" => agent.pos))
    end

    json(Dict("id" => id, "agents" => agents))
end

# Ruta para actualizar la simulación y obtener el estado actual de los agentes
route("/simulations/:id") do
    id = params(:id)
    model = instances[id]

    # Ejecutar un paso de la simulación
    for agent in allagents(model)
        if agent isa Robot
            move_robot!(agent, model)
        end
    end

    # Obtener estado de los agentes después de la actualización
    agents = []
    for agent in allagents(model)
        push!(agents, Dict("id" => agent.id, "type" => typeof(agent), "position" => agent.pos))
    end

    json(Dict("agents" => agents))
end

# Configuración del servidor y CORS
Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

# Iniciar el servidor
up()
