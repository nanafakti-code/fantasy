-- ============================================================
-- Fantasy Andalucía — Migración 021: Equipo CHIPIONA C.F.
-- Actualizar equipo_id de 32 jugadores de CHIPIONA C.F.
-- ============================================================

UPDATE public.jugadores SET equipo_id = '386ef181-4ec5-4079-aa9a-35597f473aba'
WHERE (nombre, apellidos) IN (
  ('Andres', 'Gomez Parra'),
  ('Cabeza', 'Cabeza García'),
  ('Dani', 'Montalban Montiel'),
  ('Manu', 'Rodríguez Porta'),
  ('Martínez', 'Martínez Vidal'),
  ('Nico', 'Fernández Bustinduy'),
  ('Blanco', 'Blanco Valdés'),
  ('Chote', 'Peña Carpio'),
  ('Dani', 'Pérez Porras'),
  ('Dani', 'Rodríguez Ruiz'),
  ('Dani', 'Garcia Vazquez'),
  ('Iván', 'Caballero Lucena'),
  ('Jesús', 'Del Moral Porras'),
  ('Miranda', 'Miranda Pérez de la Lastra'),
  ('Rivaldo', 'Alconchel Margarida'),
  ('TROYI', 'PÉREZ TROYANO'),
  ('Abraham', 'López Lorenzo'),
  ('Borja', 'Peinado Verano'),
  ('David', 'Tirado Bernal'),
  ('José', 'García Leal'),
  ('Joud', 'Joud López'),
  ('Juanma', 'Benitez Quiros'),
  ('Leandro', 'Jiménez Acaso'),
  ('Sergio', 'Solís Castaño'),
  ('David', 'Lorenzo Santos'),
  ('Eze', 'Martín Rúa'),
  ('Florido', 'Florido Caro'),
  ('Migue', 'González Pajarón'),
  ('Petaca', 'Grilo Ruiz'),
  ('Ricky', 'Cos Acuña'),
  ('Samu', 'Naval Castaño'),
  ('Simón', 'Perales Ramos')
);
