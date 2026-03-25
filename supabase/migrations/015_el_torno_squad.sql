-- ============================================================
-- Fantasy Andalucía — Migración 015: Equipo El Torno
-- Actualizar equipo_id de 35 jugadores de C.D. EL TORNO 2009
-- ============================================================

UPDATE public.jugadores SET equipo_id = '18f07e59-e214-47ca-b99c-cbf2133a0ef9'
WHERE (nombre, apellidos) IN (
  ('Adrián', 'García Carmona'),
  ('Chico', 'Martin Noble'),
  ('Pablo Antonio', 'Beltran Rojas'),
  ('Adrian', 'Cepero Lebron'),
  ('Diego', 'García Castro'),
  ('Floren', 'Roman Garcia de Veas'),
  ('Jorge', 'Sánchez Diaz'),
  ('Juanito', 'Mesa Macias'),
  ('Manolete', 'Perez Olea'),
  ('Rafa', 'González Ramírez'),
  ('Rodri', 'Rodríguez Rodríguez'),
  ('Rubén', 'Olid Vega'),
  ('Vicente', 'Fernandez Ceballos'),
  ('Yuni', 'Moreno Seda'),
  ('Antonio', 'Barroso Heredia'),
  ('Antonio', 'Medina López'),
  ('Caba', 'Cabanillas Aldón'),
  ('Javi', 'Martin Pacheco'),
  ('Juan Antonio', 'García Morón'),
  ('Juan', 'Benítez Ramos'),
  ('Poyatos', 'Poyatos Dorado'),
  ('Roque', 'Durán Lebrón'),
  ('Rubén', 'Galiano Braza'),
  ('Yoel', 'Cabanillas Aldon'),
  ('Alberto', 'Santos Postigo'),
  ('Alex', 'Fernández Vilches'),
  ('Félix', 'Ramirez Barba'),
  ('Félix', 'Salguero Infante'),
  ('Gámez', 'Gámez Reina'),
  ('Juanjo', 'Ruiz Navas'),
  ('Lamela', 'Fernández Lamela'),
  ('Morales', 'Morales Avila'),
  ('Óscar', 'Gálvez Jiménez'),
  ('Robe', 'Ruiz Lebrón'),
  ('Yeray', 'Morales García')
);
