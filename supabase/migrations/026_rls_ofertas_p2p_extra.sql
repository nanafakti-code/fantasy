-- Migración 026: RLS para gestión de ofertas P2P (UPDATE y DELETE)

-- 1. Permitir a los compradores borrar (cancelar) sus propias ofertas pendientes
DROP POLICY IF EXISTS "ofertas: borrar propia" ON public.ofertas_jugadores;
CREATE POLICY "ofertas: borrar propia" ON public.ofertas_jugadores
    FOR DELETE USING (auth.uid() = comprador_id AND estado = 'pendiente');

-- 2. Permitir a los vendedores actualizar el estado (aceptar/rechazar)
DROP POLICY IF EXISTS "ofertas: actualizar estado vendedor" ON public.ofertas_jugadores;
CREATE POLICY "ofertas: actualizar estado vendedor" ON public.ofertas_jugadores
    FOR UPDATE USING (auth.uid() = vendedor_id);

-- 3. Función RPC para aceptar oferta P2P (para encapsular lógica de transferencia)
CREATE OR REPLACE FUNCTION public.aceptar_oferta_p2p(p_oferta_id UUID)
RETURNS json AS $$
DECLARE
    v_oferta RECORD;
    v_presupuesto_comprador NUMERIC;
    v_equipo_vendedor_id UUID;
    v_equipo_comprador_id UUID;
BEGIN
    -- 1. Obtener la oferta
    SELECT * INTO v_oferta FROM public.ofertas_jugadores WHERE id = p_oferta_id AND estado = 'pendiente';
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'mensaje', 'Oferta no encontrada o ya procesada.');
    END IF;

    -- Validar que el que llama es el vendedor
    IF v_oferta.vendedor_id != auth.uid() THEN
        RETURN json_build_object('success', false, 'mensaje', 'No tienes permiso para aceptar esta oferta.');
    END IF;

    -- 2. Validar presupuesto del comprador
    SELECT presupuesto INTO v_presupuesto_comprador 
    FROM public.usuarios_ligas 
    WHERE user_id = v_oferta.comprador_id AND liga_id = v_oferta.liga_id;
    
    IF v_presupuesto_comprador < v_oferta.monto THEN
        RETURN json_build_object('success', false, 'mensaje', 'El comprador ya no tiene presupuesto suficiente.');
    END IF;

    -- 3. Obtener equipos fantasy IDs
    SELECT id INTO v_equipo_vendedor_id FROM public.equipos_fantasy WHERE user_id = v_oferta.vendedor_id AND liga_id = v_oferta.liga_id;
    SELECT id INTO v_equipo_comprador_id FROM public.equipos_fantasy WHERE user_id = v_oferta.comprador_id AND liga_id = v_oferta.liga_id;

    -- 4. EJECUTAR TRANSFERENCIA
    -- Restar al comprador
    UPDATE public.usuarios_ligas SET presupuesto = presupuesto - v_oferta.monto 
    WHERE user_id = v_oferta.comprador_id AND liga_id = v_oferta.liga_id;
    
    -- Sumar al vendedor
    UPDATE public.usuarios_ligas SET presupuesto = presupuesto + v_oferta.monto 
    WHERE user_id = v_oferta.vendedor_id AND liga_id = v_oferta.liga_id;

    -- Mover jugador
    DELETE FROM public.equipo_fantasy_jugadores WHERE equipo_fantasy_id = v_equipo_vendedor_id AND jugador_id = v_oferta.jugador_id;
    INSERT INTO public.equipo_fantasy_jugadores (equipo_fantasy_id, jugador_id) 
    VALUES (v_equipo_comprador_id, v_oferta.jugador_id);

    -- Registrar en historial
    INSERT INTO public.transferencias (liga_id, jugador_id, vendedor_id, comprador_id, precio)
    VALUES (v_oferta.liga_id, v_oferta.jugador_id, v_oferta.vendedor_id, v_oferta.comprador_id, v_oferta.monto);

    -- Marcar oferta como aceptada
    UPDATE public.ofertas_jugadores SET estado = 'aceptada' WHERE id = p_oferta_id;
    
    -- Opcional: Rechazar automáticamente otras ofertas por el mismo jugador en esta liga
    UPDATE public.ofertas_jugadores 
    SET estado = 'rechazada' 
    WHERE jugador_id = v_oferta.jugador_id 
    AND liga_id = v_oferta.liga_id 
    AND id != p_oferta_id 
    AND estado = 'pendiente';

    RETURN json_build_object('success', true, 'mensaje', 'Transferencia P2P completada con éxito.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
