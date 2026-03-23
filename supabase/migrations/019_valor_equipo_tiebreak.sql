-- Migración 019: Cálculo de Valor de Equipo y Desempate en Clasificación

-- 1. Añadir columna valor_equipo a usuarios_ligas
ALTER TABLE public.usuarios_ligas 
ADD COLUMN IF NOT EXISTS valor_equipo NUMERIC(14, 2) DEFAULT 0;

-- 2. Función para recalcular el valor de equipo de un usuario en una liga
CREATE OR REPLACE FUNCTION public.recalcular_valor_equipo_usuario(p_user_id UUID, p_liga_id UUID)
RETURNS VOID AS $$
DECLARE
    v_valor_total NUMERIC(14, 2);
    v_equipo_id UUID;
BEGIN
    -- Obtener el ID del equipo fantasy
    SELECT id INTO v_equipo_id 
    FROM public.equipos_fantasy 
    WHERE user_id = p_user_id AND liga_id = p_liga_id;

    IF v_equipo_id IS NOT NULL THEN
        -- Calcular la suma de precios de todos los jugadores que pertenecen al equipo
        SELECT COALESCE(SUM(j.precio), 0) INTO v_valor_total
        FROM public.equipo_fantasy_jugadores efj
        JOIN public.jugadores j ON j.id = efj.jugador_id
        WHERE efj.equipo_fantasy_id = v_equipo_id;

        -- Actualizar la tabla usuarios_ligas
        UPDATE public.usuarios_ligas
        SET valor_equipo = v_valor_total
        WHERE user_id = p_user_id AND liga_id = p_liga_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Trigger para actualizar valor cuando cambian los jugadores del equipo
CREATE OR REPLACE FUNCTION public.fn_trigger_update_valor_equipo()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_liga_id UUID;
BEGIN
    -- Determinar el equipo afectado
    IF (TG_OP = 'DELETE') THEN
        SELECT user_id, liga_id INTO v_user_id, v_liga_id FROM public.equipos_fantasy WHERE id = OLD.equipo_fantasy_id;
    ELSE
        SELECT user_id, liga_id INTO v_user_id, v_liga_id FROM public.equipos_fantasy WHERE id = NEW.equipo_fantasy_id;
    END IF;

    -- Recalcular
    IF v_user_id IS NOT NULL THEN
        PERFORM public.recalcular_valor_equipo_usuario(v_user_id, v_liga_id);
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_update_valor_equipo_on_change
AFTER INSERT OR UPDATE OR DELETE ON public.equipo_fantasy_jugadores
FOR EACH ROW EXECUTE FUNCTION public.fn_trigger_update_valor_equipo();

-- 4. Trigger para actualizar valor cuando cambia el precio de un jugador
CREATE OR REPLACE FUNCTION public.fn_trigger_update_valor_equipo_on_price()
RETURNS TRIGGER AS $$
BEGIN
    -- Si el precio ha cambiado, actualizar el valor de equipo de TODOS los poseedores del jugador
    IF (NEW.precio <> OLD.precio) THEN
        UPDATE public.usuarios_ligas ul
        SET valor_equipo = (
            SELECT COALESCE(SUM(j.precio), 0)
            FROM public.equipo_fantasy_jugadores efj
            JOIN public.equipos_fantasy ef ON ef.id = efj.equipo_fantasy_id
            JOIN public.jugadores j ON j.id = efj.jugador_id
            WHERE ef.user_id = ul.user_id AND ef.liga_id = ul.liga_id
        )
        WHERE ul.user_id IN (
            SELECT ef.user_id 
            FROM public.equipo_fantasy_jugadores efj
            JOIN public.equipos_fantasy ef ON ef.id = efj.equipo_fantasy_id
            WHERE efj.jugador_id = NEW.id
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_update_valor_equipo_on_price_change
AFTER UPDATE OF precio ON public.jugadores
FOR EACH ROW EXECUTE FUNCTION public.fn_trigger_update_valor_equipo_on_price();

-- 5. Actualizar la Vista de Clasificación para usar valor_equipo como criterio de desempate
DROP VIEW IF EXISTS public.vista_clasificacion CASCADE;
CREATE OR REPLACE VIEW public.vista_clasificacion AS
SELECT
  ul.liga_id,
  ul.user_id,
  u.username,
  u.avatar_url,
  ul.puntos_totales,
  ul.presupuesto,
  ul.valor_equipo,
  RANK() OVER (
    PARTITION BY ul.liga_id
    ORDER BY ul.puntos_totales DESC, ul.valor_equipo DESC
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

-- 6. Actualizar la función actualizar_clasificacion para incluir el desempate
CREATE OR REPLACE FUNCTION public.actualizar_clasificacion(p_liga_id UUID)
RETURNS void AS $$
BEGIN
  -- 1. Recalcular puntos_totales sumando todos los puntos por jornada
  UPDATE public.usuarios_ligas ul
  SET puntos_totales = (
    SELECT COALESCE(SUM(pj.puntos), 0)
    FROM public.puntos_jornada pj
    WHERE pj.user_id = ul.user_id
      AND pj.liga_id = p_liga_id
  )
  WHERE ul.liga_id = p_liga_id;

  -- 2. Recalcular posiciones (ordenadas por puntos DESC y luego valor_equipo DESC para desempate)
  WITH ranking AS (
    SELECT
      user_id,
      RANK() OVER (ORDER BY puntos_totales DESC, valor_equipo DESC) AS nueva_posicion
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

-- 7. Inicializar el valor de equipo para los datos existentes
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT user_id, liga_id FROM public.usuarios_ligas LOOP
        PERFORM public.recalcular_valor_equipo_usuario(rec.user_id, rec.liga_id);
    END LOOP;
END;
$$;
