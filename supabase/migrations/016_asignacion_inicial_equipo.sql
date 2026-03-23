-- 016_asignacion_inicial_equipo.sql
-- Este archivo maneja la asignación de 14 jugadores iniciales cuando un usuario entra en una liga.

-- Asegurar columna clausula
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='equipo_fantasy_jugadores' AND column_name='clausula') THEN
        ALTER TABLE public.equipo_fantasy_jugadores ADD COLUMN clausula NUMERIC(14,2);
    END IF;
END $$;

-- 1. Función para seleccionar y asignar jugadores iniciales
CREATE OR REPLACE FUNCTION public.inicializar_equipo_usuario()
RETURNS TRIGGER AS $$
DECLARE
    v_equipo_id UUID;
    v_jugador_id UUID;
    v_i         INT;
BEGIN
    -- 1. Crear el Equipo Fantasy si no existe
    INSERT INTO public.equipos_fantasy (user_id, liga_id, nombre, formacion)
    VALUES (NEW.user_id, NEW.liga_id, 'Mi Equipo', '4-4-2')
    ON CONFLICT (user_id, liga_id) DO UPDATE SET created_at = NOW()
    RETURNING id INTO v_equipo_id;

    -- Limpiar posibles restos de intentos fallidos
    DELETE FROM public.equipo_fantasy_jugadores WHERE equipo_fantasy_id = v_equipo_id;

    -- 2. Asignar jugadores aleatorios por posición (1 POR, 5 DEF, 5 MED, 3 DEL = 14)
    -- PORTEROS (1)
    FOR v_jugador_id IN (
        SELECT j.id FROM public.jugadores j
        WHERE j.posicion = 'portero'
        AND j.id NOT IN (
            SELECT efj.jugador_id FROM public.equipo_fantasy_jugadores efj
            JOIN public.equipos_fantasy ef ON ef.id = efj.equipo_fantasy_id
            WHERE ef.liga_id = NEW.liga_id
        )
        ORDER BY random() LIMIT 1
    ) LOOP
        INSERT INTO public.equipo_fantasy_jugadores (equipo_fantasy_id, jugador_id, es_titular, fecha_fichaje, clausula)
        SELECT v_equipo_id, v_jugador_id, true, NOW(), precio * 1.2
        FROM public.jugadores WHERE id = v_jugador_id;
    END LOOP;

    -- DEFENSAS (5) - 4 Titulares, 1 Suplente
    v_i := 0;
    FOR v_jugador_id IN (
        SELECT j.id FROM public.jugadores j
        WHERE j.posicion = 'defensa'
        AND j.id NOT IN (
            SELECT efj.jugador_id FROM public.equipo_fantasy_jugadores efj
            JOIN public.equipos_fantasy ef ON ef.id = efj.equipo_fantasy_id
            WHERE ef.liga_id = NEW.liga_id
        )
        ORDER BY random() LIMIT 5
    ) LOOP
        INSERT INTO public.equipo_fantasy_jugadores (equipo_fantasy_id, jugador_id, es_titular, orden_suplente, fecha_fichaje, clausula)
        SELECT v_equipo_id, v_jugador_id, (v_i < 4), (CASE WHEN v_i = 4 THEN 1 ELSE NULL END), NOW(), precio * 1.2
        FROM public.jugadores WHERE id = v_jugador_id;
        v_i := v_i + 1;
    END LOOP;

    -- MEDIOS (5) - 4 Titulares, 1 Suplente
    v_i := 0;
    FOR v_jugador_id IN (
        SELECT j.id FROM public.jugadores j
        WHERE j.posicion = 'centrocampista'
        AND j.id NOT IN (
            SELECT efj.jugador_id FROM public.equipo_fantasy_jugadores efj
            JOIN public.equipos_fantasy ef ON ef.id = efj.equipo_fantasy_id
            WHERE ef.liga_id = NEW.liga_id
        )
        ORDER BY random() LIMIT 5
    ) LOOP
        INSERT INTO public.equipo_fantasy_jugadores (equipo_fantasy_id, jugador_id, es_titular, orden_suplente, fecha_fichaje, clausula)
        SELECT v_equipo_id, v_jugador_id, (v_i < 4), (CASE WHEN v_i = 4 THEN 2 ELSE NULL END), NOW(), precio * 1.2
        FROM public.jugadores WHERE id = v_jugador_id;
        v_i := v_i + 1;
    END LOOP;

    -- DELANTEROS (3) - 2 Titulares, 1 Suplente
    v_i := 0;
    FOR v_jugador_id IN (
        SELECT j.id FROM public.jugadores j
        WHERE j.posicion = 'delantero'
        AND j.id NOT IN (
            SELECT efj.jugador_id FROM public.equipo_fantasy_jugadores efj
            JOIN public.equipos_fantasy ef ON ef.id = efj.equipo_fantasy_id
            WHERE ef.liga_id = NEW.liga_id
        )
        ORDER BY random() LIMIT 3
    ) LOOP
        INSERT INTO public.equipo_fantasy_jugadores (equipo_fantasy_id, jugador_id, es_titular, orden_suplente, fecha_fichaje, clausula)
        SELECT v_equipo_id, v_jugador_id, (v_i < 2), (CASE WHEN v_i = 2 THEN 3 ELSE NULL END), NOW(), precio * 1.2
        FROM public.jugadores WHERE id = v_jugador_id;
        v_i := v_i + 1;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Crear el TRIGGER en usuarios_ligas
