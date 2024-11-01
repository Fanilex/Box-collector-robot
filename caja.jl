module ModuloCaja
export Caja, crearCaja, setPos
using Random

mutable struct Caja
   posicion::Vector{Float64}
   angulo::Float64
   estado_caja::String
end

function crearCaja(dimBoard::Float64, zonaDescarga::Float64)
   min_coord = -dimBoard + 10
   max_coord = dimBoard - 10
   x = rand() * (max_coord - min_coord) + min_coord
   y = rand() * (max_coord - min_coord) + min_coord
   # Evitar que las cajas se generen en la zona de descarga
   while x >= -dimBoard && x <= (-dimBoard + 2 * zonaDescarga) &&
         y >= -dimBoard && y <= (-dimBoard + 2 * zonaDescarga)
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

end
