-- Migración 031: Mejorar Ciclo de Ofertas de la Liga (Ofertas Diarias en cada Refresco)

-- 1. Unificar las funciones para que se ajusten al ciclo de mercado (24h)
CREATE OR REPLACE FUNCTION public.generar_ofertas_liga_mercado(p_liga_id UUID)
RETURNS void AS $$
DECLARE
    rec RECORD;
    v_factor NUMERIC;
    v_oferta NUMERIC;
BEGIN
    -- A. Marcar TODAS las ofertas pendientes de AYER (o ciclos anteriores) como expiradas
    -- Esto fuerza que en cada refresco de mercado la liga haga una oferta NUEVA
    UPDATE public.ofertas_mercado 
    SET estado = 'expirada'
    WHERE liga_id = p_liga_id 
    AND estado = 'pendiente';

    -- B. Generar nuevas ofertas para los jugadores de usuarios puestos en el mercado
    FOR rec IN 
        SELECT m.id as mercado_id, m.vendedor_id, m.jugador_id, j.precio 
        FROM public.mercado m
        JOIN public.jugadores j ON j.id = m.jugador_id
        WHERE m.liga_id = p_liga_id
        AND m.vendedor_id IS NOT NULL 
    LOOP
        -- Factor aleatorio entre 0.90 y 1.10 (+/- 10%)
        v_factor := 0.90 + (random() * 0.20);
        v_oferta := floor(rec.precio * v_factor);
        
        -- Insertar nueva oferta como PENDIENTE
        -- Como hemos expirado las anteriores, no habrá conflicto con el índice parcial de 'pendiente'
        INSERT INTO public.ofertas_mercado (mercado_id, jugador_id, liga_id, usuario_id, monto, estado)
        VALUES (rec.mercado_id, rec.jugador_id, p_liga_id, rec.vendedor_id, v_oferta, 'pendiente');
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Asegurar que refrescar_mercado_liga llama a la generación de ofertas
-- (Casi siempre ya lo hace, pero redefinimos para estar seguros de la lógica SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.refrescar_mercado_liga(p_liga_id UUID)
RETURNS void AS $$
BEGIN
    -- 1. Resolver las subastas que han acabado (compras de usuarios por jugadores de la liga)
    PERFORM public.resolver_subastas_liga(p_liga_id);

    -- 2. Limpiar jugadores de la LIGA caducados
    DELETE FROM public.mercado 
    WHERE liga_id = p_liga_id AND vendedor_id IS NULL AND fecha_fin <= NOW();

    -- 3. Limpiar jugadores de USUARIOS caducados (excedieron las 48h)
    DELETE FROM public.mercado 
    WHERE liga_id = p_liga_id AND vendedor_id IS NOT NULL AND fecha_fin < NOW();

    -- 4. Generar NUEVAS ofertas de la liga para vendedores activos (Ciclo diario cada vez que cierra el mercado)
    PERFORM public.generar_ofertas_liga_mercado(p_liga_id);

    -- 5. Poner los nuevos de la liga (12 aleatorios)
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
    LIMIT 12;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
