-- Migration 033: Add own goals and clean sheet statistics
-- Table: public.estadisticas_jugadores

-- 1. Add new columns
ALTER TABLE public.estadisticas_jugadores 
ADD COLUMN IF NOT EXISTS goles_propia INT NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS porteria_cero BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Update the points calculation function
CREATE OR REPLACE FUNCTION public.calcular_puntos_jugador()
RETURNS TRIGGER AS $$
DECLARE
  pos_jugador posicion;
  pts         NUMERIC := 0;
BEGIN
  -- Get player position
  SELECT posicion INTO pos_jugador
  FROM public.jugadores
  WHERE id = NEW.jugador_id;

  -- 1. Playing / Starting
  -- Assuming if minutos_jugados > 0, they get points (currently the UI sets titular or not)
  -- The current logic sets +2 for titular.
  IF NEW.titular THEN
    pts := pts + 2;
  END IF;

  -- 2. Scored Goals by Position
  CASE pos_jugador
    WHEN 'portero'        THEN pts := pts + (NEW.goles * 10);
    WHEN 'defensa'        THEN pts := pts + (NEW.goles * 8);
    WHEN 'centrocampista' THEN pts := pts + (NEW.goles * 6);
    WHEN 'delantero'      THEN pts := pts + (NEW.goles * 4);
  END CASE;

  -- 3. Own Goals (-2 each, regardless of position)
  pts := pts + (NEW.goles_propia * -2);

  -- 4. Clean Sheet (Portería 0)
  IF NEW.porteria_cero THEN
    CASE pos_jugador
      WHEN 'delantero'      THEN pts := pts + 1;
      WHEN 'centrocampista' THEN pts := pts + 2;
      WHEN 'defensa'        THEN pts := pts + 3;
      WHEN 'portero'        THEN pts := pts + 3;
    END CASE;
  END IF;

  -- 5. Asistencias (+3 each)
  pts := pts + (NEW.asistencias * 3);

  -- 6. Tarjetas
  -- Yellow cards: -1 each (but double yellow = -5 total)
  IF NEW.tarjetas_amarillas >= 2 THEN
    pts := pts - 5;
  ELSE
    pts := pts - (NEW.tarjetas_amarillas * 1);
  END IF;

  -- Red cards: -4 each
  pts := pts - (NEW.tarjetas_rojas * 4);

  -- Ensure points don't go below 0 (or whatever the business rule is)
  -- The original had GREATEST(pts, 0), let's keep it.
  NEW.puntos_calculados := GREATEST(pts, 0);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
