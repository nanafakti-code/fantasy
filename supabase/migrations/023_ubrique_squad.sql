-- ============================================================
-- Fantasy Andalucía — Migración 023: Equipo C.D. UBRIQUE
-- Actualizar equipo_id de 38 jugadores de C.D. UBRIQUE
-- ============================================================

UPDATE public.jugadores SET equipo_id = 'd96afce6-7f39-4222-abc5-e778836d6d17'
WHERE (nombre, apellidos) IN (
  ('Cristian', 'Cadenas Ortega'),
  ('David', 'López Núñez'),
  ('Fernando', 'Sánchez Chacón'),
  ('Melli', 'Ordoñez Capote'),
  ('Rodrigo', 'Rosado Yáñez'),
  ('Álvaro', 'Coronel Valle'),
  ('BENY', 'Benitiz Angulo'),
  ('Daniel', 'Bohorquez Gómez'),
  ('David', 'Cantos Fernández'),
  ('Francisco', 'Llucía Barragán'),
  ('Francisco', 'Gago González'),
  ('José', 'López García'),
  ('Iván', 'Sánchez Moscoso'),
  ('Josue', 'Pinilla Vargas'),
  ('Jose', 'Lamela Rodriguez'),
  ('Manuel', 'Figueroa Roman'),
  ('Manuel', 'Calvo Sevilla'),
  ('Mario', 'Chacón Rios'),
  ('Carlos', 'Mena Arce'),
  ('Juan', 'Montedeoca Fernandez'),
  ('Álvaro', 'Macías Moreno'),
  ('Aníbal', 'Rodriguez Vazquez'),
  ('Antonio', 'Coveñas Sánchez'),
  ('Arturo', 'de Oria Blanco'),
  ('Francisco', 'Ruiz Sotomayor Galvin'),
  ('Francisco', 'Fernández Rivero'),
  ('Fernando', 'Sánchez Jiménez'),
  ('Álvaro', 'Garcés Dominguez'),
  ('Francisco', 'Pérez López'),
  ('Pedro', 'Rodríguez Salguero'),
  ('Raúl', 'Flores González'),
  ('Adriano', 'Corrales Pérez'),
  ('Alejandro', 'García Miranda'),
  ('Cristian', 'Mateos Salguero'),
  ('Lucas', 'Moscoso Pérez'),
  ('Pablo', 'Vega Muñoz'),
  ('Agustín', 'Zeballos Delfino'),
  ('Ismael', 'Zeballos Delfino')
);
