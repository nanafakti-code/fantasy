-- ============================================================
-- Fantasy Andalucía — Migración 026: Equipo XEREZ C.D.
-- Actualizar equipo_id de 33 jugadores de XEREZ C.D.
-- ============================================================

UPDATE public.jugadores SET equipo_id = '19aa6989-d34f-4451-9ae4-e9024db658fd'
WHERE (nombre, apellidos) IN (
  ('Andrés', 'Canto Gómez'),
  ('Daniel', 'Jiménez Robles'),
  ('Hugo', 'Costela Aragón'),
  ('Mauricio David', 'Trujillo Marín'),
  ('Parsa', 'Baghersad Renani'),
  ('Anass', 'Latif'),
  ('Ángel', 'Campos Rodríguez'),
  ('Francisco Javier', 'Cadena González'),
  ('Daniel', 'del Ojo Sánchez'),
  ('David', 'La Chica Gómez'),
  ('Diego Fernando', 'García Aliaño'),
  ('Francisco Javier', 'Guerrero García'),
  ('Iván', 'Ramos Jimenez'),
  ('Javier', 'Cauqui Barroso'),
  ('Leo', 'Marín Bredel'),
  ('Nestor', 'Gascon Parra'),
  ('Raúl', 'Segura Galán'),
  ('Samuel', 'Arriaza Guerrero'),
  ('David', 'Figueroa Díaz'),
  ('Antonio', 'Montero Barroso'),
  ('Alberto', 'Ruiz Berdejo López'),
  ('Bako', 'Traore'),
  ('Daniel', 'Sánchez del Castillo'),
  ('Manuel', 'Gálvez Román'),
  ('Germán', 'Romero Román'),
  ('Juan', 'Landa Navarro'),
  ('Julio', 'Pineda Jiménez'),
  ('Manuel Alejandro', 'Román Holgado'),
  ('Mario', 'Garcés Ordóñez'),
  ('José', 'Conde Ortínez'),
  ('Sergio', 'Arze Méndez'),
  ('Jesús', 'Soto Yuste'),
  ('Javier', 'López Buzón')
);
