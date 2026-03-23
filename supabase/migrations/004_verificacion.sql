-- ============================================================
-- Fantasy Andalucía — Sistema de Puntuación
-- Documentación de referencia y script de verificación
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- TABLA DE PUNTOS (referencia)
-- ────────────────────────────────────────────────────────────
--
-- ACCIÓN                     PT   DF   CC   DL
-- ─────────────────────────────────────────────
-- Titular (jugó desde inicio) +2   +2   +2   +2
-- Gol                        +10  +8   +6   +4
-- Asistencia                  +3   +3   +3   +3
-- Portería a cero (titular)   +8   +4   +2    -
-- Tarjeta amarilla            -1   -1   -1   -1
-- Doble amarilla (= roja)     -5   -5   -5   -5
-- Tarjeta roja directa        -4   -4   -4   -4
-- ─────────────────────────────────────────────

-- Verificar que el sistema de puntos funciona correctamente:
-- Simular estadísticas de un delantero con 2 goles y 1 amarilla

/*
  Esperado:
  - Titular: +2
  - 2 goles DL: +8
  - 1 amarilla: -1
  = 9 puntos
*/
SELECT
  j.nombre || ' ' || j.apellidos AS jugador,
  j.posicion,
  ej.titular,
  ej.goles,
  ej.asistencias,
  ej.tarjetas_amarillas,
  ej.tarjetas_rojas,
  ej.puntos_calculados
FROM public.estadisticas_jugadores ej
JOIN public.jugadores j ON j.id = ej.jugador_id
ORDER BY ej.puntos_calculados DESC
LIMIT 20;

-- Ver la clasificación de todas las ligas
SELECT
  l.nombre AS liga,
  vc.posicion,
  vc.username,
  vc.puntos_totales,
  vc.puntos_ultima_jornada
FROM public.vista_clasificacion vc
JOIN public.ligas l ON l.id = vc.liga_id
ORDER BY l.nombre, vc.posicion;

-- Comprobación de integridad: equipos con más de 15 jugadores
SELECT ef.id, COUNT(efj.id) AS num_jugadores
FROM public.equipos_fantasy ef
JOIN public.equipo_fantasy_jugadores efj ON efj.equipo_fantasy_id = ef.id
GROUP BY ef.id
HAVING COUNT(efj.id) > 15;

-- Ver puntos de la jornada 8 en todas las ligas
SELECT
  u.username,
  l.nombre AS liga,
  pj.puntos AS puntos_j8
FROM public.puntos_jornada pj
JOIN public.usuarios u ON u.id = pj.user_id
JOIN public.ligas l ON l.id = pj.liga_id
JOIN public.jornadas j ON j.id = pj.jornada_id
WHERE j.numero = 8
ORDER BY pj.puntos DESC;
