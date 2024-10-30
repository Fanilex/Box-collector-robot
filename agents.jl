# Archivo: backend.jl

using Sockets
using JSON
using Random

# Parámetros del entorno
num_robots = 5
num_cajas_por_carril = 20
num_carriles = num_robots
ancho_carril = 10  # Ancho de cada carril
altura_grilla = 100  # Altura de la grilla

# Zona de entrega (parte superior de la pantalla)
zona_entrega_y = altura_grilla - 1

# Estructuras de datos
mutable struct Robot
    id::Int
    posicion::Tuple{Int, Int}
    cargando::Bool
    destino::Tuple{Int, Int}
    path::Array{Tuple{Int, Int}}
end

mutable struct Caja
    id::Int
    posicion::Tuple{Int, Int}
    recogida::Bool
end

# Inicializar robots y cajas
robots = Robot[]
cajas = Caja[]

for i in 1:num_robots
    # Posición inicial de los robots (parte inferior de su carril)
    x_pos = (i - 1) * ancho_carril + ancho_carril ÷ 2
    robot_pos = (x_pos, 0)
    push!(robots, Robot(i, robot_pos, false, robot_pos, []))
    
    # Generar cajas en posiciones aleatorias dentro del carril
    for j in 1:num_cajas_por_carril
        x = x_pos  # Mantenerse en el centro del carril
        y = rand(1:zona_entrega_y - 1)
        push!(cajas, Caja((i - 1) * num_cajas_por_carril + j, (x, y), false))
    end
end

# Función para encontrar la caja más cercana en el carril del robot
function encontrar_caja(robot::Robot)
    for caja in cajas
        if !caja.recogida && caja.posicion[1] == robot.posicion[1]
            return caja
        end
    end
    return nothing
end

# Función para calcular el camino directo hacia el destino
function calcular_camino(origen::Tuple{Int, Int}, destino::Tuple{Int, Int})
    path = []
    x, y = origen
    while y != destino[2]
        y += y < destino[2] ? 1 : -1
        push!(path, (x, y))
    end
    return path
end

# Función principal de simulación
function simular()
    # Establecer conexión con Python
    server = connect(5555)
    println("Conectado al frontend en Python")
    
    # Ciclo de simulación
    while true
        # Actualizar robots
        for robot in robots
            if isempty(robot.path)
                if robot.cargando
                    # Llevar caja a la zona de entrega
                    destino = (robot.posicion[1], zona_entrega_y)
                    robot.path = calcular_camino(robot.posicion, destino)
                else
                    # Buscar siguiente caja
                    caja = encontrar_caja(robot)
                    if caja !== nothing
                        robot.destino = caja.posicion
                        robot.path = calcular_camino(robot.posicion, caja.posicion)
                        caja.recogida = true  # Marcar caja como recogida
                    end
                end
            else
                # Mover robot un paso
                robot.posicion = popfirst!(robot.path)
                
                # Verificar si llegó al destino
                if isempty(robot.path)
                    if robot.cargando
                        robot.cargando = false  # Dejar caja
                    else
                        robot.cargando = true  # Recoger caja
                    end
                end
            end
        end
        
        # Preparar estado para enviar
        estado = Dict(
            "robots" => [Dict("id" => robot.id, "posicion" => robot.posicion, "cargando" => robot.cargando) for robot in robots],
            "cajas" => [Dict("id" => caja.id, "posicion" => caja.posicion, "recogida" => caja.recogida) for caja in cajas]
        )
        mensaje = JSON.json(estado) * "\n"
        write(server, mensaje)
        
        sleep(0.1)  # Controlar velocidad de la simulación
    end
end

# Ejecutar simulación
simular()
