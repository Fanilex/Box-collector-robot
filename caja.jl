# caja

module ModuloCaja
    export Caja, crearCaja, setPos, setPosYEstado!, get_estado_caja, set_estado_caja, get_posicion_caja, get_angulo_caja, to_dict
    using Random
    using JSON  
    # Estructura mutable para representar una caja
    mutable struct Caja
        posicion::Vector{Float64}  # Posición [x, y, z] de la caja
        angulo::Float64            # Ángulo de orientación de la caja
        estado_caja::String        # Estado actual de la caja 
    end

    # Extensión de la función Dict para serializar Caja a JSON
    function Base.Dict(caja::Caja)
        Dict(
            "posicion" => caja.posicion,
            "angulo" => caja.angulo,
            "estado_caja" => caja.estado_caja
        )
    end

    # Función para crear una nueva caja con posiciones aleatorias fuera del margen y zona de descarga
    function crearCaja(dimBoard::Float64, zonaDescarga::Float64, margin::Float64)
        min_coord = -dimBoard + 10 + margin  # Evita crear dentro del margen inferior
        max_coord = dimBoard - 10 - margin   # Evita crear dentro del margen superior
        x = rand() * (max_coord - min_coord) + min_coord
        y = rand() * (max_coord - min_coord) + min_coord
        # Repetir hasta que la caja no esté en la zona de descarga
        while y >= dimBoard - zonaDescarga - margin
            x = rand() * (max_coord - min_coord) + min_coord
            y = rand() * (max_coord - min_coord) + min_coord
        end
        posicion = [x, y, 3.0]               # Posición inicial con z=3.0
        angulo = rand() * 2π                  # Ángulo aleatorio entre 0 y 2π
        estado_caja = "esperando"             # Estado inicial de la caja
        return Caja(posicion, angulo, estado_caja)
    end

    # Función para establecer la posición y ángulo de una caja
    function setPos(caja::Caja, pos::Vector{Float64}, an::Float64)
        caja.posicion = pos
        caja.angulo = an
    end

    # Función para establecer posición, ángulo y estado de una caja
    function setPosYEstado!(caja::Caja, pos::Vector{Float64}, an::Float64, estado::String)
        caja.posicion = pos
        caja.angulo = an
        caja.estado_caja = estado
    end

    # Getter para el estado de la caja
    function get_estado_caja(caja::Caja)
        return caja.estado_caja
    end

    # Setter para el estado de la caja
    function set_estado_caja(caja::Caja, estado::String)
        caja.estado_caja = estado
    end

    # Getter para la posición de la caja
    function get_posicion_caja(caja::Caja)
        return caja.posicion
    end

    # Getter para el ángulo de la caja
    function get_angulo_caja(caja::Caja)
        return caja.angulo
    end

    # Función para crear una representación serializable de la caja
    function to_dict(caja::Caja)
       return Dict(
           "position" => caja.posicion,
           "angle" => caja.angulo,
           "state" => caja.estado_caja
       )
    end

end  # Fin del módulo ModuloCaja