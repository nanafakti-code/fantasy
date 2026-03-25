-- ============================================================
-- Fantasy Andalucía — Migración 029: Equipo A.D. NUEVA JARILLA
-- Actualizar equipo_id de 22 jugadores de A.D. NUEVA JARILLA
-- ============================================================

UPDATE public.jugadores SET equipo_id = '1cc6683d-952c-40db-83e1-caf6f938894b'
WHERE (nombre, apellidos) IN (
  ('Alejandro', 'Martínez Rosado'),
  ('Juan Jose', 'Peña Mateos'),
  ('Pablo', 'Abuín Casado'),
  ('Adahy', 'Jiménez Sánchez'),
  ('Alejandro', 'Perez Calvo De La Rosa'),
  ('Antonio', 'Cebrian Sanchez'),
  ('Francisco Javier', 'Conde Nieves'),
  ('Gabriel', 'Becerra Garcia'),
  ('Angel', 'Gallero Prat'),
  ('Ismael', 'Gonzalez Grimaldi'),
  ('Juan', 'Laynez García'),
  ('Sergio', 'Montalvo Vega'),
  ('Alejandro', 'Bautista Gil'),
  ('Alejandro', 'Castillo Garrido'),
  ('Cristian', 'Fernandez Lopez'),
  ('Ezequiel', 'Acuña Reguera'),
  ('Isaac', 'Garrido Fernandez'),
  ('Alejandro', 'Montalvo Vega'),
  ('Sergio', 'Puche Campuzano'),
  ('Adrian', 'Escalera Caballero'),
  ('Manuel', 'Gutierrez Heredia'),
  ('Juan Luis', 'Fernández Pérez')
);
