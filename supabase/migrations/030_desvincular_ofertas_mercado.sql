-- Migración 030: Desvincular Ofertas de la Liga del Borrado de Mercado

-- 1. Eliminar la restricción de CASCADE para que la oferta sobreviva al borrado del registro de mercado al expirar
ALTER TABLE public.ofertas_mercado DROP CONSTRAINT IF EXISTS ofertas_mercado_mercado_id_fkey;

-- 2. Volver a añadir la foreign key pero sin CASCADE (o simplemente dejarla como UUID informativo)
-- La dejaremos solo como referencia opcional ya que tenemos jugador_id y liga_id para la lógica principal.
ALTER TABLE public.ofertas_mercado 
    ADD CONSTRAINT ofertas_mercado_mercado_id_fkey 
    FOREIGN KEY (mercado_id) REFERENCES public.mercado(id) ON DELETE SET NULL;

-- 3. Asegurar que las ofertas "pendientes" no se marquen como expiradas inmediatamente al borrar el mercado
-- (Ya hemos añadido jugador_id y liga_id en la migración 029)

-- 4. Permitir que el usuario vea la oferta incluso si mercado_id ya no existe
-- Esto ya debería funcionar con la lógica de 029.

-- 5. Ajuste en generar_ofertas_liga_mercado para que las ofertas duren lo suficiente
CREATE OR REPLACE FUNCTION public.generar_ofertas_liga_mercado(p_liga_id UUID)
RETURNS void AS $$
DECLARE
    rec RECORD;
    v_factor NUMERIC;
    v_oferta NUMERIC;
BEGIN
    -- Marcar ofertas antiguas como expiradas SOLO si han pasado 48h desde su creación
    -- Esto permite que si el mercado acaba a las 48h, la última oferta generada (ej: a las 40h) siga viva 24h más
    UPDATE public.ofertas_mercado 
    SET estado = 'expirada'
    WHERE liga_id = p_liga_id 
    AND estado = 'pendiente'
    AND created_at < NOW() - INTERVAL '48 hours';

    -- Generar nuevas ofertas para los jugadores de usuarios puestos en el mercado
    FOR rec IN 
        SELECT m.id as mercado_id, m.vendedor_id, m.jugador_id, j.precio 
        FROM public.mercado m
        JOIN public.jugadores j ON j.id = m.jugador_id
        WHERE m.liga_id = p_liga_id
        AND m.vendedor_id IS NOT NULL 
    LOOP
        -- Factor aleatorio entre 0.90 y 1.10
        v_factor := 0.90 + (random() * 0.20);
        v_oferta := floor(rec.precio * v_factor);
        
        -- Insertar nueva oferta. Si ya hay una de hoy (pendiente), la actualizamos.
        -- Si la anterior fue rechazada, esta nueva entra como pendiente.
        INSERT INTO public.ofertas_mercado (mercado_id, jugador_id, liga_id, usuario_id, monto, estado)
        VALUES (rec.mercado_id, rec.jugador_id, p_liga_id, rec.vendedor_id, v_oferta, 'pendiente')
        ON CONFLICT (jugador_id, liga_id) WHERE estado = 'pendiente' DO UPDATE 
        SET monto = EXCLUDED.monto, created_at = NOW();
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
