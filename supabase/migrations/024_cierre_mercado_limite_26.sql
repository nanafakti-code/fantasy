-- Migración 024: Cierre de mercado y límite de plantilla de 26 jugadores

-- 1. Función para procesar el cierre de mercado (ejecutar para una liga)
CREATE OR REPLACE FUNCTION public.procesar_cierre_mercado(p_liga_id UUID)
RETURNS VOID AS $$
DECLARE
    r_mercado RECORD;
    r_puja RECORD;
    v_equipo_ganador_id UUID;
    v_count_jugadores INTEGER;
BEGIN
    -- Recorrer todos los jugadores que han terminado su tiempo en el mercado para esa liga
    FOR r_mercado IN 
        SELECT * FROM public.mercado 
        WHERE liga_id = p_liga_id AND fecha_fin <= now()
    LOOP
        -- Buscar la puja más alta para este jugador del mercado
        SELECT * INTO r_puja 
        FROM public.pujas 
        WHERE mercado_id = r_mercado.id 
        ORDER BY monto DESC, fecha ASC 
        LIMIT 1;

        IF FOUND THEN
            -- Obtener el equipo fantasy del ganador
            SELECT id INTO v_equipo_ganador_id 
            FROM public.equipos_fantasy 
            WHERE user_id = r_puja.usuario_id AND liga_id = p_liga_id;

            -- Contar cuántos jugadores tiene ya el ganador
            SELECT COUNT(*) INTO v_count_jugadores 
            FROM public.equipo_fantasy_jugadores 
            WHERE equipo_fantasy_id = v_equipo_ganador_id;

            -- Solo procesar si el ganador tiene menos de 26 jugadores
            IF v_count_jugadores < 26 THEN
                -- 1. Restar dinero al comprador
                UPDATE public.usuarios_ligas 
                SET presupuesto = presupuesto - r_puja.monto
                WHERE user_id = r_puja.usuario_id AND liga_id = p_liga_id;

                -- 2. Si había vendedor, darle su dinero
                IF r_mercado.vendedor_id IS NOT NULL THEN
                    UPDATE public.usuarios_ligas 
                    SET presupuesto = presupuesto + r_puja.monto
                    WHERE user_id = r_mercado.vendedor_id AND liga_id = p_liga_id;
                    
                    -- Eliminar el jugador del equipo del vendedor anterior
                    DELETE FROM public.equipo_fantasy_jugadores
                    WHERE jugador_id = r_mercado.jugador_id
                    AND equipo_fantasy_id = (
                        SELECT id FROM public.equipos_fantasy 
                        WHERE user_id = r_mercado.vendedor_id AND liga_id = p_liga_id
                    );
                END IF;

                -- 3. Añadir jugador al equipo del ganador con cláusula inicial (150% del precio de compra)
                INSERT INTO public.equipo_fantasy_jugadores (equipo_fantasy_id, jugador_id, clausula)
                VALUES (v_equipo_ganador_id, r_mercado.jugador_id, r_puja.monto * 1.5);

                -- 4. Registrar la transferencia
                INSERT INTO public.transferencias (liga_id, jugador_id, vendedor_id, comprador_id, precio)
                VALUES (p_liga_id, r_mercado.jugador_id, r_mercado.vendedor_id, r_puja.usuario_id, r_puja.monto);
            END IF;
        END IF;

        -- Eliminar del mercado (tanto si se vendió como si no)
        DELETE FROM public.mercado WHERE id = r_mercado.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Trigger para evitar comprar si se tienen 26 jugadores
CREATE OR REPLACE FUNCTION public.check_limite_plantilla()
RETURNS TRIGGER AS $$
DECLARE
    v_count INTEGER;
    v_equipo_id UUID;
    v_liga_id UUID;
