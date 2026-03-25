-- ============================================================
-- Fantasy Andalucía — Migración 018: Equipo JUVENTUD SANLUQUEÑA A.D.
-- Actualizar equipo_id de 27 jugadores de JUVENTUD SANLUQUEÑA A.D.
-- ============================================================

UPDATE public.jugadores SET equipo_id = '2c756d8c-bb4d-4074-b633-051594024eb1'
WHERE (nombre, apellidos) IN (
  ('Alejandro', 'Cáceres Lara'),
  ('Nacho', 'Pérez Seco'),
  ('Núa', 'Senra Ibañez'),
  ('Diop', 'Diop'),
  ('Estrugo', 'Estrugo González'),
  ('Ezequiel', 'Romero Becerra'),
  ('Pablo', 'López Rodríguez'),
  ('Piti', 'González Álvarez'),
  ('Salvi', 'Pozo Monge'),
  ('Sergio', 'Castellano Carrasco'),
  ('Adam', 'Jiménez Martínez'),
  ('Alex', 'Morales Sanchez'),
  ('Camacho', 'Camacho Rivera'),
  ('Fran', 'Domínguez Cruz'),
  ('Jesús', 'Rendón Garcia'),
  ('José', 'Pérez Seco'),
  ('Moy', 'Núñez García'),
  ('Remo', 'Jiménez Rangel'),
  ('Brando', 'Jiménez Vidal'),
  ('Christian', 'Aznar Fernández'),
  ('Gálvez', 'Gálvez Rodríguez'),
  ('Josemi', 'Sánchez Cadena'),
  ('Luismi', 'Ibáñez García'),
  ('Mario', 'Mena Pipio'),
  ('Marrufo', 'Marrufo Pérez'),
  ('Oviedo', 'Oviedo Porta'),
  ('Tamayo', 'Tamayo Clavijo')
);
