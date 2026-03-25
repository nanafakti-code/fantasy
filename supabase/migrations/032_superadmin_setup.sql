-- ============================================================
-- Fantasy Andalucía — Migración 032: Sistema de Superadmin
-- ============================================================

-- 1. Añadir columna de rol a usuarios
ALTER TABLE public.usuarios ADD COLUMN rol VARCHAR(20) DEFAULT 'user';

-- 2. Asegurar que los admins puedan ver y editar TODO por RLS
-- (Hacemos políticas genéricas de Admin para las tablas críticas)

-- Ligas: Admin puede hacer todo
CREATE POLICY "ligas: admin total" 
ON public.ligas 
FOR ALL 
USING (EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol = 'admin'))
WITH CHECK (EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol = 'admin'));

-- Usuarios_Ligas: Admin puede gestionar membresías
CREATE POLICY "usuarios_ligas: admin total" 
ON public.usuarios_ligas 
FOR ALL 
USING (EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol = 'admin'))
WITH CHECK (EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol = 'admin'));

-- Jugadores: Admin puede editar datos técnicos
CREATE POLICY "jugadores: admin total" 
ON public.jugadores 
FOR ALL 
USING (EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol = 'admin'))
WITH CHECK (EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol = 'admin'));

-- Partidos: Admin puede gestionar calendario
CREATE POLICY "partidos: admin total" 
ON public.partidos 
FOR ALL 
USING (EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol = 'admin'))
WITH CHECK (EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol = 'admin'));

-- Estadísticas: Admin puede poner los puntos
CREATE POLICY "estadisticas: admin total" 
ON public.estadisticas_jugadores 
FOR ALL 
USING (EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol = 'admin'))
WITH CHECK (EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol = 'admin'));


-- 3. Crear función de ayuda para convertir a admin (ejecutar desde SQL Editor si se desea)
-- Usage: SELECT public.make_admin('email@example.com');
CREATE OR REPLACE FUNCTION public.make_admin(p_email TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.usuarios SET rol = 'admin' WHERE email = p_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
