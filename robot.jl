# robot.jl
module ModuloRobot
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

function crearRobot(dimBoard::Float64, zonaDescarga::Float64, vel::Float64, num_robot::Int, total_robots::Int, total_lanes::Int, margin::Float64)
    # Calcular el ancho de cada carril
    lane_width = (2 * dimBoard) / total_lanes
    # Asignar carril basado en el número del robot
    lane_index = (num_robot - 1) % total_lanes  # Para asegurar que si hay más robots que carriles, se repitan
    lane_x_min = -dimBoard + lane_index * lane_width + margin
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
    velocidad_rotacion = π / 30  # Velocidad de rotación (radianes por frame)
    velocidad = vel  # Velocidad de movimiento

    # Asignar zona de descarga individual
    ancho_zona = (2 * dimBoard) / total_robots
    x_min_descarga = -dimBoard + (num_robot - 1) * ancho_zona + margin
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
    Main.ModuloCaja.setPos(caja, robot.puntoCarga, robot.angulo)
    Main.ModuloCaja.set_estado_caja(caja, "recogida")
    robot.caja_recogida = caja
    robot.estado_robot = "caja_recogida"
end

function soltar(robot::Robot)
    if robot.caja_recogida != nothing
        # Obtener posición de la pila actual
        pila_pos = robot.posiciones_pilas[robot.indice_pila_actual]
        altura = robot.altura_pila_actual * 6.0  # Altura de cada caja (ajustar según sea necesario)
        pos_caja = [pila_pos[1], pila_pos[2], 3.0 + altura]
        Main.ModuloCaja.setPos(robot.caja_recogida, pos_caja, 0.0)
        Main.ModuloCaja.set_estado_caja(robot.caja_recogida, "soltada")

        # Actualizar altura de la pila
        robot.altura_pila_actual += 1
        if robot.altura_pila_actual >= 5  # Si alcanza 5 cajas, pasar a la siguiente pila
            robot.altura_pila_actual = 0
            robot.indice_pila_actual += 1
            if robot.indice_pila_actual > length(robot.posiciones_pilas)
                robot.indice_pila_actual = 1  # Reiniciar si todas las pilas están llenas
            end
        end

        robot.caja_recogida = nothing
    else
        println("Advertencia: Intentando soltar una caja cuando robot.caja_recogida es nothing")
    end
end

function eventHandler!(robot::Robot)
    if robot.estado_robot == "buscar"
        # El robot sigue avanzando en línea recta hasta encontrar una caja
    elseif robot.estado_robot == "caja_recogida"
        # Dirección hacia la pila actual en su zona de descarga
        pila_pos = robot.posiciones_pilas[robot.indice_pila_actual]
        newDir = [pila_pos[1] - robot.posicion[1], pila_pos[2] - robot.posicion[2]]
        robot.angulo_objetivo = atan(newDir[2], newDir[1])
        robot.rotando = true
        robot.estado_robot = "rotando_a_descarga"
    elseif robot.estado_robot == "rotando_a_descarga"
        if !robot.rotando
            robot.estado_robot = "yendo_a_descarga"
        end
    elseif robot.estado_robot == "yendo_a_descarga"
        pila_pos = robot.posiciones_pilas[robot.indice_pila_actual]
        dist = norm([robot.posicion[1] - pila_pos[1], robot.posicion[2] - pila_pos[2]])
        if dist < 5.0
            robot.estado_robot = "soltando_caja"
        end
    elseif robot.estado_robot == "soltando_caja"
        soltar(robot)
        robot.estado_robot = "buscar"
        robot.angulo_objetivo = rand() * 2π  # Nueva dirección aleatoria
        robot.rotando = true
    end
end

function update(robot::Robot)
    eventHandler!(robot)

    if robot.rotando
        diferencia = robot.angulo_objetivo - robot.angulo
        if abs(diferencia) > robot.velocidad_rotacion
            incremento = robot.velocidad_rotacion * sign(diferencia)
            robot.angulo += incremento
        else
            robot.angulo = robot.angulo_objetivo
            robot.rotando = false
        end
    else
        # Movimiento hacia adelante
        delta_x = robot.velocidad * cos(robot.angulo)
        delta_y = robot.velocidad * sin(robot.angulo)
        nueva_x = robot.posicion[1] + delta_x
        nueva_y = robot.posicion[2] + delta_y

        # Verificar límites del carril y ajustar posición y ángulo si es necesario
        if nueva_x < robot.lane_x_min
            nueva_x = robot.lane_x_min
            robot.angulo = π - robot.angulo
        elseif nueva_x > robot.lane_x_max
            nueva_x = robot.lane_x_max
            robot.angulo = π - robot.angulo
        end

        # Verificar límites en Y y ajustar ángulo si es necesario
        if nueva_y < -robot.dimBoard + robot.margin
            nueva_y = -robot.dimBoard + robot.margin
            robot.angulo = -robot.angulo
        elseif nueva_y > robot.dimBoard - robot.zonaDescarga - robot.margin
            nueva_y = robot.dimBoard - robot.zonaDescarga - robot.margin
            robot.angulo = -robot.angulo
        end

        robot.posicion[1] = nueva_x
        robot.posicion[2] = nueva_y
    end

    updatePuntoCarga!(robot)

    if robot.caja_recogida != nothing
        Main.ModuloCaja.setPos(robot.caja_recogida, robot.puntoCarga, robot.angulo)
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
