-- Migración 020: Sistema de Clausulazos y Ofertas entre Usuarios

-- 1. Añadir campos de cláusula a la relación equipo-jugador
ALTER TABLE public.equipo_fantasy_jugadores 
ADD COLUMN IF NOT EXISTS clausula NUMERIC(14, 2),
ADD COLUMN IF NOT EXISTS clausula_abierta_hasta TIMESTAMPTZ;

-- 2. Función para inicializar cláusulas (ej: 120% del valor de mercado)
CREATE OR REPLACE FUNCTION public.calcular_clausula_inicial(p_precio NUMERIC)
RETURNS NUMERIC AS $$
BEGIN
    RETURN p_precio * 1.25; -- Cláusula por defecto: 125% del precio
END;
$$ LANGUAGE plpgsql;

-- 3. Trigger para poner cláusula al fichar un jugador
CREATE OR REPLACE FUNCTION public.fn_set_clausula_on_fichaje()
RETURNS TRIGGER AS $$
DECLARE
    v_precio_mercado NUMERIC;
BEGIN
    -- Obtener el precio actual del jugador
    SELECT precio INTO v_precio_mercado FROM public.jugadores WHERE id = NEW.jugador_id;
    
    -- Establecer la cláusula (puedes ajustarlo según tus reglas)
    NEW.clausula := public.calcular_clausula_inicial(v_precio_mercado);
    
    -- Por defecto, la cláusula está "abierta" por 14 días tras el fichaje 
    -- (o según la interpretación del usuario: la ventana de clausulazo dura 14 días)
    NEW.clausula_abierta_hasta := NOW() + INTERVAL '14 days';
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_set_clausula_on_insert
BEFORE INSERT ON public.equipo_fantasy_jugadores
FOR EACH ROW EXECUTE FUNCTION public.fn_set_clausula_on_fichaje();

-- 4. TABLA DE OFERTAS: Para las propuestas entre usuarios
CREATE TABLE IF NOT EXISTS public.ofertas_jugadores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    liga_id UUID REFERENCES public.ligas(id) ON DELETE CASCADE,
    jugador_id UUID REFERENCES public.jugadores(id) ON DELETE CASCADE,
    vendedor_id UUID REFERENCES public.usuarios(id) ON DELETE CASCADE,
    comprador_id UUID REFERENCES public.usuarios(id) ON DELETE CASCADE,
    monto NUMERIC(12, 2) NOT NULL,
    estado TEXT DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'aceptada', 'rechazada', 'expirada')),
    create_at TIMESTAMPTZ DEFAULT now()
);

-- 5. FUNCIÓN PARA EJECUTAR CLAUSULAZO (Compra instantánea por cláusula)
CREATE OR REPLACE FUNCTION public.ejecutar_clausulazo(
    p_jugador_id UUID,
    p_vendedor_id UUID,
    p_comprador_id UUID,
    p_liga_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_clausula NUMERIC;
    v_presupuesto_comprador NUMERIC;
    v_equipo_vendedor_id UUID;
    v_equipo_comprador_id UUID;
    v_abierta_hasta TIMESTAMPTZ;
BEGIN
    -- 1. Obtener equipos
    SELECT id INTO v_equipo_vendedor_id FROM public.equipos_fantasy WHERE user_id = p_vendedor_id AND liga_id = p_liga_id;
    SELECT id INTO v_equipo_comprador_id FROM public.equipos_fantasy WHERE user_id = p_comprador_id AND liga_id = p_liga_id;
    
    -- 2. Obtener datos de la cláusula
    SELECT clausula, clausula_abierta_hasta INTO v_clausula, v_abierta_hasta
    FROM public.equipo_fantasy_jugadores
    WHERE equipo_fantasy_id = v_equipo_vendedor_id AND jugador_id = p_jugador_id;

    -- 3. Validaciones
    IF v_abierta_hasta IS NULL OR v_abierta_hasta < NOW() THEN
        RETURN json_build_object('error', 'La cláusula de este jugador no está abierta en este momento.');
    END IF;

    SELECT presupuesto INTO v_presupuesto_comprador FROM public.usuarios_ligas WHERE user_id = p_comprador_id AND liga_id = p_liga_id;
    IF v_presupuesto_comprador < v_clausula THEN
        RETURN json_build_object('error', 'No tienes presupuesto suficiente para el clausulazo.');
    END IF;

    -- 4. Ejecutar Transferencia
    -- Restar dinero al comprador
    UPDATE public.usuarios_ligas SET presupuesto = presupuesto - v_clausula WHERE user_id = p_comprador_id AND liga_id = p_liga_id;
    -- Sumar dinero al vendedor
    UPDATE public.usuarios_ligas SET presupuesto = presupuesto + v_clausula WHERE user_id = p_vendedor_id AND liga_id = p_liga_id;
    
    -- Cambiar dueño del jugador
    DELETE FROM public.equipo_fantasy_jugadores WHERE equipo_fantasy_id = v_equipo_vendedor_id AND jugador_id = p_jugador_id;
    INSERT INTO public.equipo_fantasy_jugadores (equipo_fantasy_id, jugador_id) VALUES (v_equipo_comprador_id, p_jugador_id);
    
    -- Registrar transferencia en el historial
    INSERT INTO public.transferencias (liga_id, jugador_id, vendedor_id, comprador_id, precio)
    VALUES (p_liga_id, p_jugador_id, p_vendedor_id, p_comprador_id, v_clausula);

    RETURN json_build_object('success', true, 'mensaje', 'Clausulazo ejecutado con éxito');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS
ALTER TABLE public.ofertas_jugadores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ofertas: ver si eres comprador o vendedor" ON public.ofertas_jugadores
FOR SELECT USING (auth.uid() = comprador_id OR auth.uid() = vendedor_id);

CREATE POLICY "ofertas: insertar propia" ON public.ofertas_jugadores
FOR INSERT WITH CHECK (auth.uid() = comprador_id);
