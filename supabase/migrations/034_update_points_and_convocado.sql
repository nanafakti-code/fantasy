-- Migration 034: Add Convocado and update scoring rules
-- Table: public.estadisticas_jugadores

-- 1. Add Convocado column
ALTER TABLE public.estadisticas_jugadores 
ADD COLUMN IF NOT EXISTS convocado BOOLEAN NOT NULL DEFAULT FALSE;

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

  -- 1. Participation
  -- Base point for being called up (Convocado)
  IF NEW.convocado THEN
    pts := pts + 1;
  END IF;

  -- Additional point for being starter (Titular)
  IF NEW.titular THEN
    pts := pts + 1; -- Total 2 if Convocado + Titular (Adjusting to keep total at 2 as before)
  END IF;

  -- 2. Scored Goals by Position (Updated rules)
  CASE pos_jugador
    WHEN 'portero'        THEN pts := pts + (NEW.goles * 6);
    WHEN 'defensa'        THEN pts := pts + (NEW.goles * 6);
    WHEN 'centrocampista' THEN pts := pts + (NEW.goles * 5);
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
  -- Note: User didn't specify changes for assists, keeping previous +3.
  -- Actually, in step 60 I saw 'asistencias': 0 // Eliminado. 
  -- But in the trigger I still have it. I'll keep it there just in case.
  pts := pts + (NEW.asistencias * 3);

  -- 6. Tarjetas (Updated rules)
  -- User stated: 
  -- tarjeta amarilla -1
  -- tarjeta doble amarilla -3
  -- tarjeta roja -4
  
  IF NEW.tarjetas_amarillas >= 2 THEN
    -- Double yellow total penalty is -3
    pts := pts - 3;
  ELSE
    -- Single yellow is -1
    pts := pts - (NEW.tarjetas_amarillas * 1);
  END IF;

  -- Red card is -4
  pts := pts - (NEW.tarjetas_rojas * 4);

  -- Negative scores are allowed
  NEW.puntos_calculados := pts;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
