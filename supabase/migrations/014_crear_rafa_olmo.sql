-- Migración 014: Crear jugador Rafa Olmo en Chipiona C.F.
INSERT INTO public.jugadores (
  nombre, 
  apellidos, 
  equipo_id, 
  posicion, 
  precio, 
  activo
)
SELECT 
  'Rafa', 
  'Olmo', 
  id, 
  'centrocampista'::posicion, 
  1000000, 
  TRUE
FROM public.equipos_reales
WHERE nombre = 'CHIPIONA C.F.'
LIMIT 1;
