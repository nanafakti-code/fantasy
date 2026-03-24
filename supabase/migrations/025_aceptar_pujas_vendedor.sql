-- Migración 025: Función para aceptar/rechazar pujas manualmente por el vendedor

CREATE OR REPLACE FUNCTION public.aceptar_puja_mercado(p_puja_id UUID)
RETURNS JSON AS $$
DECLARE
    v_puja RECORD;
    v_mercado RECORD;
    v_equipo_comprador_id UUID;
    v_equipo_vendedor_id UUID;
    v_count_jugadores INTEGER;
BEGIN
    -- 1. Obtener datos de la puja y el mercado
    SELECT * INTO v_puja FROM public.pujas WHERE id = p_puja_id;
    IF NOT FOUND THEN RETURN json_build_object('error', 'Puja no encontrada'); END IF;

    SELECT * INTO v_mercado FROM public.mercado WHERE id = v_puja.mercado_id;
    IF NOT FOUND THEN RETURN json_build_object('error', 'Item de mercado no encontrado'); END IF;

    -- 2. Validar que el que llama es el vendedor
    IF v_mercado.vendedor_id != auth.uid() THEN
        RETURN json_build_object('error', 'Solo el vendedor puede aceptar esta puja');
    END IF;

    -- 3. Obtener equipos
    SELECT id INTO v_equipo_vendedor_id FROM public.equipos_fantasy WHERE user_id = v_mercado.vendedor_id AND liga_id = v_mercado.liga_id;
    SELECT id INTO v_equipo_comprador_id FROM public.equipos_fantasy WHERE user_id = v_puja.usuario_id AND liga_id = v_mercado.liga_id;

    -- 4. Validar límite 26 jugadores del comprador
    SELECT COUNT(*) INTO v_count_jugadores FROM public.equipo_fantasy_jugadores WHERE equipo_fantasy_id = v_equipo_comprador_id;
    IF v_count_jugadores >= 26 THEN
        RETURN json_build_object('error', 'El comprador ya tiene el límite de 26 jugadores');
    END IF;

    -- 5. Validar presupuesto del comprador
    IF NOT EXISTS (
        SELECT 1 FROM public.usuarios_ligas 
        WHERE user_id = v_puja.usuario_id AND liga_id = v_mercado.liga_id AND presupuesto >= v_puja.monto
    ) THEN
        RETURN json_build_object('error', 'El comprador ya no tiene presupuesto suficiente');
    END IF;

    -- 6. EJECUTAR TRANSFERENCIA
    -- Restar al comprador
    UPDATE public.usuarios_ligas SET presupuesto = presupuesto - v_puja.monto
    WHERE user_id = v_puja.usuario_id AND liga_id = v_mercado.liga_id;
    
    -- Sumar al vendedor
    UPDATE public.usuarios_ligas SET presupuesto = presupuesto + v_puja.monto
    WHERE user_id = v_mercado.vendedor_id AND liga_id = v_mercado.liga_id;

    -- Cambiar dueño
    DELETE FROM public.equipo_fantasy_jugadores WHERE equipo_fantasy_id = v_equipo_vendedor_id AND jugador_id = v_mercado.jugador_id;
    INSERT INTO public.equipo_fantasy_jugadores (equipo_fantasy_id, jugador_id, clausula)
    VALUES (v_equipo_comprador_id, v_mercado.jugador_id, v_puja.monto * 1.5);

    -- Historial
    INSERT INTO public.transferencias (liga_id, jugador_id, vendedor_id, comprador_id, precio)
    VALUES (v_mercado.liga_id, v_mercado.jugador_id, v_mercado.vendedor_id, v_puja.usuario_id, v_puja.monto);

    -- Limpiar mercado y pujas
    DELETE FROM public.mercado WHERE id = v_mercado.id;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
