module ModuloRobot
export Robot, crearRobot, update, transportar, soltar
using Random
using LinearAlgebra

# Variable global para indicar si algún robot está rotando
const robot_rotando = Ref(false)

mutable struct Robot
    dimBoard::Float64
    zonaDescarga::Float64
    posicion::Vector{Float64}
    estado_robot::String
    contador::Int
    puntoCarga::Vector{Float64}
    caja_recogida::Union{Nothing, Main.ModuloCaja.Caja}
    direccion::Vector{Float64}
    angulo::Float64
    # Nuevos campos para manejar la rotación
    rotando::Bool
    angulo_objetivo::Float64
    velocidad_rotacion::Float64
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
    dir_vector = [rand() * 2 - 1, rand() * 2 - 1, 0.0]
    direccion = (dir_vector / norm(dir_vector)) * vel
    angulo = atan(direccion[2], direccion[1])
    rotando = false
    angulo_objetivo = angulo
    velocidad_rotacion = π / 60  # Velocidad de rotación (radianes por frame)
    robot = Robot(dimBoard, zonaDescarga, posicion, estado_robot, contador, puntoCarga, caja_recogida, direccion, angulo, rotando, angulo_objetivo, velocidad_rotacion)
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
    caja.estado_caja = "recogida"
    robot.caja_recogida = caja
    robot.estado_robot = "caja_recogida"
end

function soltar(robot::Robot)
    if robot.caja_recogida != nothing
        Main.ModuloCaja.setPos(robot.caja_recogida, [robot.puntoCarga[1], robot.puntoCarga[2], 3.0], robot.angulo)
        robot.caja_recogida.estado_caja = "soltada"
        robot.caja_recogida = nothing
        robot.estado_robot = "buscar"
    else
        # Manejar el caso en que no hay caja asignada
        println("Advertencia: Intentando soltar una caja cuando robot.caja_recogida es nothing")
    end
end

function eventHandler!(robot::Robot)
    if robot.estado_robot == "caja_recogida"
        # Dirección hacia la zona de descarga
        target_x = -robot.dimBoard + robot.zonaDescarga
        target_y = -robot.dimBoard + robot.zonaDescarga
        newDir = [target_x - robot.posicion[1], target_y - robot.posicion[2], 0.0]
        fctr = norm(newDir)
        newDir = newDir / fctr
        robot.direccion = newDir * norm(robot.direccion)
        robot.estado_robot = "iniciar_rotacion"
        robot.angulo_objetivo = atan(robot.direccion[2], robot.direccion[1])
        robot.rotando = true
        robot.contador = 0
        robot_rotando[] = true  # Indicar que un robot está rotando
    elseif robot.estado_robot == "iniciar_rotacion"
        # Espera a que termine la rotación
        if !robot.rotando
            robot.estado_robot = "en_camino"
        end
    elseif robot.estado_robot == "en_camino"
        # Verificar si el robot está dentro de la zona de descarga
        if robot.posicion[1] >= -robot.dimBoard && robot.posicion[1] <= (-robot.dimBoard + 2 * robot.zonaDescarga) &&
           robot.posicion[2] >= -robot.dimBoard && robot.posicion[2] <= (-robot.dimBoard + 2 * robot.zonaDescarga)
            robot.direccion .= 0.0  # Detener el robot
            robot.estado_robot = "se_detiene"
            robot.contador = 0
        end
    elseif robot.estado_robot == "se_detiene"
        if robot.caja_recogida != nothing
            soltar(robot)
        else
            println("Advertencia: Robot en estado 'se_detiene' pero no tiene una caja asignada")
        end
        # Asignar nueva dirección aleatoria
        dir_vector = [rand() * 2 - 1, rand() * 2 - 1, 0.0]
        robot.direccion = dir_vector / norm(dir_vector)
        robot.estado_robot = "iniciar_rotacion"
        robot.angulo_objetivo = atan(robot.direccion[2], robot.direccion[1])
        robot.rotando = true
        robot_rotando[] = true  # Indicar que un robot está rotando
        robot.contador = 0
    elseif robot.estado_robot == "buscar"
        if rand() > 0.7 && robot.contador > 100
            dir_vector = [rand() * 2 - 1, rand() * 2 - 1, 0.0]
            robot.direccion = dir_vector / norm(dir_vector)
            robot.estado_robot = "iniciar_rotacion"
            robot.angulo_objetivo = atan(robot.direccion[2], robot.direccion[1])
            robot.rotando = true
            robot_rotando[] = true  # Indicar que un robot está rotando
            robot.contador = 0
        end
    end
    robot.contador += 1
end

function update(robot::Robot)
    # Sincronización: Si otro robot está rotando, no hacer nada
    if robot_rotando[] && !robot.rotando
        # Robot en espera
        return
    end

    eventHandler!(robot)

    if robot.rotando
        # Ajustar el ángulo gradualmente
        diferencia = robot.angulo_objetivo - robot.angulo
        if abs(diferencia) > robot.velocidad_rotacion
            incremento = robot.velocidad_rotacion * sign(diferencia)
            robot.angulo += incremento
        else
            robot.angulo = robot.angulo_objetivo
            robot.rotando = false
            robot_rotando[] = false  # Indicar que ya no hay robots rotando
        end
        # Actualizar dirección en base al nuevo ángulo
        robot.direccion = [cos(robot.angulo), sin(robot.angulo), 0.0] * norm(robot.direccion)
    else
        # Movimiento normal
        new_x = robot.posicion[1] + robot.direccion[1]
        new_y = robot.posicion[2] + robot.direccion[2]

        if -robot.dimBoard <= new_x <= robot.dimBoard
            robot.posicion[1] = new_x
        else
            robot.direccion[1] *= -1
        end
        if -robot.dimBoard <= new_y <= robot.dimBoard
            robot.posicion[2] = new_y
        else
            robot.direccion[2] *= -1
        end
    end

    updatePuntoCarga!(robot)

    if robot.caja_recogida != nothing && (robot.estado_robot == "caja_recogida" || robot.estado_robot == "en_camino" || robot.rotando)
        Main.ModuloCaja.setPos(robot.caja_recogida, robot.puntoCarga, robot.angulo)
    end
end

end  # Fin del módulo ModuloRobot
