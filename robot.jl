# robot.jl

include("caja.jl")
using .ModuloCaja

module ModuloRobot
export update
export Robot, crearRobot, update, transportar, soltar
export get_estado_robot, get_posicion, get_angulo, asignar_zona_descarga
using Random
using LinearAlgebra

mutable struct Robot
    dimBoard::Float64
    zonaDescarga::Float64
    posicion::Vector{Float64}
    estado_robot::String
    contador::Int
    puntoCarga::Vector{Float64}
    caja_recogida::Union{Nothing, Main.ModuloCaja.Caja}
    angulo::Float64
    rotando::Bool
    angulo_objetivo::Float64
    velocidad_rotacion::Float64
    velocidad::Float64
    # Campos para manejo de apilamiento
    zona_descarga_robot::Tuple{Float64, Float64, Float64, Float64}  # (x_min, x_max, y_min, y_max)
    posiciones_pilas::Vector{Vector{Float64}}  # Lista de posiciones de pilas
    indice_pila_actual::Int
    altura_pila_actual::Int
    # Campos para límites de carril
    lane_x_min::Float64
    lane_x_max::Float64
    # Campo para margen
    margin::Float64
end

function to_dict(robot::Robot)
    return Dict(
        "position" => robot.posicion,
        "angle" => robot.angulo,
        "state" => robot.estado_robot
    )
end

function crearRobot(dimBoard::Float64, zonaDescarga::Float64, vel::Float64, num_robot::Int, total_robots::Int, total_lanes::Int, margin::Float64)
    # Calcular el ancho de cada carril
    lane_width = (2 * dimBoard - 2 * margin) / total_lanes  # Ajuste para márgenes
    # Asignar carril basado en el número del robot
    lane_index = (num_robot - 1) % total_lanes  # Para asegurar que si hay más robots que carriles, se repitan
    lane_x_min = -dimBoard + margin + lane_index * lane_width
    lane_x_max = lane_x_min + lane_width - margin

    # Generar posición inicial dentro del carril y respetando el margen en Y
    min_coord_y = -dimBoard + margin
    max_coord_y = dimBoard - zonaDescarga - margin
    x = rand() * (lane_x_max - lane_x_min) + lane_x_min
    y = rand() * (max_coord_y - min_coord_y) + min_coord_y
    posicion = [x, y, 13.0]
    angulo = rand() * 2π  # Ángulo inicial aleatorio
    estado_robot = "buscar"
    contador = 0
    puntoCarga = zeros(3)
    caja_recogida = nothing
    rotando = false
    angulo_objetivo = angulo
    velocidad_rotacion = π / 2  # Velocidad de rotación (radianes por frame)
    velocidad = 200  # Velocidad de movimiento

    # Asignar zona de descarga individual
    ancho_zona = (2 * dimBoard - 2 * margin) / total_robots
    x_min_descarga = -dimBoard + margin + (num_robot - 1) * ancho_zona
    x_max_descarga = x_min_descarga + ancho_zona - margin
    y_min = dimBoard - zonaDescarga - margin
    y_max = dimBoard - margin

    zona_descarga_robot = (x_min_descarga, x_max_descarga, y_min, y_max)

    # Inicializar posiciones de pilas
    posiciones_pilas = []
    num_pilas = 5  # Número máximo de pilas en la zona
    for i in 1:num_pilas
        x_pila = x_min_descarga + (i - 0.5) * (ancho_zona / num_pilas)
        y_pila = y_min + zonaDescarga / 2
        push!(posiciones_pilas, [x_pila, y_pila])
    end
    indice_pila_actual = 1
    altura_pila_actual = 0

    robot = Robot(dimBoard, zonaDescarga, posicion, estado_robot, contador, puntoCarga, caja_recogida,
                  angulo, rotando, angulo_objetivo, velocidad_rotacion, velocidad,
                  zona_descarga_robot, posiciones_pilas, indice_pila_actual, altura_pila_actual,
                  lane_x_min, lane_x_max, margin)
    updatePuntoCarga!(robot)
    return robot
