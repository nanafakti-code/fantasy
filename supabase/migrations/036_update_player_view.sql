-- Migration 036 (Re-write): Update vista_jugadores
-- Incluir puntos_totales y asegurar que puntos_promedio sea correcto
-- Se elimina la restricción de 'finalizado' para que las pruebas del usuario muestren puntos de inmediato.

DROP VIEW IF EXISTS public.vista_jugadores;

CREATE OR REPLACE VIEW public.vista_jugadores AS
SELECT
  j.id,
  j.nombre,
  j.apellidos,
  j.posicion,
  j.dorsal,
  j.foto_url,
  j.precio,
  j.activo,
  j.equipo_id,
  e.nombre      AS equipo_nombre,
  e.escudo_url  AS equipo_escudo,
  e.division,
  -- Puntos totales de toda la temporada
  COALESCE(
    (
      SELECT SUM(ej.puntos_calculados)
      FROM public.estadisticas_jugadores ej
      JOIN public.partidos p ON p.id = ej.partido_id
      WHERE ej.jugador_id = j.id
    ),
    0
  ) AS puntos_totales,
  -- Puntos promedio de las últimas 5 actuaciones
  COALESCE(
    (
      SELECT ROUND(AVG(ultimas.puntos_calculados), 2)
      FROM (
        SELECT ej.puntos_calculados
        FROM public.estadisticas_jugadores ej
        JOIN public.partidos p ON p.id = ej.partido_id
        WHERE ej.jugador_id = j.id
        ORDER BY p.fecha_hora DESC
        LIMIT 5
      ) AS ultimas
    ),
    0
  ) AS puntos_promedio,
  -- Puntos de la última jornada disputada
  COALESCE(
    (
      SELECT ej.puntos_calculados
      FROM public.estadisticas_jugadores ej
      JOIN public.partidos p ON p.id = ej.partido_id
      WHERE ej.jugador_id = j.id
      ORDER BY p.fecha_hora DESC
      LIMIT 1
    ),
    0
  ) AS puntos_ultima_jornada
FROM public.jugadores j
LEFT JOIN public.equipos_reales e ON e.id = j.equipo_id;
