-- ============================================================
-- Fantasy Andalucía — Migración 016: Equipo C.D. SAN ROQUE
-- Actualizar equipo_id de 38 jugadores de C.D. SAN ROQUE
-- ============================================================

UPDATE public.jugadores SET equipo_id = 'a80664d3-1515-42c3-8b2a-619b401d1f5d'
WHERE (nombre, apellidos) IN (
  ('Alex', 'García Fernández'),
  ('David', 'Jiménez Polanco'),
  ('Fran', 'Rodríguez Bellido'),
  ('Rubén', 'Román Fernández'),
  ('Víctor', 'Ayala Orrillo'),
  ('Álex', 'Benítez Martín'),
  ('Banderas', 'Banderas Murillo'),
  ('Chechu', 'Calvo Ferrer'),
  ('Dani', 'Martín Delgado'),
  ('Fran', 'Díaz Malia'),
  ('José Augusto', 'Casanova Turrillo'),
  ('Miranda', 'Miranda Llaveta'),
  ('Moto', 'López Ferrer'),
  ('Rubén Alconchel', 'Alconchel Oliva'),
  ('Toledo', 'Fernández Toledo'),
  ('Adrián', 'Furné Gutiérrez'),
  ('Alejandro', 'Ferra Lara'),
  ('Álex', 'García Carrillo'),
  ('Álex', 'González Buendía'),
  ('Andrés', 'Sánchez Sereno'),
  ('Carlos', 'Ruiz Corbacho'),
  ('Isma', 'Furne Gutiérrez'),
  ('Jaime', 'Rodriguez Navas'),
  ('Luis', 'De la Luz Pelayo Hoyos'),
  ('Miguel', 'Ortiz Merino'),
  ('Otero', 'Otero Domínguez'),
  ('Tamarit', 'Tamarit García'),
  ('Zalayeta', 'Zalayeta'),
  ('Abel', 'Ruiz Cervan'),
  ('Abraham', 'Lobo López'),
  ('Álex', 'García Sanjorge'),
  ('Ezequiel', 'Estigarribia Velázquez'),
  ('Juanma', 'Ocaña Ruiz'),
  ('Kevin', 'Peñalosa Ruíz'),
  ('Ledesma', 'Ledesma Carrillo'),
  ('Niko', 'Pereira Pina'),
  ('Pino', 'Pino Rivas'),
  ('Sergio', 'Palma García')
);
