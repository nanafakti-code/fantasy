-- ============================================================
-- Fantasy Andalucía — Migración 024: Equipo GRUPO EMPRESA BAZAN
-- Actualizar equipo_id de 37 jugadores de GRUPO EMPRESA BAZAN
-- ============================================================

UPDATE public.jugadores SET equipo_id = '503aa32d-bd45-458d-bec0-9e31aa21cecf'
WHERE (nombre, apellidos) IN (
  ('Asier', 'Carrera Medina'),
  ('Daniel', 'García Baena'),
  ('Ignacio', 'Carles López'),
  ('Joaquin', 'Garcés Nieto'),
  ('Marco', 'Pipio Berea'),
  ('Ruben', 'Braza Jimenez'),
  ('Ruben', 'Braza Braza Jimenez'),
  ('Jesús', 'Aguirre García'),
  ('Camilo', 'Babilonia Navarro'),
  ('Brian', 'Herreros Fabra'),
  ('David', 'Pinedo Núñez'),
  ('Javier', 'Suárez Pimentel'),
  ('Jesús', 'Gutiérrez Gómez'),
  ('Manuel', 'Cornejo Amaya'),
  ('Jesús', 'Ochoa Barriga'),
  ('Raúl', 'Chapela López'),
  ('Raúl', 'Alias Callejón'),
  ('Samuel', 'Sarmiento Cruz'),
  ('Victor', 'León Camacho'),
  ('Adrián', 'Blanco Bozo'),
  ('Alejandro', 'Guerrero Sevillano'),
  ('Hugo', 'Ávila Marín'),
  ('Hugo', 'De la Flor Rodríguez'),
  ('Isaac', 'Rodriguez Rivero'),
  ('Javier', 'Girón Freire'),
  ('Francisco', 'Romero Pinedo'),
  ('Mario', 'Jiménez Palomino'),
  ('Matías', 'Respeto Solano'),
  ('Mauro', 'Pastor Gutiérrez'),
  ('Miguel', 'Garrido Castro'),
  ('Alberto', 'de Celis Costilla'),
  ('Alejandro', 'Collantes López'),
  ('Juan', 'Conejero Benítez'),
  ('Kevin', 'Lamela Garrido'),
  ('Miguel', 'de Alba Gallego'),
  ('Miguel', 'Pacheco Rodriguez'),
  ('Roberto', 'Viciana Rodríguez')
);
