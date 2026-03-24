-- Migración 021: Políticas RLS para añadir jugadores al mercado

-- 1. Permitir que los usuarios pongan sus propios jugadores a la venta
DROP POLICY IF EXISTS "Usuarios pueden poner sus jugadores en el mercado" ON public.mercado;
CREATE POLICY "Usuarios pueden poner sus jugadores en el mercado" ON public.mercado
FOR INSERT WITH CHECK (
    vendedor_id = auth.uid() AND
    EXISTS (
        SELECT 1 FROM public.equipo_fantasy_jugadores efj
        JOIN public.equipos_fantasy ef ON ef.id = efj.equipo_fantasy_id
        WHERE ef.user_id = auth.uid() 
        AND ef.liga_id = public.mercado.liga_id 
        AND efj.jugador_id = public.mercado.jugador_id
    )
);

-- 2. Permitir que los usuarios retiren sus propios jugadores del mercado
DROP POLICY IF EXISTS "Usuarios pueden retirar sus jugadores del mercado" ON public.mercado;
CREATE POLICY "Usuarios pueden retirar sus jugadores del mercado" ON public.mercado
FOR DELETE USING (vendedor_id = auth.uid());
