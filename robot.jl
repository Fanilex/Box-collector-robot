module ModuloRobot
export Robot, crearRobot, update, transportar, soltar
export get_estado_robot, get_posicion, get_angulo
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
end

function crearRobot(dimBoard::Float64, zonaDescarga::Float64, vel::Float64)
    min_coord = -dimBoard
    max_coord = dimBoard
    posicion = [rand() * (max_coord - min_coord) + min_coord,
                rand() * (max_coord - min_coord) + min_coord,
                13.0]
    estado_robot = "buscar"
    contador = 0
    puntoCarga = zeros(3)
    caja_recogida = nothing
    angulo = rand() * 2π  # Ángulo inicial aleatorio
    rotando = false
    angulo_objetivo = angulo
    velocidad_rotacion = π / 30  # Velocidad de rotación (radianes por frame)
    velocidad = vel  # Velocidad de movimiento
    robot = Robot(dimBoard, zonaDescarga, posicion, estado_robot, contador, puntoCarga, caja_recogida,
                  angulo, rotando, angulo_objetivo, velocidad_rotacion, velocidad)
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
        Main.ModuloCaja.setPos(robot.caja_recogida, [robot.puntoCarga[1], robot.puntoCarga[2], 3.0], robot.angulo)
        Main.ModuloCaja.set_estado_caja(robot.caja_recogida, "soltada")
        robot.caja_recogida = nothing
    else
        println("Advertencia: Intentando soltar una caja cuando robot.caja_recogida es nothing")
    end
end

function eventHandler!(robot::Robot)
    if robot.estado_robot == "buscar"
        # El robot sigue avanzando en línea recta hasta encontrar una caja (manejado desde Python)
    elseif robot.estado_robot == "caja_recogida"
        # Dirección hacia la zona de descarga
        target_x = -robot.dimBoard + robot.zonaDescarga
        target_y = -robot.dimBoard + robot.zonaDescarga
        newDir = [target_x - robot.posicion[1], target_y - robot.posicion[2]]
        robot.angulo_objetivo = atan(newDir[2], newDir[1])
        robot.rotando = true
        robot.estado_robot = "rotando_a_descarga"
    elseif robot.estado_robot == "rotando_a_descarga"
        if !robot.rotando
            robot.estado_robot = "yendo_a_descarga"
        end
    elseif robot.estado_robot == "yendo_a_descarga"
        dist = norm([robot.posicion[1] - (-robot.dimBoard + robot.zonaDescarga),
                     robot.posicion[2] - (-robot.dimBoard + robot.zonaDescarga)])
        if dist < 10
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
        # Movimiento normal
        delta_x = robot.velocidad * cos(robot.angulo)
        delta_y = robot.velocidad * sin(robot.angulo)
        robot.posicion[1] += delta_x
        robot.posicion[2] += delta_y

        # Verificar límites y ajustar ángulo si es necesario
        if robot.posicion[1] < -robot.dimBoard || robot.posicion[1] > robot.dimBoard
            robot.posicion[1] = clamp(robot.posicion[1], -robot.dimBoard, robot.dimBoard)
            robot.angulo = π - robot.angulo
        end
        if robot.posicion[2] < -robot.dimBoard || robot.posicion[2] > robot.dimBoard
            robot.posicion[2] = clamp(robot.posicion[2], -robot.dimBoard, robot.dimBoard)
            robot.angulo = -robot.angulo
        end
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

end  # Fin del módulo ModuloRobot