end

function updatePuntoCarga!(robot::Robot)
    offset = [22.0, 0.0, 0.0]
    rotation_matrix = [
        cos(robot.angulo) -sin(robot.angulo) 0.0;
        sin(robot.angulo) cos(robot.angulo)  0.0;
        0.0             0.0              1.0
    ]
    rotated_offset = rotation_matrix * offset
    robot.puntoCarga = robot.posicion .+ rotated_offset
    robot.puntoCarga[3] = robot.posicion[3]
end

function transportar(robot::Robot, caja)
    println("Attempting to transport box...")  # Debug: Entry into function
    Main.ModuloCaja.setPos(caja, robot.puntoCarga, robot.angulo)
    Main.ModuloCaja.set_estado_caja(caja, "recogida")
    robot.caja_recogida = caja
    robot.estado_robot = "caja_recogida"
    println("Box is now being transported. Robot state: ", robot.estado_robot)  # Debug: Confirm transport
end

function soltar(robot::Robot)
    if robot.caja_recogida != nothing
        # Drop box at the current stack position in the discharge zone
        pila_pos = robot.posiciones_pilas[robot.indice_pila_actual]
        altura = robot.altura_pila_actual * 6.0  # Increase height for stacking
        pos_caja = [pila_pos[1], pila_pos[2], 3.0 + altura]  # Adjust height
        # Set the position and state of the box to indicate it is now in the discharge zone
        Main.ModuloCaja.setPosYEstado!(robot.caja_recogida, pos_caja, 0.0, "soltada")
        # Update the stack height and prepare for the next stack if needed
        robot.altura_pila_actual += 1
        if robot.altura_pila_actual >= 5  # Start a new stack after 5 boxes
            robot.altura_pila_actual = 0
            robot.indice_pila_actual += 1
            if robot.indice_pila_actual > length(robot.posiciones_pilas)
                robot.indice_pila_actual = 1
            end
        end
        # Reset the robot state for searching another box
        robot.caja_recogida = nothing
        robot.estado_robot = "buscar"  # Ready to look for the next box
        println("Robot is now ready to search for the next box.")
    else
        println("Warning: Attempting to release a box, but no box is currently held by the robot.")
    end
end

