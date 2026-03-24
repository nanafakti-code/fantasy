-- Migración 022: Sistema de Ofertas de la Liga y Tiempo en Mercado (48h)

-- 1. Tabla para ofertas de la liga (basadas en jugadores puestos al mercado por usuarios)
CREATE TABLE IF NOT EXISTS public.ofertas_mercado (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mercado_id UUID REFERENCES public.mercado(id) ON DELETE CASCADE,
    usuario_id UUID REFERENCES public.usuarios(id) ON DELETE CASCADE, -- Dueño del jugador
    monto NUMERIC(12, 2) NOT NULL,
    estado TEXT DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'aceptada', 'rechazada', 'expirada')),
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(mercado_id) -- Solo una oferta de la liga por jugador en mercado
);

-- 2. RLS para ofertas_mercado
ALTER TABLE public.ofertas_mercado ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Usuarios ven sus propias ofertas de mercado" ON public.ofertas_mercado;
CREATE POLICY "Usuarios ven sus propias ofertas de mercado" ON public.ofertas_mercado
    FOR SELECT USING (auth.uid() = usuario_id);

DROP POLICY IF EXISTS "Usuarios pueden actualizar sus ofertas (rechazar)" ON public.ofertas_mercado;
CREATE POLICY "Usuarios pueden actualizar sus ofertas (rechazar)" ON public.ofertas_mercado
    FOR UPDATE USING (auth.uid() = usuario_id);

-- 3. Función para generar ofertas automáticas de la liga
CREATE OR REPLACE FUNCTION public.generar_ofertas_liga_mercado(p_liga_id UUID)
RETURNS void AS $$
DECLARE
    rec RECORD;
    v_factor NUMERIC;
    v_oferta NUMERIC;
BEGIN
    -- Marcar ofertas antiguas como expiradas para esta liga
    UPDATE public.ofertas_mercado om
    SET estado = 'expirada'
    FROM public.mercado m
    WHERE om.mercado_id = m.id
    AND m.liga_id = p_liga_id
    AND om.estado = 'pendiente';

    -- Generar nuevas ofertas para los jugadores de usuarios en esa liga
    FOR rec IN 
        SELECT m.id as mercado_id, m.vendedor_id, j.precio 
        FROM public.mercado m
        JOIN public.jugadores j ON j.id = m.jugador_id
        WHERE m.liga_id = p_liga_id
        AND m.vendedor_id IS NOT NULL 
        AND m.fecha_fin > NOW()
    LOOP
        -- Factor aleatorio entre 0.92 y 1.08 (8% arriba/abajo)
        v_factor := 0.92 + (random() * 0.16);
        v_oferta := floor(rec.precio * v_factor);
        
        INSERT INTO public.ofertas_mercado (mercado_id, usuario_id, monto)
        VALUES (rec.mercado_id, rec.vendedor_id, v_oferta)
        ON CONFLICT (mercado_id) DO UPDATE 
        SET monto = EXCLUDED.monto, estado = 'pendiente', created_at = NOW();
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 4. Función para aceptar oferta de la liga
CREATE OR REPLACE FUNCTION public.aceptar_oferta_liga_mercado(p_oferta_id UUID)
RETURNS json AS $$
DECLARE
    v_oferta RECORD;
    v_mercado RECORD;
    v_equipo_id UUID;
BEGIN
    -- Obtener datos de la oferta
    SELECT * INTO v_oferta FROM public.ofertas_mercado WHERE id = p_oferta_id AND estado = 'pendiente';
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'mensaje', 'Oferta no encontrada o ya procesada.');
    END IF;

    -- Validar que sea el dueño (SECURITY DEFINER se salta RLS pero validamos el ID)
    IF v_oferta.usuario_id != auth.uid() THEN
        RETURN json_build_object('success', false, 'mensaje', 'No tienes permiso para aceptar esta oferta.');
    END IF;

    -- Obtener datos del mercado
    SELECT * INTO v_mercado FROM public.mercado WHERE id = v_oferta.mercado_id;
    
    -- Obtener equipo del usuario en esa liga
    SELECT id INTO v_equipo_id FROM public.equipos_fantasy WHERE user_id = auth.uid() AND liga_id = v_mercado.liga_id;

    -- EJECUTAR VENTA
    -- 1. Borrar jugador del equipo
    DELETE FROM public.equipo_fantasy_jugadores WHERE equipo_fantasy_id = v_equipo_id AND jugador_id = v_mercado.jugador_id;
    
    -- 2. Añadir dinero (usando rpc existente o manual)
    UPDATE public.usuarios_ligas SET presupuesto = presupuesto + v_oferta.monto 
    WHERE user_id = auth.uid() AND liga_id = v_mercado.liga_id;
    
    -- 3. Registrar transferencia
    INSERT INTO public.transferencias (liga_id, jugador_id, vendedor_id, comprador_id, precio)
    VALUES (v_mercado.liga_id, v_mercado.jugador_id, auth.uid(), NULL, v_oferta.monto);
    
    -- 4. Limpiar mercado (borra oferta por cascada)
    DELETE FROM public.mercado WHERE id = v_mercado.id;

    RETURN json_build_object('success', true, 'mensaje', 'Oferta aceptada con éxito.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Actualización de limpieza en refrescar_mercado_liga
-- Modificamos la función existente para que también limpie jugadores de usuarios caducados (48h)
CREATE OR REPLACE FUNCTION public.refrescar_mercado_liga(p_liga_id UUID)
RETURNS void AS $$
DECLARE
    v_division TEXT;
BEGIN
    -- 1. Limpiar jugadores de la LIGA (vendedor_id IS NULL)
    DELETE FROM public.mercado WHERE liga_id = p_liga_id AND vendedor_id IS NULL;

    -- 2. Limpiar jugadores de USUARIOS caducados (vendedor_id IS NOT NULL y fecha_fin < NOW)
    DELETE FROM public.mercado WHERE liga_id = p_liga_id AND vendedor_id IS NOT NULL AND fecha_fin < NOW();

    -- 3. Generar ofertas de la liga para los que quedan (opcional llamarlo aquí)
    PERFORM public.generar_ofertas_liga_mercado(p_liga_id);

    -- 4. Poner los 12 nuevos de la liga
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
$$ LANGUAGE plpgsql;
