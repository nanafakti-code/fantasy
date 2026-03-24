-- Migración 023: Políticas RLS para la tabla de pujas
-- Permite que los usuarios gestionen sus propias ofertas en el mercado

-- 1. Permitir que los usuarios inserten sus propias pujas si están en la liga
DROP POLICY IF EXISTS "Usuarios pueden pujar en el mercado de sus ligas" ON public.pujas;
CREATE POLICY "Usuarios pueden pujar en el mercado de sus ligas" ON public.pujas
FOR INSERT WITH CHECK (
    usuario_id = auth.uid() AND
    mercado_id IN (
        SELECT m.id FROM public.mercado m
        JOIN public.usuarios_ligas ul ON ul.liga_id = m.liga_id
        WHERE ul.user_id = auth.uid()
    )
);

-- 2. Permitir que los usuarios vean sus propias pujas (ya existía pero la reforzamos)
DROP POLICY IF EXISTS "Usuarios pueden ver sus propias pujas" ON public.pujas;
CREATE POLICY "Usuarios pueden ver sus propias pujas" ON public.pujas
FOR SELECT USING (
    usuario_id = auth.uid() OR 
    mercado_id IN (SELECT id FROM public.mercado WHERE vendedor_id = auth.uid())
);

-- 3. Permitir que los usuarios actualicen sus propias pujas
DROP POLICY IF EXISTS "Usuarios pueden modificar sus propias pujas" ON public.pujas;
CREATE POLICY "Usuarios pueden modificar sus propias pujas" ON public.pujas
FOR UPDATE USING (usuario_id = auth.uid());

-- 4. Permitir que los usuarios borren sus propias pujas
DROP POLICY IF EXISTS "Usuarios pueden borrar sus propias pujas" ON public.pujas;
CREATE POLICY "Usuarios pueden borrar sus propias pujas" ON public.pujas
FOR DELETE USING (usuario_id = auth.uid());
