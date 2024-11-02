module ModuloRobot
export Robot, crearRobot, update, transportar

using Random
using LinearAlgebra

mutable struct Robot
    dimBoard::Float64
    zonaDescarga::Float64
    posicion::Vector{Float64}
    estado_robot::String
    direccion::Vector{Float64}
    angulo::Float64
end

function crearRobot(dimBoard::Float64, zonaDescarga::Float64, vel::Float64)
    posicion = [rand() * (2 * dimBoard) - dimBoard, rand() * (2 * dimBoard) - dimBoard, 13.0]
    estado_robot = "buscar"
    dir_vector = [rand() * 2 - 1, rand() * 2 - 1, 0.0]
    direccion = (dir_vector / norm(dir_vector)) * vel
    angulo = atan(direccion[2], direccion[1])
    Robot(dimBoard, zonaDescarga, posicion, estado_robot, direccion, angulo)
end

function update(robot::Robot)
    # Update position based on direction
    robot.posicion[1] += robot.direccion[1]
    robot.posicion[2] += robot.direccion[2]
end

function transportar(robot::Robot, caja)
    caja.posicion = copy(robot.posicion)
    caja.estado_caja = "recogida"
    robot.estado_robot = "caja_recogida"
end

end
