-- ============================================================
-- Fantasy Andalucía — Migración 020: Equipo OLVERA C.D.
-- Actualizar equipo_id de 31 jugadores de OLVERA C.D.
-- ============================================================

UPDATE public.jugadores SET equipo_id = '1f1a189f-3f5d-4527-875f-cc14b408189b'
WHERE (nombre, apellidos) IN (
  ('Francisco', 'Ortega Castro'),
  ('Germán', 'Bocanegra Albarrán'),
  ('Rubén', 'Periáñez Sacie'),
  ('Zarzu', 'Zarzuela Bocanegra'),
  ('Antonio', 'Escalante Escalante'),
  ('Dani', 'Burgos Calderón'),
  ('Galindo', 'Rubiales Galindo'),
  ('Hugo', 'Villalba Toledo'),
  ('Iván', 'Mulero Escalona'),
  ('MACA', 'Jiménez Saborido'),
  ('Mario', 'Pérez Márquez'),
  ('Melchor', 'Pérez Mulero'),
  ('Álvaro', 'Troya Periáñez'),
  ('Ángel', 'Porras Gutiérrez'),
  ('Caico', 'Casanueva Gómez'),
  ('Diego', 'Cabrera Mesa'),
  ('Pablo', 'Gómez Cabeza'),
  ('Paradas', 'Paradas Perez'),
  ('Ricardo', 'Cabrera Jiménez'),
  ('Trilli', 'Perez Barrera'),
  ('Alex', 'Bocanegra Párraga'),
  ('Alfonso', 'Perez Caravaca'),
  ('Álvaro', 'Zambrana Gómez'),
  ('Anas', 'El Fkih Mira'),
  ('Charli', 'Pérez Jiménez'),
  ('Morales', 'Morales Cabeza'),
  ('Óscar', 'Márquez Zamudio'),
  ('Rubén', 'Jiménez Carreño'),
  ('Rubén', 'Mancio Paradas'),
  ('Samuel', 'Cabeza Menacho'),
  ('Xesco', 'Bocanegra Párraga')
);
