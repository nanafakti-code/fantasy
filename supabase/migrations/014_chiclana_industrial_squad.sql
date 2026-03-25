-- ============================================================
-- Fantasy Andalucía — Migración 014: Equipo Chiclana Industrial
-- Actualizar equipo_id de 32 jugadores de CHICLANA IND. C.F.
-- ============================================================

UPDATE public.jugadores SET equipo_id = 'f2ca27e7-2f45-4906-9f4b-a397632219f6'
WHERE (nombre, apellidos) IN (
  ('Adán', 'Medina Quirós'),
  ('Fran', 'Morales Bernal'),
  ('Ivan', 'Callealta Sánchez'),
  ('Borja', 'Hermida Rodrigo'),
  ('Enrique', 'Brenes Jiménez'),
  ('Fran', 'Jiménez Legupin'),
  ('Jose', 'González Pérez'),
  ('Marcos', 'Aragon Hermoso'),
  ('Raúl', 'López Arsenal'),
  ('Adri', 'Domínguez Roa'),
  ('Alba', 'Alba Vela'),
  ('Álvaro', 'Hurtado Rodríguez'),
  ('Clemente', 'Gómez Oliva'),
  ('Cristian', 'Velázquez Flores'),
  ('Esteban', 'Sánchez Marín'),
  ('Guillermo', 'Hahn Bergantiño'),
  ('Javi', 'Ortega Belizón'),
  ('Juanca', 'Velázquez Magariño'),
  ('Manuel', 'Pinto Reina'),
  ('Miguel', 'Betanzo Espada'),
  ('Ruben', 'Moreno Flores'),
  ('Álvaro', 'Moreno Aguilar'),
  ('Antonio', 'Ortiz Valverde'),
  ('Cris', 'González Betanzos'),
  ('Esteban', 'Marín Domínguez'),
  ('Jesús', 'Periñán Aragón'),
  ('Luis', 'Cebada Fernández'),
  ('Mario', 'Callealta Sánchez'),
  ('Óscar', 'Rodríguez Galvín'),
  ('Pablo', 'Rodríguez Espinosa'),
  ('Viki', 'Cabeza de Vaca Aragón'),
  ('Yaroslav', 'Pukha')
);
