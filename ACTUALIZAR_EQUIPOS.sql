-- ============================================================
-- Script de ejecución: Actualizar equipo_id de todos los jugadores
-- Ejecutar en Supabase SQL Editor para asociar jugadores con equipos
-- ============================================================

-- Migración 014: CHICLANA IND. C.F.
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

-- ============================================================
-- RESUMEN DE EJECUCIÓN:
-- ============================================================
-- Total filas actualizadas: 
SELECT COUNT(*) as "Jugadores actualizados CHICLANA IND."
FROM public.jugadores 
WHERE equipo_id = 'f2ca27e7-2f45-4906-9f4b-a397632219f6';

-- Verificar otros equipos pendientes:
SELECT 
  e.nombre as "Equipo",
  COUNT(j.id) as "Jugadores sin equipo asignado"
FROM public.equipos_reales e
LEFT JOIN public.jugadores j ON j.equipo_id = e.id
WHERE e.division = 'segunda_andaluza'
GROUP BY e.id, e.nombre
ORDER BY e.nombre;
