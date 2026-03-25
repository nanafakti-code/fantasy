-- ============================================================
-- Fantasy Andalucía — Migración 019: Equipo JEDULA C.D.
-- Actualizar equipo_id de 36 jugadores de JEDULA C.D.
-- ============================================================

UPDATE public.jugadores SET equipo_id = 'e9c8b453-3af9-4f8a-8680-fc9738ab851a'
WHERE (nombre, apellidos) IN (
  ('Álvaro', 'Mateos Pantoja'),
  ('Hugo', 'Gil García'),
  ('José', 'García López'),
  ('Juanmi', 'Casas Cote'),
  ('Manuel', 'Roldan Muñoz'),
  ('Paco', 'Pajuelo De Los Reyes'),
  ('Chato', 'Hernández Garcia'),
  ('Dani', 'Goma Rosales'),
  ('Juandi', 'Gil Carrera'),
  ('Julio', 'Benitez Orozco'),
  ('Marcos', 'Madrena Jiménez'),
  ('Miguel', 'Enríquez Barragán'),
  ('Rafa', 'Benítez Castrelo'),
  ('Rafael', 'Muñoz Cuevas'),
  ('Raúl', 'Aguilar Hierro'),
  ('Raúl', 'González Santos'),
  ('Zakaria', 'Assadi Boukhari'),
  ('Adrián', 'Galloso Martínez'),
  ('Isidoro', 'Gallego Iglesias'),
  ('Jesús', 'Rondán Archidona'),
  ('Manuel', 'Medina Ruiz'),
  ('Marcos', 'Segovia Macías'),
  ('Migue', 'Artal Pacheco'),
  ('Moy', 'Torres Amaya'),
  ('Pablo', 'Gil Cebrián'),
  ('Pablo', 'Valle Avecilla'),
  ('Alejandro', 'Pineda Cabrera'),
  ('Elio', 'Muñoz Medina'),
  ('Girón', 'Girón De La Barrera'),
  ('Hita', 'Hita Jiménez'),
  ('José', 'Barba González'),
  ('Juan', 'Olivera López'),
  ('Marcos', 'Camarena Ramírez'),
  ('Omar', 'Aguilar Mahimda'),
  ('Rivero', 'Rivero Gargallo'),
  ('Rooney', 'Ortega Aleu')
);
