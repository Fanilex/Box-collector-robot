module ModuloCaja

export Caja, crearCaja, setPos

using Random

mutable struct Caja
    posicion::Vector{Float64}
    angulo::Float64
    estado::String
end

function crearCaja(dimBoard::Float64, zonaDescarga::Float64)
    x = rand(-dimBoard + 10:dimBoard - 10)
    y = rand(-dimBoard + 10:dimBoard - 10)
    # Evitar que las cajas se generen en la zona de recolección
    while x >= -dimBoard && x <= (-dimBoard + 2 * zonaDescarga) &&
          y >= -dimBoard && y <= (-dimBoard + 2 * zonaDescarga)
        x = rand(-dimBoard + 10:dimBoard - 10)
        y = rand(-dimBoard + 10:dimBoard - 10)
    end
    posicion = [x, y, 3.0]
    angulo = rand() * 360.0  # Changed to full circle
    estado = "FREE"
    return Caja(posicion, angulo, estado)
end

function setPos(caja::Caja, pos::Vector{Float64}, an::Float64)
    caja.posicion = pos
    caja.angulo = an
end

end