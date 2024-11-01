module ModuloRobot
export Robot, crearRobot, update, transportar, soltar
using Random
using LinearAlgebra

mutable struct Robot
  dimBoard::Float64
  zonaDescarga::Float64
  posicion::Vector{Float64}
  estado_robot::String
  contador::Int
  puntoCarga::Vector{Float64}
  caja_recogida::Any
  direccion::Vector{Float64}
  angulo::Float64
end

function crearRobot(dimBoard::Float64, zonaDescarga::Float64, vel::Float64)
  posicion = [rand(-dimBoard:dimBoard), rand(-dimBoard:dimBoard), 13.0]
  estado_robot = "buscar"
  contador = 0
  puntoCarga = zeros(3)
  caja_recogida = nothing
  dir_vector = [rand(-1.0:0.1:1.0), rand(-1.0:0.1:1.0), 0.0]
  direccion = (dir_vector / norm(dir_vector)) * vel
  angulo = atan(direccion[2], direccion[1])
  robot = Robot(dimBoard, zonaDescarga, posicion, estado_robot, contador, puntoCarga, caja_recogida, direccion, angulo)
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
  Main.ModuloCaja.setPos(robot.caja_recogida, [robot.puntoCarga[1], robot.puntoCarga[2], 3.0], robot.angulo)
  robot.caja_recogida.estado_caja = "soltada"
  robot.caja_recogida = nothing
  robot.estado_robot = "buscar"
end

function eventHandler!(robot::Robot)
  if robot.estado_robot == "caja_recogida"
      # Dirección hacia la nueva zona de recolección en la esquina
      target_x = -robot.dimBoard + robot.zonaDescarga
      target_y = -robot.dimBoard + robot.zonaDescarga
      newDir = [target_x - robot.posicion[1], target_y - robot.posicion[2], 0.0]
      fctr = norm(newDir)
      newDir = newDir / fctr
      robot.direccion = newDir * norm(robot.direccion)
      robot.estado_robot = "en_camino"
      robot.contador = 0
  elseif robot.estado_robot == "en_camino"
      # Verificar si el robot está dentro de la zona de recolección
      if robot.posicion[1] >= -robot.dimBoard && robot.posicion[1] <= (-robot.dimBoard + 2 * robot.zonaDescarga) &&
         robot.posicion[2] >= -robot.dimBoard && robot.posicion[2] <= (-robot.dimBoard + 2 * robot.zonaDescarga)
          robot.direccion *= 0.01
          robot.estado_robot = "se_detiene"
          robot.contador = 0
      end
  elseif robot.estado_robot == "se_detiene"
      soltar(robot)
      robot.direccion /= 0.01
      robot.contador = 0
  elseif robot.estado_robot == "buscar"
      if rand(0:100) > 70 && robot.contador > robot.dimBoard * 2
          dir_vector = [rand(-1.0:0.1:1.0), rand(-1.0:0.1:1.0), 0.0]
          robot.direccion = dir_vector / norm(dir_vector)
          robot.contador = 0
      end
  end
  robot.contador += 1
end

function update(robot::Robot)
  eventHandler!(robot)

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

  robot.angulo = atan(robot.direccion[2], robot.direccion[1])

  updatePuntoCarga!(robot)

  if robot.caja_recogida != nothing && (robot.estado_robot == "caja_recogida" || robot.estado_robot == "en_camino")
      Main.ModuloCaja.setPos(robot.caja_recogida, robot.puntoCarga, robot.angulo)
  end
end

end
