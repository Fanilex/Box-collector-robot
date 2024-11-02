module ModuloCaja
export Caja, crearCaja, setPos
export get_estado_caja, set_estado_caja
export get_posicion_caja, get_angulo_caja
using Random
using JSON  # Soporte para serialización JSON

mutable struct Caja
    posicion::Vector{Float64}
    angulo::Float64
    estado_caja::String
end

# Soporte para serialización a JSON
function Base.Dict(caja::Caja)
    Dict(
        "posicion" => caja.posicion,
        "angulo" => caja.angulo,
        "estado_caja" => caja.estado_caja
    )
end

function crearCaja(dimBoard::Float64, zonaDescarga::Float64, margin::Float64)
    min_coord = -dimBoard + 10 + margin  # Asegura que no se cree dentro del margen
    max_coord = dimBoard - 10 - margin
    x = rand() * (max_coord - min_coord) + min_coord
    y = rand() * (max_coord - min_coord) + min_coord
    # Evitar que las cajas se generen en la zona de descarga
    while y >= dimBoard - zonaDescarga - margin
        x = rand() * (max_coord - min_coord) + min_coord
        y = rand() * (max_coord - min_coord) + min_coord
    end
    posicion = [x, y, 3.0]
    angulo = rand() * 2π
    estado_caja = "esperando"
    return Caja(posicion, angulo, estado_caja)
end

function setPos(caja::Caja, pos::Vector{Float64}, an::Float64)
    caja.posicion = pos
    caja.angulo = an
end

# Funciones de acceso (getters y setters)
function get_estado_caja(caja::Caja)
    return caja.estado_caja
end

function set_estado_caja(caja::Caja, estado::String)
    caja.estado_caja = estado
end

function get_posicion_caja(caja::Caja)
    return caja.posicion
end

function get_angulo_caja(caja::Caja)
    return caja.angulo
end

# Add a function to create a serializable representation
function to_dict(caja::Caja)
    return Dict(
        "position" => caja.posicion,
        "angle" => caja.angulo,
        "state" => caja.estado_caja
    )
end

end  # Fin del módulo ModuloCaja
