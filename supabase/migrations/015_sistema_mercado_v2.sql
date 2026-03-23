-- Migración 015: Sistema de Mercado Avanzado
-- Implementa pujas, mercado diario y transferencias

-- 1. MERCADO: Jugadores disponibles para compra/puja
CREATE TABLE IF NOT EXISTS public.mercado (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    liga_id UUID REFERENCES public.ligas(id) ON DELETE CASCADE,
    jugador_id UUID REFERENCES public.jugadores(id) ON DELETE CASCADE,
    vendedor_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL, -- NULL si es la liga
    precio_minimo NUMERIC(12, 2) NOT NULL,
    fecha_fin TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. PUJAS: Ofertas de usuarios por jugadores en el mercado
CREATE TABLE IF NOT EXISTS public.pujas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mercado_id UUID REFERENCES public.mercado(id) ON DELETE CASCADE,
    usuario_id UUID REFERENCES public.usuarios(id) ON DELETE CASCADE,
    monto NUMERIC(12, 2) NOT NULL,
    fecha TIMESTAMPTZ DEFAULT now()
);

-- 3. HISTORIAL_TRANSFERENCIAS: Registro histórico de compras y ventas
CREATE TABLE IF NOT EXISTS public.transferencias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    liga_id UUID REFERENCES public.ligas(id) ON DELETE CASCADE,
    jugador_id UUID REFERENCES public.jugadores(id) ON DELETE CASCADE,
    vendedor_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL, -- NULL si fue la liga
    comprador_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    precio NUMERIC(12, 2) NOT NULL,
    fecha TIMESTAMPTZ DEFAULT now()
);

-- 4. FUNCIÓN PARA REFRESCAR EL MERCADO DE UNA LIGA
-- Limpia los jugadores de la liga y pone 12 nuevos aleatorios
CREATE OR REPLACE FUNCTION public.refrescar_mercado_liga(p_liga_id UUID)
RETURNS VOID AS $$
DECLARE
    v_division TEXT;
BEGIN
    -- Obtener la división de la liga
    SELECT division INTO v_division FROM public.ligas WHERE id = p_liga_id;

    -- Eliminar jugadores puestos por la "liga" (vendedor_id es NULL)
    DELETE FROM public.mercado 
    WHERE liga_id = p_liga_id 
    AND vendedor_id IS NULL;

    -- Insertar 12 jugadores aleatorios que:
    -- 1. No pertenezcan a ningún usuario en esta liga
    -- 2. No estén ya en el mercado puestos por usuarios
    -- 3. [Opcional] Sean de equipos reales de la categoría (si se quisiera filtrar)
    INSERT INTO public.mercado (liga_id, jugador_id, precio_minimo, fecha_fin)
    SELECT 
        p_liga_id, 
        j.id, 
        j.precio, 
        (CURRENT_DATE + 1) + (SELECT created_at::time FROM public.ligas WHERE id = p_liga_id)
    FROM public.jugadores j
    WHERE j.id NOT IN (
        -- Jugadores que ya tienen dueño en esta liga
        SELECT efj.jugador_id 
        FROM public.equipo_fantasy_jugadores efj
        JOIN public.equipos_fantasy ef ON efj.equipo_fantasy_id = ef.id
        WHERE ef.liga_id = p_liga_id
    )
    AND j.id NOT IN (
        -- Jugadores que ya están en el mercado puestos por usuarios
        SELECT jugador_id FROM public.mercado WHERE liga_id = p_liga_id
    )
    ORDER BY random()
    LIMIT 12;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. FUNCIÓN PARA TRANSFERIR ADMIN
CREATE OR REPLACE FUNCTION public.transferir_admin(p_liga_id UUID, p_nuevo_admin_id UUID)
RETURNS VOID AS $$
BEGIN
    -- Verificar que el que llama es el creador actual
    IF NOT EXISTS (
        SELECT 1 FROM public.ligas 
        WHERE id = p_liga_id AND creador_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Solo el administrador actual puede transferir el mando.';
    END IF;

    -- Actualizar el creador
    UPDATE public.ligas 
    SET creador_id = p_nuevo_admin_id 
    WHERE id = p_liga_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. SEGURIDAD RLS
ALTER TABLE public.mercado ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pujas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transferencias ENABLE ROW LEVEL SECURITY;

-- Políticas básicas (lectura para todos los de la liga, escritura restringida)
DROP POLICY IF EXISTS "Usuarios pueden ver el mercado de sus ligas" ON public.mercado;
CREATE POLICY "Usuarios pueden ver el mercado de sus ligas" ON public.mercado
    FOR SELECT USING (
        liga_id IN (SELECT liga_id FROM public.usuarios_ligas WHERE user_id = auth.uid())
    );

DROP POLICY IF EXISTS "Usuarios pueden ver sus propias pujas" ON public.pujas;
CREATE POLICY "Usuarios pueden ver sus propias pujas" ON public.pujas
    FOR SELECT USING (
        usuario_id = auth.uid() OR 
        mercado_id IN (SELECT id FROM public.mercado WHERE vendedor_id = auth.uid())
    );

DROP POLICY IF EXISTS "Usuarios pueden ver el historial de sus ligas" ON public.transferencias;
CREATE POLICY "Usuarios pueden ver el historial de sus ligas" ON public.transferencias
    FOR SELECT USING (
        liga_id IN (SELECT liga_id FROM public.usuarios_ligas WHERE user_id = auth.uid())
    );
