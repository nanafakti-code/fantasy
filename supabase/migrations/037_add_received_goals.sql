-- Migration 037 (Updated): Change Recibió goals to incremental counter
-- Table: public.estadisticas_jugadores

-- 1. Remove boolean column if exists, and add integer column
ALTER TABLE public.estadisticas_jugadores DROP COLUMN IF EXISTS recibio_2_goles;
ALTER TABLE public.estadisticas_jugadores ADD COLUMN IF NOT EXISTS goles_recibidos INTEGER NOT NULL DEFAULT 0;

-- 2. Update the points calculation function
CREATE OR REPLACE FUNCTION public.calcular_puntos_jugador()
RETURNS TRIGGER AS $$
DECLARE
  pos_jugador posicion;
  pts         NUMERIC := 0;
  factor      INTEGER := 0;
BEGIN
  -- Get player position
  SELECT posicion INTO pos_jugador
  FROM public.jugadores
  WHERE id = NEW.jugador_id;

  -- 1. Participation
  -- Base point for being called up (Convocado)
  IF NEW.convocado THEN
    pts := pts + 1;
  END IF;

  -- Additional points for being starter (Titular)
  IF NEW.titular THEN
    pts := pts + 2; -- Total 3 if Convocado + Titular
  END IF;

  -- 2. Scored Goals by Position
  CASE pos_jugador
    WHEN 'portero'        THEN pts := pts + (NEW.goles * 6);
    WHEN 'defensa'        THEN pts := pts + (NEW.goles * 6);
    WHEN 'centrocampista' THEN pts := pts + (NEW.goles * 5);
    WHEN 'delantero'      THEN pts := pts + (NEW.goles * 4);
    ELSE NULL;
  END CASE;

  -- 3. Own Goals (-2 each)
  pts := pts + (NEW.goles_propia * -2);

  -- 4. Clean Sheet (Portería 0)
  IF NEW.porteria_cero THEN
    CASE pos_jugador
      WHEN 'delantero'      THEN pts := pts + 1;
      WHEN 'centrocampista' THEN pts := pts + 2;
      WHEN 'defensa'        THEN pts := pts + 3;
      WHEN 'portero'        THEN pts := pts + 3;
      ELSE NULL;
    END CASE;
  END IF;

  -- 5. Received Goals Penalty (Incremental: per every 2 goals)
  -- 2 goles recibidos -> -1 delanteros y centrocampistas, -2 defensas y porteros.
  -- Usamos factor = goles_recibidos / 2 (división entera)
  factor := NEW.goles_recibidos / 2;
  
  IF factor > 0 THEN
    CASE pos_jugador
      WHEN 'portero'        THEN pts := pts - (factor * 2);
      WHEN 'defensa'        THEN pts := pts - (factor * 2);
      WHEN 'centrocampista' THEN pts := pts - (factor * 1);
      WHEN 'delantero'      THEN pts := pts - (factor * 1);
      ELSE NULL;
    END CASE;
  END IF;

  -- 6. Asistencias (+3 each)
  pts := pts + (NEW.asistencias * 3);

  -- 7. Tarjetas
  IF NEW.tarjetas_amarillas >= 2 THEN
    pts := pts - 3;
  ELSE
    pts := pts - (NEW.tarjetas_amarillas * 1);
  END IF;

  pts := pts - (NEW.tarjetas_rojas * 4);

  -- Apply points
  NEW.puntos_calculados := pts;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