BEGIN
    -- Determinar la liga_id (depende de si es puja o mercado)
    IF TG_TABLE_NAME = 'pujas' THEN
        SELECT liga_id INTO v_liga_id FROM public.mercado WHERE id = NEW.mercado_id;
    END IF;

    -- Obtener el equipo del usuario en esa liga
    SELECT id INTO v_equipo_id FROM public.equipos_fantasy 
    WHERE user_id = auth.uid() AND liga_id = v_liga_id;

    SELECT COUNT(*) INTO v_count 
    FROM public.equipo_fantasy_jugadores 
    WHERE equipo_fantasy_id = v_equipo_id;

    IF v_count >= 26 THEN
        RAISE EXCEPTION 'No puedes adquirir más jugadores. Ya tienes el máximo permitido (26).';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Aplicar el trigger a las pujas
DROP TRIGGER IF EXISTS trg_check_limite_pujas ON public.pujas;
CREATE TRIGGER trg_check_limite_pujas
BEFORE INSERT ON public.pujas
FOR EACH ROW EXECUTE FUNCTION public.check_limite_plantilla();

-- 3. Actualizar la función de clausulazo para comprobar el límite
CREATE OR REPLACE FUNCTION public.ejecutar_clausulazo(
    p_jugador_id UUID,
    p_vendedor_id UUID,
    p_comprador_id UUID,
    p_liga_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_clausula NUMERIC;
    v_presupuesto_comprador NUMERIC;
    v_equipo_vendedor_id UUID;
    v_equipo_comprador_id UUID;
    v_abierta_hasta TIMESTAMPTZ;
    v_count_jugadores INTEGER;
BEGIN
    -- 1. Obtener equipos
    SELECT id INTO v_equipo_vendedor_id FROM public.equipos_fantasy WHERE user_id = p_vendedor_id AND liga_id = p_liga_id;
    SELECT id INTO v_equipo_comprador_id FROM public.equipos_fantasy WHERE user_id = p_comprador_id AND liga_id = p_liga_id;
    
    -- 2. Validar límite de plantilla (26 jugadores)
    SELECT COUNT(*) INTO v_count_jugadores 
    FROM public.equipo_fantasy_jugadores 
    WHERE equipo_fantasy_id = v_equipo_comprador_id;

    IF v_count_jugadores >= 26 THEN
        RETURN json_build_object('error', 'No puedes adquirir más jugadores. Ya tienes el máximo permitido (26).');
    END IF;

    -- 3. Obtener datos de la cláusula
    SELECT clausula, clausula_abierta_hasta INTO v_clausula, v_abierta_hasta
    FROM public.equipo_fantasy_jugadores
    WHERE equipo_fantasy_id = v_equipo_vendedor_id AND jugador_id = p_jugador_id;

    -- 4. Otras Validaciones
    IF v_abierta_hasta IS NULL OR v_abierta_hasta < NOW() THEN
        RETURN json_build_object('error', 'La cláusula de este jugador no está abierta en este momento.');
    END IF;

    SELECT presupuesto INTO v_presupuesto_comprador FROM public.usuarios_ligas WHERE user_id = p_comprador_id AND liga_id = p_liga_id;
    IF v_presupuesto_comprador < v_clausula THEN
        RETURN json_build_object('error', 'No tienes presupuesto suficiente para el clausulazo.');
    END IF;

    -- 5. Ejecutar Transferencia
    -- Restar dinero al comprador
    UPDATE public.usuarios_ligas SET presupuesto = presupuesto - v_clausula WHERE user_id = p_comprador_id AND liga_id = p_liga_id;
    -- Sumar dinero al vendedor
    UPDATE public.usuarios_ligas SET presupuesto = presupuesto + v_clausula WHERE user_id = p_vendedor_id AND liga_id = p_liga_id;
    
    -- Cambiar dueño del jugador
    DELETE FROM public.equipo_fantasy_jugadores WHERE equipo_fantasy_id = v_equipo_vendedor_id AND jugador_id = p_jugador_id;
    INSERT INTO public.equipo_fantasy_jugadores (equipo_fantasy_id, jugador_id) VALUES (v_equipo_comprador_id, p_jugador_id);
    
    -- Registrar transferencia en el historial
    INSERT INTO public.transferencias (liga_id, jugador_id, vendedor_id, comprador_id, precio)
    VALUES (p_liga_id, p_jugador_id, p_vendedor_id, p_comprador_id, v_clausula);

    RETURN json_build_object('success', true, 'mensaje', 'Clausulazo ejecutado con éxito');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
