using StaticArrays, Random

# Definir agente Caja
mutable struct Caja
   id::Int
   pos::SVector{2, Float64}
end

# Definir agente Robot
mutable struct Robot
   id::Int
   pos::SVector{2, Float64}
   target_pos::SVector{2, Float64}
end

# Función para mover el robot hacia la caja
function move_robot!(robot::Robot)
   dx, dy = robot.target_pos .- robot.pos
   distance = sqrt(dx^2 + dy^2)
   
   # Verificar si el robot ya está en la posición de la caja (o muy cerca)
   if distance < 0.1
      println("Robot alcanzó la caja en la posición ", robot.pos)
      return true  # Indica que el objetivo ha sido alcanzado
   end

   # Calcular el paso en dirección a la caja, con un tamaño de paso visible
   step_size = min(1.0, distance)  # Ajuste para dar un paso máximo de 1.0 o menor si está cerca
   step = SVector(dx / distance * step_size, dy / distance * step_size)
   robot.pos += step
   return false  # El objetivo aún no ha sido alcanzado
end

# Inicializar agentes
function initialize_agents()
   # Posición inicial del robot y de la caja en el espacio continuo
   robot = Robot(1, SVector(1.0, 1.0), SVector(rand(1.0:20.0), rand(1.0:20.0)))
   caja = Caja(1, robot.target_pos)  # La caja en una posición aleatoria
   return robot, caja
end

# Ejecutar varios pasos de simulación hasta que el robot alcance la caja
robot, caja = initialize_agents()
println("Posiciones iniciales:")
println("Robot:", robot)
println("Caja:", caja)

# Ciclo de simulación
for i in 1:100  # Limite de pasos para evitar ciclos infinitos
   println("\nPaso $i:")
   reached = move_robot!(robot)
   println("Posición actual del robot:", robot.pos)
   if reached
      println("Simulación completada: el robot alcanzó la caja.")
      break
   end
end
