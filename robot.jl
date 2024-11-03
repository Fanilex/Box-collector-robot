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

function crearRobot(dimBoard::Float64, zonaDescarga::Float64, vel::Float64, num_robot::Int, total_robots::Int, margin::Float64)
    # Generar posición inicial dentro del board y respetando el margen y no en la zona de descarga
    x_min = -dimBoard + margin
    x_max = dimBoard - margin
    y_min = -dimBoard + margin
    y_max = dimBoard - zonaDescarga - margin

    x = rand() * (x_max - x_min) + x_min
    y = rand() * (y_max - y_min) + y_min
    posicion = [x, y, 13.0]

    angulo = pi/2 + rand() * 0.2 - 0.1  # Inicializar cerca de pi/2 (90 grados) con pequeños desvíos
    estado_robot = "buscar"
    contador = 0
    puntoCarga = zeros(3)
    caja_recogida = nothing
    rotando = false
    angulo_objetivo = angulo
    velocidad_rotacion = pi / 4  # Velocidad de rotación (radians por frame)
    velocidad = 200  # Velocidad de movimiento

    # Asignar zona de descarga individual
    ancho_zona = (2 * dimBoard - 2 * margin) / total_robots
    x_min_descarga = -dimBoard + margin + (num_robot - 1) * ancho_zona
    x_max_descarga = x_min_descarga + ancho_zona - margin
    y_min_descarga = dimBoard - zonaDescarga - margin
    y_max_descarga = dimBoard - margin

    zona_descarga_robot = (x_min_descarga, x_max_descarga, y_min_descarga, y_max_descarga)

    # Inicializar posiciones de pilas
    posiciones_pilas = []
    num_pilas = 5  # Número máximo de pilas en la zona
    for i in 1:num_pilas
        x_pila = x_min_descarga + (i - 0.5) * (ancho_zona / num_pilas)
        y_pila = y_min_descarga + zonaDescarga / 2
        push!(posiciones_pilas, [x_pila, y_pila])
    end
    indice_pila_actual = 1
    altura_pila_actual = 0

    robot = Robot(dimBoard, zonaDescarga, posicion, estado_robot, contador, puntoCarga, caja_recogida,
                  angulo, rotando, angulo_objetivo, velocidad_rotacion, velocidad,
                  zona_descarga_robot, posiciones_pilas, indice_pila_actual, altura_pila_actual,
                  margin)
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
        altura = robot.altura_pila_actual * 6.0  # Incrementar la altura para apilar
        pos_caja = [pila_pos[1], pila_pos[2], 3.0 + altura]  # Ajustar altura
        # Establecer la posición y estado de la caja para indicar que ahora está en la zona de descarga
        Main.ModuloCaja.setPosYEstado!(robot.caja_recogida, pos_caja, 0.0, "soltada")
        # Actualizar la altura de la pila y preparar para la siguiente pila si es necesario
        robot.altura_pila_actual += 1
        if robot.altura_pila_actual >= 5  # Comenzar una nueva pila después de 5 cajas
            robot.altura_pila_actual = 0
            robot.indice_pila_actual += 1
            if robot.indice_pila_actual > length(robot.posiciones_pilas)
                robot.indice_pila_actual = 1
            end
        end
        # Reiniciar el estado del robot para buscar otra caja
        robot.caja_recogida = nothing
        robot.estado_robot = "buscar"  # Listo para buscar la próxima caja
        # Después de soltar, establece el ángulo objetivo hacia la dirección estándar (arriba)
        robot.angulo_objetivo = pi/2  # Dirección estándar hacia arriba
        robot.rotando = true
        println("Robot is now ready to search for the next box.")
    else
        println("Warning: Attempting to release a box, but no box is currently held by the robot.")
    end
end

# Función para envolver ángulos entre 0 y 2pi
function wrap(angle::Float64)
    return mod(angle, 2pi)
end

