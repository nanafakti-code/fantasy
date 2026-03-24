    -- Migración 027: Fix Security y Lógica de Refresco de Mercado

    -- 1. Marcar funciones de refresco como SECURITY DEFINER para saltar RLS al generar jugadores de sistema
    ALTER FUNCTION public.refrescar_mercado_liga(UUID) SECURITY DEFINER;
    ALTER FUNCTION public.generar_ofertas_liga_mercado(UUID) SECURITY DEFINER;

    -- 2. Asegurar que las ofertas de la liga se generen correctamente incluso si hubo rechazos previos
    -- (Ya está en la lógica de ON CONFLICT de generar_ofertas_liga_mercado, pero reforzamos la permisos)

    -- 3. Permitir a los usuarios ver las ofertas que la LIGA les hace por sus jugadores
    DROP POLICY IF EXISTS "Usuarios ven sus propias ofertas de mercado" ON public.ofertas_mercado;
    CREATE POLICY "Usuarios ven sus propias ofertas de mercado" ON public.ofertas_mercado
        FOR SELECT USING (auth.uid() = usuario_id);

    -- 4. Permitir actualizar a 'rechazada'
    DROP POLICY IF EXISTS "Usuarios pueden rechazar ofertas liga" ON public.ofertas_mercado;
    CREATE POLICY "Usuarios pueden rechazar ofertas liga" ON public.ofertas_mercado
        FOR UPDATE USING (auth.uid() = usuario_id);
