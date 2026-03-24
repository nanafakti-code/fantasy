-- Migración 028: Resolución de Subastas Automáticas de la Liga

-- 1. Función para resolver subastas de jugadores de la LIGA (vendedor_id IS NULL)
CREATE OR REPLACE FUNCTION public.resolver_subastas_liga(p_liga_id UUID)
RETURNS void AS $$
DECLARE
    v_mercado_id UUID;
    v_jugador_id UUID;
    v_vencedor RECORD;
    v_equipo_fantasia_id UUID;
BEGIN
    -- Iterar por los jugadores de la LIGA (vendedor_id IS NULL) que han expirado
    FOR v_mercado_id, v_jugador_id IN 
        SELECT id, jugador_id FROM public.mercado 
        WHERE liga_id = p_liga_id AND vendedor_id IS NULL AND fecha_fin <= NOW()
    LOOP
        -- Buscar la mejor puja para este mercado_id
        -- Prioridad: 1. Mayor monto, 2. Fecha más antigua (quien punjo antes)
        SELECT * INTO v_vencedor 
        FROM public.pujas 
        WHERE mercado_id = v_mercado_id
        ORDER BY monto DESC, fecha ASC
        LIMIT 1;

        IF FOUND THEN
            -- Obtener equipo fantasy del vencedor
            SELECT id INTO v_equipo_fantasia_id 
            FROM public.equipos_fantasy 
            WHERE user_id = v_vencedor.usuario_id AND liga_id = p_liga_id;

            -- 1. Validar presupuesto de nuevo (por si acaso bajó en el ínterim)
            IF EXISTS (SELECT 1 FROM public.usuarios_ligas WHERE user_id = v_vencedor.usuario_id AND liga_id = p_liga_id AND presupuesto >= v_vencedor.monto) THEN
                
                -- EJECUTAR FICHAJE
                -- A. Restar dinero
                UPDATE public.usuarios_ligas 
                SET presupuesto = presupuesto - v_vencedor.monto 
                WHERE user_id = v_vencedor.usuario_id AND liga_id = p_liga_id;

                -- B. Añadir jugador al equipo
                INSERT INTO public.equipo_fantasy_jugadores (equipo_fantasy_id, jugador_id)
                VALUES (v_equipo_fantasia_id, v_jugador_id);

                -- C. Registrar transferencia
                INSERT INTO public.transferencias (liga_id, jugador_id, vendedor_id, comprador_id, precio)
                VALUES (p_liga_id, v_jugador_id, NULL, v_vencedor.usuario_id, v_vencedor.monto);

            END IF;
        END IF;

        -- Borrar pujas de este mercado (tanto si hubo ganador como si no)
        DELETE FROM public.pujas WHERE mercado_id = v_mercado_id;
        
        -- El registro de mercado se borrará en la función refrescar_mercado_liga
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Actualizar refrescar_mercado_liga para que llame a resolver_subastas_liga
CREATE OR REPLACE FUNCTION public.refrescar_mercado_liga(p_liga_id UUID)
RETURNS void AS $$
DECLARE
    v_limit INT := 12;
BEGIN
    -- 1. Resolver las subastas que han acabado
    PERFORM public.resolver_subastas_liga(p_liga_id);

    -- 2. Limpiar jugadores de la LIGA caducados (ya procesados por resolver_subastas_liga)
    DELETE FROM public.mercado WHERE liga_id = p_liga_id AND vendedor_id IS NULL AND fecha_fin <= NOW();

    -- 3. Limpiar jugadores de USUARIOS caducados
    DELETE FROM public.mercado WHERE liga_id = p_liga_id AND vendedor_id IS NOT NULL AND fecha_fin < NOW();

    -- 4. Generar nuevas ofertas de la liga para vendedores activos
    PERFORM public.generar_ofertas_liga_mercado(p_liga_id);

    -- 5. Poner los nuevos de la liga (hasta completar 12 o lo que se desee)
    -- Contamos cuántos de la liga quedan activos
    INSERT INTO public.mercado (liga_id, jugador_id, precio_minimo, fecha_fin)
    SELECT 
        p_liga_id, 
        j.id, 
        j.precio, 
        NOW() + INTERVAL '24 hours'
    FROM public.jugadores j
    WHERE NOT EXISTS (
        SELECT 1 FROM public.equipo_fantasy_jugadores efj 
        JOIN public.equipos_fantasy ef ON ef.id = efj.equipo_fantasy_id 
        WHERE efj.jugador_id = j.id AND ef.liga_id = p_liga_id
    )
    AND NOT EXISTS (
        SELECT 1 FROM public.mercado m WHERE m.jugador_id = j.id AND m.liga_id = p_liga_id
    )
    ORDER BY random()
    -- Solo rellenar si es necesario (ej: limit 12 total o simplemente 12 nuevos)
    LIMIT v_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
