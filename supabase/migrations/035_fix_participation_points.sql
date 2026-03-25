-- Migration 035: Fix participation points
-- Convocado: +1, Titular: +2 (Total 3 if both)

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

  -- Additional points for being starter (Titular)
  IF NEW.titular THEN
    pts := pts + 2; 
  END IF;

  -- 2. Scored Goals by Position
  CASE pos_jugador
    WHEN 'portero'        THEN pts := pts + (NEW.goles * 6);
    WHEN 'defensa'        THEN pts := pts + (NEW.goles * 6);
    WHEN 'centrocampista' THEN pts := pts + (NEW.goles * 5);
    WHEN 'delantero'      THEN pts := pts + (NEW.goles * 4);
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
    END CASE;
  END IF;

  -- 5. Asistencias (+3 each)
  pts := pts + (NEW.asistencias * 3);

  -- 6. Tarjetas
  IF NEW.tarjetas_amarillas >= 2 THEN
    pts := pts - 3;
  ELSE
    pts := pts - (NEW.tarjetas_amarillas * 1);
  END IF;

  pts := pts - (NEW.tarjetas_rojas * 4);

  -- Save calculated points
  NEW.puntos_calculados := pts;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
