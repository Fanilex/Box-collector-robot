
module ModuloRobot

export Robot, crearRobot, update, transportar, soltar

using Random
using LinearAlgebra

mutable struct Robot
    dimBoard::Float64
    zonaDescarga::Float64
    posicion::Vector{Float64}
    actividad::String
    count::Int
    maxPalletHeight::Float64
    minPalletHeight::Float64
    palletHeight::Float64
    palletState::String
    forkCenter::Vector{Float64}
    transportando::Any
    Direction::Vector{Float64}
    angulo::Float64
    seccionAlmacen::Int  # New field for storage section
end

function crearRobot(dimBoard::Float64, zonaDescarga::Float64, vel::Float64, seccionAlmacen::Int)
    posicion = [rand(-dimBoard:dimBoard), rand(-dimBoard:dimBoard), 13.0]
    actividad = "buscar"
    count = 0
    maxPalletHeight = 50.0
    minPalletHeight = -40.0
    palletHeight = minPalletHeight
    palletState = "DOWN"
    forkCenter = zeros(3)
    transportando = nothing
    dir_vector = [rand(-1.0:0.1:1.0), rand(-1.0:0.1:1.0), 0.0]
    Direction = (dir_vector / norm(dir_vector)) * vel
    angulo = atan(Direction[2], Direction[1])
    robot = Robot(dimBoard, zonaDescarga, posicion, actividad, count, maxPalletHeight, minPalletHeight,
                  palletHeight, palletState, forkCenter, transportando, Direction, angulo, seccionAlmacen)
    updateForkCenter!(robot)
    return robot
end

function updateForkCenter!(robot::Robot)
    offset = [22.0, 0.0, 0.0]
    rotation_matrix = [
        cos(robot.angulo) -sin(robot.angulo) 0.0;
        sin(robot.angulo) cos(robot.angulo)  0.0;
        0.0             0.0              1.0
    ]
    rotated_offset = rotation_matrix * offset
    robot.forkCenter = robot.posicion .+ rotated_offset
    robot.forkCenter[3] = robot.posicion[3] + robot.palletHeight * 0.2
end

function transportar(robot::Robot, caja)
    Main.ModuloCaja.setPos(caja, robot.forkCenter, robot.angulo)
    caja.estado = "PICKED_UP"
    robot.transportando = caja
    robot.palletState = "GOING_UP"
    robot.actividad = "DROPPING_OFF"
end

function soltar(robot::Robot)
    Main.ModuloCaja.setPos(robot.transportando, [robot.forkCenter[1], robot.forkCenter[2], 3.0], robot.angulo)
    robot.transportando.estado = "DROPPED_OFF"
    robot.transportando = nothing
    robot.actividad = "buscar"
end

function eventHandler!(robot::Robot)
    # Define the x-axis range for each robot's assigned section
    zona_ancho = robot.dimBoard * 2
    recuadro_ancho = zona_ancho / 5
    target_x = -robot.dimBoard + (robot.seccionAlmacen - 1) * recuadro_ancho

    if robot.actividad == "DROPPING_OFF"
        target_y = robot.dimBoard - robot.zonaDescarga
        newDir = [target_x - robot.posicion[1], target_y - robot.posicion[2], 0.0]
        fctr = norm(newDir)
        newDir = newDir / fctr
        robot.Direction = newDir * norm(robot.Direction)
        robot.actividad = "EN_ROUTE"
        robot.count = 0
    elseif robot.actividad == "EN_ROUTE"
        if robot.posicion[1] >= target_x && robot.posicion[1] <= (target_x + recuadro_ancho) &&
           robot.posicion[2] >= (robot.dimBoard - 2 * robot.zonaDescarga) && robot.posicion[2] <= robot.dimBoard
            robot.Direction *= 0.01
            robot.palletState = "GOING_DOWN"
            robot.actividad = "STOPPED"
            robot.count = 0
        end
    elseif robot.actividad == "STOPPED"
        if robot.palletState == "DOWN"
            soltar(robot)
            robot.Direction /= 0.01
            robot.count = 0
        end
    elseif robot.actividad == "buscar"
        if rand(0:100) > 70 && robot.count > robot.dimBoard * 2
            dir_vector = [rand(-1.0:0.1:1.0), rand(-1.0:0.1:1.0), 0.0]
            robot.Direction = dir_vector / norm(dir_vector)
            robot.count = 0
        end
    end
    robot.count += 1
end

function updatePallet!(robot::Robot)
    if robot.palletState == "GOING_UP"
        if robot.maxPalletHeight <= robot.palletHeight
            robot.palletState = "UP"
        else
            robot.palletHeight += 1
        end
    elseif robot.palletState == "GOING_DOWN"
        if robot.minPalletHeight >= robot.palletHeight
            robot.palletState = "DOWN"
        else
            robot.palletHeight -= 1
        end
    end
end

function update(robot::Robot)
    eventHandler!(robot)

    new_x = robot.posicion[1] + robot.Direction[1]
    new_y = robot.posicion[2] + robot.Direction[2]

    if -robot.dimBoard <= new_x <= robot.dimBoard
        robot.posicion[1] = new_x
    else
        robot.Direction[1] *= -1
    end
    if -robot.dimBoard <= new_y <= robot.dimBoard
        robot.posicion[2] = new_y
    else
        robot.Direction[2] *= -1
    end

    updatePallet!(robot)

    robot.angulo = atan(robot.Direction[2], robot.Direction[1])

    updateForkCenter!(robot)

    if robot.transportando != nothing && (robot.actividad == "DROPPING_OFF" || robot.actividad == "EN_ROUTE")
        Main.ModuloCaja.setPos(robot.transportando, robot.forkCenter, robot.angulo)
    end
end

end
