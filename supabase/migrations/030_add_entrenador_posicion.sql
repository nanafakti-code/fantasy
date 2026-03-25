-- Alter posicion enum to include 'entrenador'
-- This allows storing coaches in the jugadores table with posicion = 'entrenador'

ALTER TYPE posicion ADD VALUE 'entrenador' BEFORE 'portero';

-- Add comment for clarity
COMMENT ON TYPE posicion IS 'Posiciones en el fútbol: entrenador, portero, defensa, centrocampista, delantero';