DROP TRIGGER IF EXISTS trg_inicializar_equipo ON public.usuarios_ligas;
CREATE TRIGGER trg_inicializar_equipo
    AFTER INSERT ON public.usuarios_ligas
    FOR EACH ROW EXECUTE FUNCTION public.inicializar_equipo_usuario();

-- 3. SISTEMA DE CLÁUSULAS Y VENTAS
CREATE OR REPLACE FUNCTION public.comprar_por_clausula(p_liga_id UUID, p_vendedor_id UUID, p_jugador_id UUID)
RETURNS VOID AS $$
DECLARE
    v_clausula      NUMERIC;
    v_fecha_fich    TIMESTAMPTZ;
    v_comprador_id  UUID := auth.uid();
    v_comprador_presupuesto NUMERIC;
    v_equipo_comprador_id UUID;
    v_equipo_vendedor_id  UUID;
BEGIN
    -- 1. Obtener datos del jugador en el equipo vendedor
    SELECT efj.clausula, efj.fecha_fichaje, ef.id 
    INTO v_clausula, v_fecha_fich, v_equipo_vendedor_id
    FROM public.equipo_fantasy_jugadores efj
    JOIN public.equipos_fantasy ef ON ef.id = efj.equipo_fantasy_id
    WHERE ef.liga_id = p_liga_id AND ef.user_id = p_vendedor_id AND efj.jugador_id = p_jugador_id;

    -- 2. Verificar bloqueo de 14 días
    IF v_fecha_fich > (NOW() - INTERVAL '14 days') THEN
        RAISE EXCEPTION 'Cláusula bloqueada. Faltan % días', 14 - (extract(epoch from (NOW() - v_fecha_fich))/86400)::int;
    END IF;

    -- 3. Obtener equipo comprador y presupuesto
    SELECT id INTO v_equipo_comprador_id FROM public.equipos_fantasy WHERE user_id = v_comprador_id AND liga_id = p_liga_id;
    SELECT presupuesto INTO v_comprador_presupuesto FROM public.usuarios_ligas WHERE user_id = v_comprador_id AND liga_id = p_liga_id;

    IF v_comprador_presupuesto < v_clausula THEN
        RAISE EXCEPTION 'Presupuesto insuficiente (Cláusula: %)', v_clausula;
    END IF;

    -- 4. EJECUTAR TRANSFERENCIA
    -- Restar dinero al comprador
    UPDATE public.usuarios_ligas SET presupuesto = presupuesto - v_clausula WHERE user_id = v_comprador_id AND liga_id = p_liga_id;
    -- Sumar dinero al vendedor
    UPDATE public.usuarios_ligas SET presupuesto = presupuesto + v_clausula WHERE user_id = p_vendedor_id AND liga_id = p_liga_id;
    -- Cambiar de equipo al jugador
    DELETE FROM public.equipo_fantasy_jugadores WHERE equipo_fantasy_id = v_equipo_vendedor_id AND jugador_id = p_jugador_id;
    INSERT INTO public.equipo_fantasy_jugadores (equipo_fantasy_id, jugador_id, es_titular, fecha_fichaje, clausula)
    SELECT v_equipo_comprador_id, p_jugador_id, false, NOW(), precio * 1.2
    FROM public.jugadores WHERE id = p_jugador_id;

    -- 5. Registrar en el historial
    INSERT INTO public.transferencias (liga_id, jugador_id, comprador_id, vendedor_id, precio, tipo)
    VALUES (p_liga_id, p_jugador_id, v_comprador_id, p_vendedor_id, v_clausula, 'clausulazo');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Vender a la liga (Instantáneo por el 90% del valor)
CREATE OR REPLACE FUNCTION public.vender_a_la_liga(p_liga_id UUID, p_jugador_id UUID)
RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_valor_jugador NUMERIC;
    v_precio_venta  NUMERIC;
    v_equipo_id     UUID;
BEGIN
    SELECT precio INTO v_valor_jugador FROM public.jugadores WHERE id = p_jugador_id;
    v_precio_venta := v_valor_jugador * 0.9; -- Venta al 90%

    SELECT id INTO v_equipo_id FROM public.equipos_fantasy WHERE user_id = v_user_id AND liga_id = p_liga_id;

    -- Eliminar del equipo
    DELETE FROM public.equipo_fantasy_jugadores WHERE equipo_fantasy_id = v_equipo_id AND jugador_id = p_jugador_id;
    -- Sumar dinero
    UPDATE public.usuarios_ligas SET presupuesto = presupuesto + v_precio_venta WHERE user_id = v_user_id AND liga_id = p_liga_id;

    -- Registrar
    INSERT INTO public.transferencias (liga_id, jugador_id, comprador_id, vendedor_id, precio, tipo)
    VALUES (p_liga_id, p_jugador_id, NULL, v_user_id, v_precio_venta, 'venta_liga');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
