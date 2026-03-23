-- ============================================================
-- Fantasy Andalucía — Migración 002: Funciones helpers y Vistas
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- VISTA: clasificación de una liga con posiciones calculadas
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW public.vista_clasificacion AS
SELECT
  ul.liga_id,
  ul.user_id,
  u.username,
  u.avatar_url,
  ul.puntos_totales,
  ul.presupuesto,
  RANK() OVER (
    PARTITION BY ul.liga_id
    ORDER BY ul.puntos_totales DESC
  ) AS posicion,
  -- Puntos de la última jornada cerrada
  (
    SELECT pj.puntos
    FROM public.puntos_jornada pj
    JOIN public.jornadas j ON j.id = pj.jornada_id
    WHERE pj.user_id = ul.user_id
      AND pj.liga_id = ul.liga_id
      AND j.cerrada = TRUE
    ORDER BY j.numero DESC
    LIMIT 1
  ) AS puntos_ultima_jornada
FROM public.usuarios_ligas ul
JOIN public.usuarios u ON u.id = ul.user_id;

-- ════════════════════════════════════════════════════════════
-- VISTA: jugadores con info de equipo y puntos promedio
-- ════════════════════════════════════════════════════════════
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
  e.nombre      AS equipo_nombre,
  e.escudo_url  AS equipo_escudo,
  e.division,
  -- Puntos promedio de las últimas 5 actuaciones
  COALESCE(
    (
      SELECT ROUND(AVG(ultimas.puntos_calculados), 2)
      FROM (
        SELECT ej.puntos_calculados
        FROM public.estadisticas_jugadores ej
        JOIN public.partidos p ON p.id = ej.partido_id
        WHERE ej.jugador_id = j.id
          AND p.estado = 'finalizado'
        ORDER BY p.fecha_hora DESC
        LIMIT 5
      ) AS ultimas
    ),
    0
  ) AS puntos_promedio,
  -- Total de goles
  COALESCE(
    (SELECT SUM(ej.goles) FROM public.estadisticas_jugadores ej WHERE ej.jugador_id = j.id),
    0
  ) AS total_goles,
  -- Total partidos jugados como titular
  COALESCE(
    (SELECT COUNT(*) FROM public.estadisticas_jugadores ej WHERE ej.jugador_id = j.id AND ej.titular = TRUE),
    0
  ) AS partidos_titular
FROM public.jugadores j
LEFT JOIN public.equipos_reales e ON e.id = j.equipo_id;

-- ════════════════════════════════════════════════════════════
-- FUNCIÓN: generar código de invitación único
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.generar_codigo_invitacion()
RETURNS CHAR(8) AS $$
DECLARE
  codigo CHAR(8);
  existe BOOLEAN;
BEGIN
  LOOP
    -- Generar 8 caracteres aleatorios (mayúsculas + números)
    codigo := UPPER(SUBSTRING(
      REPLACE(REPLACE(
        encode(gen_random_bytes(6), 'base64'),
      '+', 'A'), '/', 'B'),
    1, 8));

    -- Verificar que no exista
    SELECT EXISTS(
      SELECT 1 FROM public.ligas WHERE codigo_invitacion = codigo
    ) INTO existe;

    EXIT WHEN NOT existe;
  END LOOP;

  RETURN codigo;
END;
$$ LANGUAGE plpgsql;

-- ════════════════════════════════════════════════════════════
-- FUNCIÓN: unirse a una liga por código
-- Segura — verifica cupo y estado
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.unirse_a_liga(
  p_codigo        CHAR(8),
  p_user_id       UUID
)
RETURNS JSON AS $$
DECLARE
  v_liga           RECORD;
  v_participantes  INT;
  v_ya_miembro     BOOLEAN;
  v_equipo_id      UUID;
  v_presupuesto    NUMERIC;
