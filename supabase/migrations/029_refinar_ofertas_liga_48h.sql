-- Migración 029: Refinar Ofertas de la Liga y Persistencia de Ofertas Post-Mercado

-- 1. Modificar la tabla ofertas_mercado para que no dependa estrictamente de mercado_id (si el registro de mercado se borra)
ALTER TABLE public.ofertas_mercado ADD COLUMN IF NOT EXISTS jugador_id UUID REFERENCES public.jugadores(id) ON DELETE CASCADE;
ALTER TABLE public.ofertas_mercado ADD COLUMN IF NOT EXISTS liga_id UUID REFERENCES public.ligas(id) ON DELETE CASCADE;

-- Poblar datos existentes para evitar nulos
UPDATE public.ofertas_mercado om
SET jugador_id = m.jugador_id, liga_id = m.liga_id
FROM public.mercado m
WHERE om.mercado_id = m.id;

-- Hacerlos obligatorios (opcional, pero recomendado)
ALTER TABLE public.ofertas_mercado ALTER COLUMN jugador_id SET NOT NULL;
ALTER TABLE public.ofertas_mercado ALTER COLUMN liga_id SET NOT NULL;

-- 2. Eliminar el UNIQUE(mercado_id) y poner uno por jugador en esa liga para ofertas de liga
ALTER TABLE public.ofertas_mercado DROP CONSTRAINT IF EXISTS ofertas_mercado_mercado_id_key;
DROP INDEX IF EXISTS idx_ofertas_liga_jugador_liga;
CREATE UNIQUE INDEX idx_ofertas_liga_jugador_liga ON public.ofertas_mercado(jugador_id, liga_id) WHERE estado = 'pendiente';

-- 3. Actualizar función generar_ofertas_liga_mercado para usar los nuevos campos
CREATE OR REPLACE FUNCTION public.generar_ofertas_liga_mercado(p_liga_id UUID)
RETURNS void AS $$
DECLARE
    rec RECORD;
    v_factor NUMERIC;
    v_oferta NUMERIC;
BEGIN
    -- Marcar ofertas antiguas como expiradas para esta liga si el jugador ya no está en el mercado 
    -- (Opcional, podrías dejarlas 24h más según deseo del usuario)
    UPDATE public.ofertas_mercado 
    SET estado = 'expirada'
    WHERE liga_id = p_liga_id 
    AND estado = 'pendiente'
    AND created_at < NOW() - INTERVAL '24 hours';

    -- Generar nuevas ofertas para los jugadores de usuarios puestos en el mercado
    FOR rec IN 
        SELECT m.id as mercado_id, m.vendedor_id, m.jugador_id, j.precio 
        FROM public.mercado m
        JOIN public.jugadores j ON j.id = m.jugador_id
        WHERE m.liga_id = p_liga_id
        AND m.vendedor_id IS NOT NULL 
    LOOP
        -- Factor aleatorio entre 0.90 y 1.10 (10% arriba/abajo como pidió el usuario)
        v_factor := 0.90 + (random() * 0.20);
        v_oferta := floor(rec.precio * v_factor);
        
        INSERT INTO public.ofertas_mercado (mercado_id, jugador_id, liga_id, usuario_id, monto)
        VALUES (rec.mercado_id, rec.jugador_id, p_liga_id, rec.vendedor_id, v_oferta)
        ON CONFLICT (jugador_id, liga_id) WHERE estado = 'pendiente' DO UPDATE 
        SET monto = EXCLUDED.monto, created_at = NOW();
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 4. Actualizar aceptar_oferta_liga_mercado para que funcione sin mercado_id
CREATE OR REPLACE FUNCTION public.aceptar_oferta_liga_mercado(p_oferta_id UUID)
RETURNS json AS $$
DECLARE
    v_oferta RECORD;
    v_equipo_id UUID;
BEGIN
    -- Obtener datos de la oferta
    SELECT * INTO v_oferta FROM public.ofertas_mercado WHERE id = p_oferta_id AND estado = 'pendiente';
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'mensaje', 'Oferta no encontrada o ya procesada.');
    END IF;

    -- Validar que sea el dueño
    IF v_oferta.usuario_id != auth.uid() THEN
        RETURN json_build_object('success', false, 'mensaje', 'No tienes permiso para aceptar esta oferta.');
    END IF;

    -- Obtener equipo del usuario en esa liga
    SELECT id INTO v_equipo_id FROM public.equipos_fantasy WHERE user_id = auth.uid() AND liga_id = v_oferta.liga_id;

    -- EJECUTAR VENTA
    -- 1. Borrar jugador del equipo
    DELETE FROM public.equipo_fantasy_jugadores WHERE equipo_fantasy_id = v_equipo_id AND jugador_id = v_oferta.jugador_id;
    
    -- 2. Añadir dinero
    UPDATE public.usuarios_ligas SET presupuesto = presupuesto + v_oferta.monto 
    WHERE user_id = auth.uid() AND liga_id = v_oferta.liga_id;
    
    -- 3. Registrar transferencia
    INSERT INTO public.transferencias (liga_id, jugador_id, vendedor_id, comprador_id, precio)
    VALUES (v_oferta.liga_id, v_oferta.jugador_id, auth.uid(), NULL, v_oferta.monto);
    
    -- 4. Marcar oferta como aceptada
    UPDATE public.ofertas_mercado SET estado = 'aceptada' WHERE id = p_oferta_id;

    -- 5. Limpiar mercado si todavía existía el registro
    DELETE FROM public.mercado WHERE jugador_id = v_oferta.jugador_id AND liga_id = v_oferta.liga_id;

    RETURN json_build_object('success', true, 'mensaje', 'Oferta aceptada con éxito.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
