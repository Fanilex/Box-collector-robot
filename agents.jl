using Sockets
using JSON
using Random


mutable struct Caja
   id::Int
   posicion::Tuple{Int, Int}
   recogida::Bool
end


mutable struct Robot
   id::Int
   posicion::Tuple{Int, Int}
   cargando::Bool
   destino::Tuple{Int, Int}
   path::Array{Tuple{Int, Int}}
   cargando_caja::Union{Caja, Nothing}
end


num_robots = 5
num_cajas_por_carril = 20
num_carriles = num_robots
ancho_carril = 160
altura_grilla = 100


zona_entrega_y = (altura_grilla - 10):altura_grilla
discharge_positions = [(x, y) for x in 1:ancho_carril:num_robots*ancho_carril, y in (altura_grilla-9):altura_grilla]
available_positions = discharge_positions[:]


robots = Robot[]
cajas = Caja[]
delivered_cajas = Caja[]


for i in 1:num_robots
  x_pos = (i - 1) * ancho_carril + ancho_carril ÷ 5
  robot_pos = (x_pos, altura_grilla + (-5))
  push!(robots, Robot(i, robot_pos, false, robot_pos, [], nothing))
   for j in 1:num_cajas_por_carril
      x = rand(x_pos-50:10:x_pos+50)
      y = rand(1:minimum(zona_entrega_y) - 1)
      push!(cajas, Caja((i - 1) * num_cajas_por_carril + j, (x, y), false))
  end
end


function encontrar_caja(robot::Robot)
   min_dist = Inf
   closest_caja = nothing
   for caja in cajas
       if !caja.recogida && caja.posicion[1] == robot.posicion[1]
           dist = abs(robot.posicion[2] - caja.posicion[2])
           if dist < min_dist
               min_dist = dist
               closest_caja = caja
           end
       end
   end
   return closest_caja
end


function bfs_path(origen::Tuple{Int, Int}, destino::Tuple{Int, Int})
   queue = [(origen, [])]
   visited = Set([origen])
   while !isempty(queue)
       (pos, path) = popfirst!(queue)
       if pos == destino
           return path
       end
       for next_pos in [(pos[1], pos[2] + 1), (pos[1], pos[2] - 1)]
           if next_pos[2] >= 0 && next_pos[2] <= altura_grilla && !(next_pos in visited)
               push!(queue, (next_pos, path == [] ? [next_pos] : [path..., next_pos]))
               push!(visited, next_pos)
           end
       end
   end
   return []
end


function asignar_posicion_entrega(caja::Caja)
   if !isempty(available_positions)
       caja.posicion = popfirst!(available_positions)
   end
end


function simular()
   server = connect(5555)
   println("Conectado al frontend en Python")
  
   while true
       for robot in robots
           if isempty(robot.path)
               if robot.cargando
                   destino = (robot.posicion[1], minimum(zona_entrega_y))
                   robot.path = bfs_path(robot.posicion, destino)
               else
                   caja = encontrar_caja(robot)
                   if caja !== nothing
                       robot.destino = caja.posicion
                       robot.path = bfs_path(robot.posicion, caja.posicion)
                       caja.recogida = true
                       robot.cargando_caja = caja
                   end
               end
           else
               robot.posicion = popfirst!(robot.path)
              
               if isempty(robot.path)
                   if robot.cargando
                       if robot.posicion[2] in zona_entrega_y
                           robot.cargando = false
                           if robot.cargando_caja !== nothing
                               asignar_posicion_entrega(robot.cargando_caja)
                               push!(delivered_cajas, robot.cargando_caja)
                               robot.cargando_caja = nothing
                           end
                       end
                   else
                       robot.cargando = true
                   end
               end
           end
       end
      
       estado = Dict(
           "robots" => [Dict("id" => robot.id, "posicion" => robot.posicion, "cargando" => robot.cargando) for robot in robots],
           "cajas" => [Dict("id" => caja.id, "posicion" => caja.posicion, "recogida" => caja.recogida) for caja in cajas],
           "delivered_cajas" => [Dict("id" => caja.id, "posicion" => caja.posicion) for caja in delivered_cajas]
       )
       mensaje = JSON.json(estado) * "\n"
       write(server, mensaje)
      
       sleep(0.1)
   end
end


simular()