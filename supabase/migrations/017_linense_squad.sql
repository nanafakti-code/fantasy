-- ============================================================
-- Fantasy Andalucía — Migración 017: Equipo REAL BALOMPEDICA LINENSE
-- Actualizar equipo_id de 40 jugadores de REAL BALOMPEDICA LINENSE
-- ============================================================

UPDATE public.jugadores SET equipo_id = '131bc731-4c8e-4249-a341-041901d3433d'
WHERE (nombre, apellidos) IN (
  ('Álex', 'Orozco Gavilán'),
  ('Daniel', 'Quintero Millán'),
  ('Diego', 'Mercado Peinado'),
  ('Miguel Ángel', 'Álvarez Rubio'),
  ('Adri', 'Jiménez Rodríguez'),
  ('Aguilera', 'Aguilera Martín'),
  ('Alberto', 'Gómez Báez'),
  ('Álex', 'Díaz Sibajas'),
  ('Carlos', 'Del Pino Rios'),
  ('Francis', 'Pecino Alconchel'),
  ('Germán', 'Ruiz González de Canales'),
  ('Henry', 'Yepes Ayala'),
  ('Ilias', 'Nam el Hamdaoui'),
  ('Jairo', 'Piñero Muñoz'),
  ('Manu', 'Fajarne Cervera'),
  ('Moustapha', 'Seck Dione'),
  ('Raúl', 'Fajarne Cervera'),
  ('Adrián', 'Melgar Guerrero'),
  ('Anuar', 'el Amiri Sammama'),
  ('Hoyo', 'Sánchez Hoyo'),
  ('Javi', 'Doncel Benitez'),
  ('Jesús', 'Méndez Ávalo'),
  ('Jona', 'Morente Martín'),
  ('Marcos', 'Fernández Cabrera'),
  ('Portela', 'Gómez Portela'),
  ('Samu', 'Merino Cervera'),
  ('Sergio', 'Suárez Corrales'),
  ('Achkra', 'Achkra'),
  ('Álvaro', 'Ríos Sore'),
  ('Jesuli', 'Piñer Espinosa'),
  ('Joaquin', 'González Luque'),
  ('Jonathan', 'Arroyo Santiago'),
  ('José', 'Tomillero Almida'),
  ('Joselu', 'Avilés Nabo'),
  ('Leonardo', 'Blasco de Freitas'),
  ('Manuel', 'Quintero Millán'),
  ('Rubén', 'Fernández Ruiz'),
  ('Salvari', 'Arguez Oliva'),
  ('Victory', 'Gigi John')
);
