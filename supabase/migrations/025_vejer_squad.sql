-- ============================================================
-- Fantasy Andalucía — Migración 025: Equipo C.D. VEJER BALOMPIE
-- Actualizar equipo_id de 31 jugadores de C.D. VEJER BALOMPIE
-- ============================================================

UPDATE public.jugadores SET equipo_id = '2513e544-7386-491b-9d0b-b48e5a7e0513'
WHERE (nombre, apellidos) IN (
  ('Ibra', 'Diouf'),
  ('Paulo', 'Espinosa Rubio'),
  ('Antonio', 'Gonzalez Lopez'),
  ('David', 'Donso'),
  ('David', 'Melero Vélez'),
  ('Domingo', 'González Orihuela'),
  ('Emilio', 'Durán Duarte'),
  ('Jose', 'Rivera Pérez'),
  ('Juan', 'Gómez Tello'),
  ('José', 'Lebrón Tejonero'),
  ('Mario', 'Moya Gallardo'),
  ('Antonio', 'Sánchez Pastor'),
  ('Said', 'Yahdih Mohamed Salem'),
  ('Jose', 'Alcedo Servan'),
  ('Álvaro', 'Miralles Morillo'),
  ('Christian', 'Vélez Sánchez'),
  ('Francisco', 'Relinque Galindo'),
  ('José', 'Martinez Bello'),
  ('Shodmekhr', 'Kurbanov'),
  ('Luis', 'Perez Peregrino'),
  ('Manuel', 'Rosales Garcés'),
  ('José', 'Melero Rodríguez'),
  ('Raúl', 'Rojas Relinque'),
  ('Manuel', 'Reyes Guerrero'),
  ('Abdou', 'Thiam Diouf'),
  ('Alejandro', 'Moreno Serván'),
  ('Antonio', 'Moreno Revuelta'),
  ('Antonio', 'Salado Zellat'),
  ('José', 'Melero Crespo'),
  ('Juan', 'Moreno Serván'),
  ('Oliver', 'Morales González')
);