function eventHandler!(robot::Robot, paquetes)
    println("Current robot state: ", robot.estado_robot)  # Debug: Track state

    # Coordenadas de la zona de descarga
    dropoff_x = 0.0
    dropoff_y = robot.dimBoard - robot.zonaDescarga / 2

    try
        if robot.estado_robot == "buscar"
            # Encontrar la caja más cercana en la lista de paquetes
            closest_box = nothing
            min_distance = Inf
            for box in paquetes
                if Main.ModuloCaja.get_estado_caja(box) == "esperando"
                    box_pos = Main.ModuloCaja.get_posicion_caja(box)
                    # Buscar todas las cajas disponibles sin restricciones de carril
                    dist = norm([robot.posicion[1] - box_pos[1], robot.posicion[2] - box_pos[2]])

                    if dist < min_distance
                        min_distance = dist
                        closest_box = box
                    end
                end
            end

            # Si se encuentra una caja, establecerla como objetivo y preparar para rotar
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
            # Después de rotar, cambiar a mover hacia la caja
            if !robot.rotando
                robot.estado_robot = "moviendo_a_caja"
                println("Rotation complete. Moving towards the box.")  # Debug
            end

        elseif robot.estado_robot == "moviendo_a_caja"
            # Verificar la distancia a la caja objetivo y recogerla si está lo suficientemente cerca
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
            # Moverse hacia la zona de descarga
            robot.angulo_objetivo = atan(dropoff_y - robot.posicion[2], dropoff_x - robot.posicion[1])
            robot.rotando = true
            robot.estado_robot = "rotando_a_descarga"
            println("Heading to drop-off zone. Target angle: ", robot.angulo_objetivo)  # Debug

        elseif robot.estado_robot == "rotando_a_descarga"
            if !robot.rotando
                robot.estado_robot = "yendo_a_descarga"
            end

        elseif robot.estado_robot == "yendo_a_descarga"
            # Verificar la distancia a la zona de descarga
            dist_to_dropoff = norm([robot.posicion[1] - dropoff_x, robot.posicion[2] - dropoff_y])
            println("Distance to drop-off zone: ", dist_to_dropoff)  # Debug
            if dist_to_dropoff < 5.0
                robot.estado_robot = "soltando_caja"
            end

        elseif robot.estado_robot == "soltando_caja"
            println("Releasing box at drop-off zone...")  # Debug
            soltar(robot)
            robot.estado_robot = "buscar"
            # Después de soltar, establece el ángulo objetivo hacia la dirección estándar (arriba)
            robot.angulo_objetivo = pi/2  # Dirección estándar hacia arriba
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
            if abs(diferencia) > pi
                diferencia -= sign(diferencia) * 2pi
            end
            incremento = robot.velocidad_rotacion * sign(diferencia)
            if abs(diferencia) > abs(incremento)
                robot.angulo += incremento
            else
                robot.angulo = robot.angulo_objetivo
                robot.rotando = false
            end
            robot.angulo = wrap(robot.angulo)
        elseif robot.estado_robot in ["moviendo_a_caja", "yendo_a_descarga"]
            # Movimiento en la dirección del ángulo actual
            delta_x = robot.velocidad * cos(robot.angulo) * 0.1
            delta_y = robot.velocidad * sin(robot.angulo) * 0.1
            nueva_x = robot.posicion[1] + delta_x
            nueva_y = robot.posicion[2] + delta_y

            # Definir buffer para evitar que los robots se acerquen demasiado a los bordes
            buffer = 10.0  # Buffer en unidades

            # Verificar límites en X y ajustar si es necesario
            if nueva_x < -robot.dimBoard + robot.margin + buffer
                nueva_x = -robot.dimBoard + robot.margin + buffer
                # Ajustar angulo_objetivo para no apuntar hacia la pared
                robot.angulo_objetivo = pi/2  # Dirección estándar hacia arriba
                robot.rotando = true
                robot.estado_robot = "rotando_a_caja"
            elseif nueva_x > robot.dimBoard - robot.margin - buffer
                nueva_x = robot.dimBoard - robot.margin - buffer
                # Ajustar angulo_objetivo para no apuntar hacia la pared
                robot.angulo_objetivo = pi/2  # Dirección estándar hacia arriba
                robot.rotando = true
                robot.estado_robot = "rotando_a_caja"
            end

            # Verificar límites en Y y ajustar si es necesario
            if nueva_y < -robot.dimBoard + robot.margin + buffer
                nueva_y = -robot.dimBoard + robot.margin + buffer
                # Ajustar angulo_objetivo para no apuntar hacia la pared
                robot.angulo_objetivo = pi/2  # Dirección estándar hacia arriba
                robot.rotando = true
                robot.estado_robot = "rotando_a_caja"
            elseif nueva_y > robot.dimBoard -  robot.margin 
                nueva_y = robot.dimBoard -  robot.margin 
                # Ajustar angulo_objetivo para no apuntar hacia la pared
                robot.angulo_objetivo = pi/2  # Dirección estándar hacia arriba
                robot.rotando = true
                robot.estado_robot = "rotando_a_caja"
            end 

            robot.posicion[1] = nueva_x
            robot.posicion[2] = nueva_y
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