BEGIN
  -- 1. Buscar la liga
  SELECT * INTO v_liga
  FROM public.ligas
  WHERE codigo_invitacion = p_codigo;

  IF NOT FOUND THEN
    RETURN json_build_object('error', 'Código de invitación no válido');
  END IF;

  -- 2. Verificar estado
  IF v_liga.estado = 'finalizada' THEN
    RETURN json_build_object('error', 'Esta liga ya ha finalizado');
  END IF;

  -- 3. Verificar si ya es miembro
  SELECT EXISTS(
    SELECT 1 FROM public.usuarios_ligas
    WHERE user_id = p_user_id AND liga_id = v_liga.id
  ) INTO v_ya_miembro;

  IF v_ya_miembro THEN
    RETURN json_build_object('error', 'Ya eres miembro de esta liga');
  END IF;

  -- 4. Verificar cupo
  SELECT COUNT(*) INTO v_participantes
  FROM public.usuarios_ligas
  WHERE liga_id = v_liga.id;

  IF v_participantes >= v_liga.max_participantes THEN
    RETURN json_build_object('error', 'La liga está completa');
  END IF;

  -- 5. Insertar membresía
  v_presupuesto := v_liga.presupuesto_inicial;

  INSERT INTO public.usuarios_ligas (user_id, liga_id, presupuesto)
  VALUES (p_user_id, v_liga.id, v_presupuesto);

  -- 6. Crear equipo fantasy vacío
  INSERT INTO public.equipos_fantasy (user_id, liga_id)
  VALUES (p_user_id, v_liga.id)
  RETURNING id INTO v_equipo_id;

  RETURN json_build_object(
    'success', true,
    'liga_id', v_liga.id,
    'liga_nombre', v_liga.nombre,
    'equipo_fantasy_id', v_equipo_id,
    'presupuesto', v_presupuesto
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ════════════════════════════════════════════════════════════
-- FUNCIÓN: crear liga y unirse automáticamente como creador
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.crear_liga(
  p_nombre              VARCHAR(100),
  p_max_participantes   INT DEFAULT 20,
  p_division            division DEFAULT 'segunda_andaluza',
  p_user_id             UUID DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_user_id     UUID;
  v_codigo      CHAR(8);
  v_liga_id     UUID;
  v_presupuesto NUMERIC := 50000000;
BEGIN
  -- Usar user_id del parámetro o del contexto auth
  v_user_id := COALESCE(p_user_id, auth.uid());

  IF v_user_id IS NULL THEN
    RETURN json_build_object('error', 'Usuario no autenticado');
  END IF;

  -- Generar código único
  v_codigo := public.generar_codigo_invitacion();

  -- Crear la liga
  INSERT INTO public.ligas (
    nombre, creador_id, codigo_invitacion,
    max_participantes, presupuesto_inicial, division
  )
  VALUES (
    p_nombre, v_user_id, v_codigo,
    p_max_participantes, v_presupuesto, p_division
  )
  RETURNING id INTO v_liga_id;

  -- Unirse automáticamente como creador
  INSERT INTO public.usuarios_ligas (user_id, liga_id, presupuesto)
  VALUES (v_user_id, v_liga_id, v_presupuesto);

  -- Crear equipo fantasy vacío
  INSERT INTO public.equipos_fantasy (user_id, liga_id)
  VALUES (v_user_id, v_liga_id);

  RETURN json_build_object(
    'success', true,
    'liga_id', v_liga_id,
    'codigo_invitacion', v_codigo
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ════════════════════════════════════════════════════════════
-- FUNCIÓN: actualizar posiciones/puntos de la clasificación
-- Llamada tras cerrar una jornada
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.actualizar_clasificacion(p_liga_id UUID)
RETURNS void AS $$
BEGIN
  -- Recalcular puntos_totales sumando todos los puntos por jornada
  UPDATE public.usuarios_ligas ul
  SET puntos_totales = (
    SELECT COALESCE(SUM(pj.puntos), 0)
    FROM public.puntos_jornada pj
    WHERE pj.user_id = ul.user_id
      AND pj.liga_id = p_liga_id
  )
  WHERE ul.liga_id = p_liga_id;

  -- Recalcular posiciones (ordenadas por puntos)
  WITH ranking AS (
    SELECT
      user_id,
      RANK() OVER (ORDER BY puntos_totales DESC) AS nueva_posicion
    FROM public.usuarios_ligas
    WHERE liga_id = p_liga_id
  )
  UPDATE public.usuarios_ligas ul
  SET posicion = r.nueva_posicion
  FROM ranking r
  WHERE ul.user_id = r.user_id
    AND ul.liga_id = p_liga_id;
END;
$$ LANGUAGE plpgsql;

-- ════════════════════════════════════════════════════════════
-- FUNCIÓN: calcular puntos de jornada para todos los usuarios
-- de una liga. Suma los puntos de sus titulares en esa jornada.
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.calcular_puntos_jornada_liga(
  p_liga_id    UUID,
  p_jornada_id UUID
)
RETURNS void AS $$
DECLARE
  rec RECORD;
  total_puntos NUMERIC;
BEGIN
  -- Para cada usuario en la liga
  FOR rec IN
    SELECT ul.user_id, ef.id AS equipo_id
    FROM public.usuarios_ligas ul
    JOIN public.equipos_fantasy ef
      ON ef.user_id = ul.user_id AND ef.liga_id = p_liga_id
    WHERE ul.liga_id = p_liga_id
  LOOP
    -- Sumar puntos de sus titulares en esa jornada
    SELECT COALESCE(SUM(ej.puntos_calculados), 0) INTO total_puntos
    FROM public.equipo_fantasy_jugadores efj
    JOIN public.estadisticas_jugadores ej ON ej.jugador_id = efj.jugador_id
    JOIN public.partidos p ON p.id = ej.partido_id
    WHERE efj.equipo_fantasy_id = rec.equipo_id
      AND efj.es_titular = TRUE
      AND p.jornada_id = p_jornada_id;

    -- Upsert puntos de jornada
    INSERT INTO public.puntos_jornada (user_id, liga_id, jornada_id, puntos, calculated_at)
    VALUES (rec.user_id, p_liga_id, p_jornada_id, total_puntos, NOW())
    ON CONFLICT (user_id, liga_id, jornada_id)
    DO UPDATE SET
      puntos = EXCLUDED.puntos,
      calculated_at = EXCLUDED.calculated_at;
  END LOOP;

  -- Actualizar tabla de clasificación
  PERFORM public.actualizar_clasificacion(p_liga_id);

  -- Marcar jornada como cerrada (si todos los partidos han finalizado)
  UPDATE public.jornadas
  SET cerrada = TRUE
  WHERE id = p_jornada_id
    AND NOT EXISTS (
      SELECT 1 FROM public.partidos
      WHERE jornada_id = p_jornada_id
        AND estado <> 'finalizado'
    );
END;
$$ LANGUAGE plpgsql;
