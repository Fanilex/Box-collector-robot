# robot

include("caja.jl") 
using .ModuloCaja
using Statistics  # Importar el módulo Statistics para mean y std

module ModuloRobot
    export Robot, crearRobot, update, transportar, soltar
    export get_estado_robot, get_posicion, get_angulo, asignar_zona_descarga
    export imprimir_estadisticas
    using Random
    using LinearAlgebra  # Para operaciones vectoriales

    # Estructura mutable para representar un robot
    mutable struct Robot
        dimBoard::Float64
        zonaDescarga::Float64
        posicion::Vector{Float64}            # [x, y, z] posición del robot
        estado_robot::String                 # Estado actual del robot
        contador::Int                         # Contador de eventos
        puntoCarga::Vector{Float64}          # Punto de carga asociado al robot
        caja_recogida::Union{Nothing, Main.ModuloCaja.Caja}  # Caja actualmente recogida
        angulo::Float64                       # Ángulo de orientación del robot
        rotando::Bool                        # Indica si el robot está rotando
        angulo_objetivo::Float64              # Ángulo objetivo para rotar
        velocidad_rotacion::Float64           # Velocidad de rotación
        velocidad::Float64                    # Velocidad de movimiento
        zona_descarga_robot::Tuple{Float64, Float64, Float64, Float64}  # Zona de descarga asignada
        posiciones_pilas::Vector{Vector{Float64}}  # Posiciones de las pilas en la zona de descarga
        indice_pila_actual::Int               # Índice de la pila actual
        altura_pila_actual::Int               # Altura actual de la pila
        margin::Float64                       # Margen para límites del tablero
        seccionAlmacen::Int                   # Sección de almacenamiento asignada
        movement_count::Int                   # Contador de movimientos realizados
        boxes_carried::Int                    # Contador de cajas transportadas
    end

    function to_dict(robot::Robot)
        return Dict(
            "position" => robot.posicion,
            "angle" => robot.angulo,
            "state" => robot.estado_robot,
            "movement_count" => robot.movement_count,  # Contador de movimientos
            "boxes_carried" => robot.boxes_carried       # Contador de cajas transportadas
        )
    end

    # Función para crear un nuevo robot con posiciones y parámetros aleatorios
    function crearRobot(dimBoard::Float64, zonaDescarga::Float64, vel::Float64, num_robot::Int, total_robots::Int, margin::Float64)
        # Definir límites de posición inicial evitando márgenes y zona de descarga
        x_min = -dimBoard + margin
        x_max = dimBoard - margin
        y_min = -dimBoard + margin
        y_max = dimBoard - zonaDescarga - margin

        # Generar posición inicial aleatoria
        x = rand() * (x_max - x_min) + x_min
        y = rand() * (y_max - y_min) + y_min
        posicion = [x, y, 13.0]  # Posición con z fija

        # Asignar ángulo inicial cercano a pi/2 (90 grados)
        angulo = pi/2 + rand() * 0.2 - 0.1
        estado_robot = "buscar"       # Estado inicial
        contador = 0
        puntoCarga = zeros(3)         # Punto de carga inicializado en (0,0,0)
        caja_recogida = nothing        # No hay caja recogida inicialmente
        rotando = false
        angulo_objetivo = angulo
        velocidad_rotacion = pi / 4    # Velocidad de rotación
        velocidad = 100                 # Velocidad de movimiento con vel o vemos

        # Asignar sección de almacenamiento única a cada robot
        seccionAlmacen = num_robot

        # Calcular ancho de zona de descarga por robot
        zona_ancho = (1.5 * dimBoard) / total_robots
        target_x = -dimBoard + (seccionAlmacen - 1) * zona_ancho + zona_ancho / 2

        # Definir zona de descarga individual para el robot
        x_min_descarga = target_x - zona_ancho / 4
        x_max_descarga = target_x + zona_ancho / 4
        y_min_descarga = dimBoard - zonaDescarga - margin
        y_max_descarga = dimBoard - margin

        zona_descarga_robot = (x_min_descarga, x_max_descarga, y_min_descarga, y_max_descarga)

        # Inicializar posiciones de pilas en la zona de descarga
        posiciones_pilas = []
        num_pilas = 5  # Número máximo de pilas
        for i in 1:num_pilas
            x_pila = x_min_descarga + (i - 0.5) * ((x_max_descarga - x_min_descarga) / num_pilas)
            y_pila = y_min_descarga + zonaDescarga / 2  # Centralizar en Y
            push!(posiciones_pilas, [x_pila, y_pila])
        end
        indice_pila_actual = 1
        altura_pila_actual = 0

        # Crear instancia del robot
        robot = Robot(dimBoard, zonaDescarga, posicion, estado_robot, contador, puntoCarga, caja_recogida,
                      angulo, rotando, angulo_objetivo, velocidad_rotacion, velocidad,
                      zona_descarga_robot, posiciones_pilas, indice_pila_actual, altura_pila_actual,
                      margin, seccionAlmacen, 0, 0)  # movement_count y boxes_carried inicializados a 0
        updatePuntoCarga!(robot)  # Actualizar punto de carga
        return robot
    end

    # Función para actualizar el punto de carga del robot basado en su orientación
    function updatePuntoCarga!(robot::Robot)
        offset = [22.0, 0.0, 0.0]  # Desplazamiento desde la posición del robot
        rotation_matrix = [
            cos(robot.angulo) -sin(robot.angulo) 0.0;
            sin(robot.angulo) cos(robot.angulo)  0.0;
            0.0             0.0              1.0
        ]
        rotated_offset = rotation_matrix * offset
        robot.puntoCarga = robot.posicion .+ rotated_offset  # Nueva posición de punto de carga
        robot.puntoCarga[3] = robot.posicion[3]            # Mantener z fijo
    end

    # Función para transportar una caja por el robot
    function transportar(robot::Robot, caja)
        println("Attempting to transport box...")  # Debug: Entrada a la función
        Main.ModuloCaja.setPos(caja, robot.puntoCarga, robot.angulo)  # Actualizar posición de la caja
        Main.ModuloCaja.set_estado_caja(caja, "recogida")             # Cambiar estado de la caja
        robot.caja_recogida = caja                                   # Asignar caja al robot
        robot.estado_robot = "caja_recogida"                         # Actualizar estado del robot
        println("Box is now being transported. Robot state: ", robot.estado_robot)  # Debug: Confirmación
    end

    # Función para soltar una caja en la zona de descarga
    function soltar(robot::Robot)
        if robot.caja_recogida != nothing
            # Obtener posición de la pila actual
            pila_pos = robot.posiciones_pilas[robot.indice_pila_actual]
            altura = robot.altura_pila_actual * 6.0  # Incrementar altura para apilar
            pos_caja = [pila_pos[1], pila_pos[2], 3.0 + altura]  # Nueva posición de la caja

            # Actualizar posición y estado de la caja
            Main.ModuloCaja.setPosYEstado!(robot.caja_recogida, pos_caja, 0.0, "soltada")
            robot.altura_pila_actual += 1  # Incrementar altura de pila

            # Verificar si se necesita crear una nueva pila
            if robot.altura_pila_actual >= 5
                robot.altura_pila_actual = 0
                robot.indice_pila_actual += 1
                if robot.indice_pila_actual > length(robot.posiciones_pilas)
                    # Crear una nueva pila a la derecha
                    new_pila_x = last(robot.posiciones_pilas)[1] + 20.0
                    new_pila_y = last(robot.posiciones_pilas)[2]
                    push!(robot.posiciones_pilas, [new_pila_x, new_pila_y])
                    robot.indice_pila_actual = length(robot.posiciones_pilas)
                end
            end

            # Reiniciar estado del robot
            robot.caja_recogida = nothing
            robot.estado_robot = "buscar"  # Listo para buscar próxima caja
            robot.angulo_objetivo = pi/2    # Dirección estándar hacia arriba
            robot.rotando = true

            # Incrementar el contador de cajas transportadas
            robot.boxes_carried += 1

            # Imprimir estadísticas del robot con promedio de movimientos por caja
            println("Robot en sección ", robot.seccionAlmacen, " ha transportado ", robot.boxes_carried, " cajas y realizado ", robot.movement_count, " movimientos.")
            if robot.boxes_carried > 0
                promedio_movimientos = robot.movement_count / robot.boxes_carried
                println("  Promedio de movimientos por caja: ", round(promedio_movimientos, digits=2))
            else
                println("  Promedio de movimientos por caja: N/A (No ha transportado cajas)")
            end

            println("Robot is now ready to search for the next box.")  # Debug: Confirmación
        else
            println("Warning: Attempting to release a box, but no box is currently held by the robot.")  # Advertencia
        end
    end

    # Función para normalizar ángulos entre 0 y 2π
    function wrap(angle::Float64)
        return mod(angle, 2π)
    end

    # Manejador de eventos para el estado del robot
    function eventHandler!(robot::Robot, paquetes)
        println("Current robot state: ", robot.estado_robot)  # Debug: Estado actual

        try
            if robot.estado_robot == "buscar"
                # Encontrar la caja más cercana que esté esperando
                closest_box = nothing
                min_distance = 1000.0  # Rango máximo de detección corregido a 1000.0 unidades
                println("Robot buscando cajas dentro de rango de 1000.0 unidades.")

                for box in paquetes
                    if Main.ModuloCaja.get_estado_caja(box) == "esperando"
                        box_pos = Main.ModuloCaja.get_posicion_caja(box)
                        dist = norm([robot.posicion[1] - box_pos[1], robot.posicion[2] - box_pos[2]])
                        #println("Evaluando caja en posición ", box_pos, " con distancia ", dist)
                        if dist < min_distance
                            min_distance = dist
                            closest_box = box
                        end
                    end
                end

                # Si se encuentra una caja, ajustar ángulo objetivo y cambiar estado
                if closest_box != nothing
                    box_pos = Main.ModuloCaja.get_posicion_caja(closest_box)
                    robot.angulo_objetivo = atan(box_pos[2] - robot.posicion[2], box_pos[1] - robot.posicion[1])
                    robot.rotando = true
                    robot.estado_robot = "rotando_a_caja"
                    println("Targeting box at position: ", box_pos)
                else
                    println("No available boxes found.")
                end

            elseif robot.estado_robot == "rotando_a_caja"
                # Después de rotar, cambiar a estado de movimiento hacia la caja
                if !robot.rotando
                    robot.estado_robot = "moviendo_a_caja"
                    println("Rotation complete. Moving towards the box.")
                end

            elseif robot.estado_robot == "moviendo_a_caja"
                # Verificar distancia a la caja objetivo y recogerla si está cerca
                closest_box = nothing
                min_distance = 1000.0  # Rango máximo de detección corregido a 1000.0 unidades
                println("Robot moviéndose hacia la caja.")

                for box in paquetes
                    if Main.ModuloCaja.get_estado_caja(box) == "esperando"
                        box_pos = Main.ModuloCaja.get_posicion_caja(box)
                        dist = norm([robot.posicion[1] - box_pos[1], robot.posicion[2] - box_pos[2]])
                        #println("Evaluando caja en posición ", box_pos, " con distancia ", dist)
                        if dist < min_distance
                            min_distance = dist
                            closest_box = box
                        end
                    end
                end

                if closest_box != nothing && min_distance < 10.0
                    println("Arrived at box. Picking up box.")  # Debug
                    transportar(robot, closest_box)             # Transportar la caja
                    robot.estado_robot = "caja_recogida"         # Actualizar estado
                end

            elseif robot.estado_robot == "caja_recogida"
                # Calcular ángulo hacia la zona de descarga asignada
                x_center = (robot.zona_descarga_robot[1] + robot.zona_descarga_robot[2]) / 2
                y_center = (robot.zona_descarga_robot[3] + robot.zona_descarga_robot[4]) / 2
                robot.angulo_objetivo = atan(y_center - robot.posicion[2], x_center - robot.posicion[1])
                robot.rotando = true
                robot.estado_robot = "rotando_a_descarga"
                println("Heading to drop-off zone. Target angle: ", robot.angulo_objetivo)  # Debug

            elseif robot.estado_robot == "rotando_a_descarga"
                # Después de rotar, cambiar a estado de movimiento hacia la descarga
                if !robot.rotando
                    robot.estado_robot = "yendo_a_descarga"
                    println("Rotation complete. Moving towards the drop-off zone.")
                end

            elseif robot.estado_robot == "yendo_a_descarga"
                # Verificar si el robot ha llegado a su zona de descarga
                x, y = robot.posicion[1], robot.posicion[2]
                x_min, x_max, y_min, y_max = robot.zona_descarga_robot

                if x >= x_min && x <= x_max && y >= y_min && y <= y_max
                    robot.estado_robot = "soltando_caja"  # Cambiar a estado de soltar
                    println("Reached drop-off zone.")
                end

            elseif robot.estado_robot == "soltando_caja"
                println("Releasing box at drop-off zone...")  # Debug
                soltar(robot)                                  # Soltar la caja
                robot.estado_robot = "buscar"                   # Reiniciar estado
                robot.angulo_objetivo = pi/2                    # Dirección estándar hacia arriba
                robot.rotando = true
            end

        catch e
            println("Error in eventHandler!: ", e)               # Debug: Error en manejador
            println("Stacktrace: ", stacktrace(e))               # Debug: Stacktrace
        end
    end

    # Función para actualizar el estado del robot
    function update(robot::Robot, paquetes)
        try
            eventHandler!(robot, paquetes)  # Manejar eventos según estado

            # Definir límites del tablero
            x_min = -robot.dimBoard + robot.margin
            x_max = robot.dimBoard - robot.margin
            y_min = -robot.dimBoard + robot.margin
            y_max = robot.dimBoard - robot.margin

            if robot.rotando
                # Lógica de rotación hacia ángulo objetivo
                diferencia = robot.angulo_objetivo - robot.angulo
                if abs(diferencia) > pi
                    diferencia -= sign(diferencia) * 2π
                end
                incremento = robot.velocidad_rotacion * sign(diferencia)
                if abs(diferencia) > abs(incremento)
                    robot.angulo += incremento
                    robot.movement_count += 1
                else
                    robot.angulo = robot.angulo_objetivo
                    robot.rotando = false
                    robot.movement_count += 1
                end
                robot.angulo = wrap(robot.angulo)  # Normalizar ángulo
            elseif robot.estado_robot == "moviendo_a_caja" || robot.estado_robot == "yendo_a_descarga"
                # Movimiento en dirección del ángulo actual
                delta_x = robot.velocidad * cos(robot.angulo) * 0.05  # Factor de ajuste de velocidad
                delta_y = robot.velocidad * sin(robot.angulo) * 0.05
                new_x = robot.posicion[1] + delta_x
                new_y = robot.posicion[2] + delta_y

                # Verificar si el nuevo movimiento está dentro de los límites
                if new_x < x_min || new_x > x_max || new_y < y_min || new_y > y_max
                    println("Robot alcanzó un límite. Ajustando dirección.")  # Debug
                    robot.angulo += π  # Girar 180 grados
                    robot.angulo = wrap(robot.angulo)  # Normalizar ángulo
                else
                    # Actualizar posición si está dentro de límites
                    robot.posicion[1] = new_x
                    robot.posicion[2] = new_y
                    robot.movement_count += 1
                end
            end

            updatePuntoCarga!(robot)  # Actualizar punto de carga

            if robot.caja_recogida != nothing
                # Actualizar posición de la caja recogida
                Main.ModuloCaja.setPos(robot.caja_recogida, robot.puntoCarga, robot.angulo)
            end

        catch e
            println("Error in update: ", e)             # Debug: Error en actualización
            println("Stacktrace: ", Base.stacktrace())  # Debug: Stacktrace
        end
    end

    # Getters para acceder a atributos del robot
    function get_estado_robot(robot::Robot)
        return robot.estado_robot
    end

    function get_posicion(robot::Robot)
        return robot.posicion
    end

    function get_angulo(robot::Robot)
        return robot.angulo
    end

    # Asignar zona de descarga al robot
    function asignar_zona_descarga(robot::Robot, x_min::Float64, x_max::Float64, y_min::Float64, y_max::Float64)
        robot.zona_descarga_robot = (x_min, x_max, y_min, y_max)
    end

    # Función para imprimir estadísticas de todos los robots
    function imprimir_estadisticas(robots::Vector{Robot})
        println("\n--- Estadísticas de los Robots ---")
        for robot in robots
            println("Robot en sección ", robot.seccionAlmacen, ":")
            println("  Movimientos totales: ", robot.movement_count)
            println("  Cajas transportadas: ", robot.boxes_carried)
            
            # Calcular y mostrar el promedio de movimientos por caja
            if robot.boxes_carried > 0
                promedio_movimientos = robot.movement_count / robot.boxes_carried
                println("  Promedio de movimientos por caja: ", round(promedio_movimientos, digits=2))
            else
                println("  Promedio de movimientos por caja: N/A (No ha transportado cajas)")
            end
        end
        println("---------------------------------\n")
    end

end  # Fin del módulo ModuloRobot
