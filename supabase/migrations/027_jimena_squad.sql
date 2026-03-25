-- ============================================================
-- Fantasy Andalucía — Migración 027: Equipo JIMENA ATHLETIC CLUB C.D.
-- Actualizar equipo_id de 35 jugadores de JIMENA ATHLETIC CLUB C.D.
-- ============================================================

UPDATE public.jugadores SET equipo_id = 'ca63866d-a7c2-4a92-89a4-3c41f9d963c5'
WHERE (nombre, apellidos) IN (
  ('Alexandru', 'Ilinca Ionut'),
  ('Fernando', 'Sanchez Diaz'),
  ('Francisco Javier', 'Mateo Vera'),
  ('Abdelali', 'Mais Jouhri'),
  ('Aitor', 'Ocaña Romero'),
  ('Alejandro', 'Jimenez Reinaldo'),
  ('Christian', 'Ledesma Gil'),
  ('Diego', 'Gómez Benítez'),
  ('Francisco Javier', 'Moreno Delgado'),
  ('Nestor Nahuel', 'Gastaud'),
  ('Javier', 'Mejías García'),
  ('Lamin', 'Camara'),
  ('Luis Daniel', 'Maitan Sanoja'),
  ('Miguel', 'Navarro Cano'),
  ('Pablo', 'Zarzuela Moreno'),
  ('Zihao', 'Luo'),
  ('Adrián', 'Gómez Dominguez'),
  ('Daniel', 'Jiménez Bandera'),
  ('Domingo', 'Bueno García'),
  ('Francisco Javier', 'Vallecillo Andrades'),
  ('Francisco Javier', 'Barreno Saraiba'),
  ('Iker', 'Moreno Orellana'),
  ('Ismael', 'Ledesma Gil'),
  ('Israel Abraham', 'Barea Báez'),
  ('Itzan', 'Canto Cabello'),
  ('Jose', 'Bernal Cabeza'),
  ('Ernesto', 'Cuenca Heredia'),
  ('Eugenio', 'Cañas Morales'),
  ('Felipe', 'Marchante Santos'),
  ('Joaquin', 'Mariscal García'),
  ('Jose Francisco', 'Gomez Reinaldo'),
  ('Juan Antonio', 'Rojas Nuñez'),
  ('Rubén', 'Rojas Mejías'),
  ('Sidiki', 'Therna Mara'),
  ('Anthonie Ronald Pepijn', 'Van Der Wissel')
);