function eventHandler!(robot::Robot, paquetes)
    println("Current robot state: ", robot.estado_robot)  # Debug: Track state

    # Define drop-off zone coordinates globally for all states that need them
    dropoff_x = 0.0
    dropoff_y = robot.dimBoard - robot.zonaDescarga / 2

    try
        if robot.estado_robot == "buscar"
            # Find the closest box in the paquetes list
            closest_box = nothing
            min_distance = Inf
            for box in paquetes
                if Main.ModuloCaja.get_estado_caja(box) == "esperando"
                    box_pos = Main.ModuloCaja.get_posicion_caja(box)
                    dist = norm([robot.posicion[1] - box_pos[1], robot.posicion[2] - box_pos[2]])

                    if dist < min_distance
                        min_distance = dist
                        closest_box = box
                    end
                end
            end

            # If a box is found, set it as the target and prepare to rotate
            if closest_box != nothing
                box_pos = Main.ModuloCaja.get_posicion_caja(closest_box)
                robot.angulo_objetivo = atan(box_pos[2] - robot.posicion[2], box_pos[1] - robot.posicion[1])
                robot.rotando = true
                robot.estado_robot = "rotando_a_caja"
                println("Targeting box at position: ", box_pos)  # Debug: Target position
            else
                println("No available boxes found.")
            end

        elseif robot.estado_robot == "rotando_a_caja"
            # After rotation, switch to moving toward the box
            if !robot.rotando
                robot.estado_robot = "moviendo_a_caja"
                println("Rotation complete. Moving towards the box.")  # Debug
            end

        elseif robot.estado_robot == "moviendo_a_caja"
            # Check distance to the target box, then pick it up if close enough
            closest_box = nothing
            min_distance = Inf
            for box in paquetes
                if Main.ModuloCaja.get_estado_caja(box) == "esperando"
                    box_pos = Main.ModuloCaja.get_posicion_caja(box)
                    dist = norm([robot.posicion[1] - box_pos[1], robot.posicion[2] - box_pos[2]])

                    if dist < min_distance
                        min_distance = dist
                        closest_box = box
                    end
                end
            end

            if closest_box != nothing && min_distance < 10.0
                println("Arrived at box. Picking up box.")  # Debug
                transportar(robot, closest_box)
                robot.estado_robot = "caja_recogida"
            end

        elseif robot.estado_robot == "caja_recogida"
            # Move towards the drop-off zone
            robot.angulo_objetivo = atan(dropoff_y - robot.posicion[2], dropoff_x - robot.posicion[1])
            robot.rotando = true
            robot.estado_robot = "rotando_a_descarga"
            println("Heading to drop-off zone. Target angle: ", robot.angulo_objetivo)  # Debug

        elseif robot.estado_robot == "rotando_a_descarga"
            if !robot.rotando
                robot.estado_robot = "yendo_a_descarga"
            end

        elseif robot.estado_robot == "yendo_a_descarga"
            # Check distance to drop-off zone
            dist_to_dropoff = norm([robot.posicion[1] - dropoff_x, robot.posicion[2] - dropoff_y])
            println("Distance to drop-off zone: ", dist_to_dropoff)  # Debug
            if dist_to_dropoff < 5.0
                robot.estado_robot = "soltando_caja"
            end

        elseif robot.estado_robot == "soltando_caja"
            println("Releasing box at drop-off zone...")  # Debug
            soltar(robot)
            robot.estado_robot = "buscar"
            robot.angulo_objetivo = rand() * 2π
            robot.rotando = true
        end

    catch e
        println("Error in eventHandler!: ", e)
        println("Stacktrace: ", stacktrace(e))
    end
end

function update(robot::Robot, paquetes)
    try
        eventHandler!(robot, paquetes)

        if robot.rotando
            diferencia = robot.angulo_objetivo - robot.angulo
            if abs(diferencia) > π
                diferencia -= sign(diferencia) * 2π
            end
            incremento = robot.velocidad_rotacion * sign(diferencia)
            if abs(diferencia) > abs(incremento)
                robot.angulo += incremento
            else
                robot.angulo = robot.angulo_objetivo
                robot.rotando = false
            end
        elseif robot.estado_robot == "moviendo_a_caja" || robot.estado_robot == "yendo_a_descarga"
            # Move forward in the direction of the current angle
            delta_x = robot.velocidad * cos(robot.angulo) * 0.1
            delta_y = robot.velocidad * sin(robot.angulo) * 0.1
            robot.posicion[1] += delta_x
            robot.posicion[2] += delta_y
            println("Moving towards target. Current position: ", robot.posicion)  # Debug
        end

        updatePuntoCarga!(robot)

        if robot.caja_recogida != nothing
            Main.ModuloCaja.setPos(robot.caja_recogida, robot.puntoCarga, robot.angulo)
        end

    catch e
        println("Error in update: ", e)
        println("Stacktrace: ", Base.stacktrace())
    end
end

# Funciones de acceso (getters)
function get_estado_robot(robot::Robot)
    return robot.estado_robot
end

function get_posicion(robot::Robot)
    return robot.posicion
end

function get_angulo(robot::Robot)
    return robot.angulo
end

function asignar_zona_descarga(robot::Robot, x_min::Float64, x_max::Float64, y_min::Float64, y_max::Float64)
    robot.zona_descarga_robot = (x_min, x_max, y_min, y_max)
end

end  # Fin del módulo ModuloRobot
