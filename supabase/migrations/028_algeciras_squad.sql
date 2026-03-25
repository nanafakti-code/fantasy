-- ============================================================
-- Fantasy Andalucía — Migración 028: Equipo ALGECIRAS C.F.
-- Actualizar equipo_id de 30 jugadores de ALGECIRAS C.F.
-- ============================================================

UPDATE public.jugadores SET equipo_id = 'e22a9e91-b62c-48e3-9fd3-e4c19ff80208'
WHERE (nombre, apellidos) IN (
  ('Daniel', 'Sánchez Pérez'),
  ('Manuel', 'Mármol Martin'),
  ('Diego Alejandro', 'Angulo Sinisterra'),
  ('George Gustave', 'Pezzeca'),
  ('Hugo', 'Losada Núñez'),
  ('Jairo', 'Rubio Aguera'),
  ('Jesús', 'Heredia Lima'),
  ('Rafael', 'Arroyo Castro'),
  ('Santiago', 'Bustos Escobar'),
  ('Adrián', 'Martínez Torres'),
  ('Alejandro', 'Vega Melgar'),
  ('Álvaro', 'Ruiz Benitez'),
  ('Cristian', 'León Aguilera'),
  ('Javier', 'Benítez España'),
  ('Francisco Jorge', 'Martínez Montes'),
  ('Louay', 'Bakkali Yettefti'),
  ('Rafael', 'Febles Benítez'),
  ('Samuel', 'Espinosa Garcia'),
  ('José', 'Varela Alcaraz'),
  ('Washington', 'Rosero Loango'),
  ('Adam', 'Riani'),
  ('Alvaro', 'Aguado Delgado'),
  ('Álvaro', 'Valverde Medero'),
  ('Daniel', 'Recagno Guerrero'),
  ('Gerardo', 'Clavijo Alba'),
  ('Iván', 'Mayayo Cano'),
  ('Manuel', 'González Velasco'),
  ('Martín', 'Córdoba Mora'),
  ('Pablo', 'Velasco Jiménez'),
  ('Simón', 'Rodriguez Marenghi')
);
