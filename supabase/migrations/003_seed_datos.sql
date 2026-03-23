-- ============================================================
-- Fantasy Andalucía — Migración 003: Datos de prueba (seed)
-- Solo para desarrollo/testing. NO ejecutar en producción.
-- ============================================================

-- ── Equipos reales de 2ª Andaluza (Sevilla) ─────────────────
INSERT INTO public.equipos_reales (id, nombre, division, ciudad) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Montequinto FC',         'segunda_andaluza', 'Dos Hermanas'),
  ('00000000-0000-0000-0000-000000000002', 'Los Palacios CF',        'segunda_andaluza', 'Los Palacios'),
  ('00000000-0000-0000-0000-000000000003', 'Alcalá de Guadaíra SD', 'segunda_andaluza', 'Alcalá de Guadaíra'),
  ('00000000-0000-0000-0000-000000000004', 'Utrera CD',              'segunda_andaluza', 'Utrera'),
  ('00000000-0000-0000-0000-000000000005', 'Morón CF',               'segunda_andaluza', 'Morón de la Frontera'),
  ('00000000-0000-0000-0000-000000000006', 'Lebrija CF',             'segunda_andaluza', 'Lebrija'),
  ('00000000-0000-0000-0000-000000000007', 'Coria del Río CD',       'segunda_andaluza', 'Coria del Río'),
  ('00000000-0000-0000-0000-000000000008', 'Arahal CD',              'segunda_andaluza', 'Arahal')
ON CONFLICT (id) DO NOTHING;

-- ── Jornadas 1–10 (2ª Andaluza) ─────────────────────────────
INSERT INTO public.jornadas (numero, division, fecha_ini, fecha_fin, cerrada) VALUES
  (1,  'segunda_andaluza', '2025-09-06', '2025-09-07', TRUE),
  (2,  'segunda_andaluza', '2025-09-13', '2025-09-14', TRUE),
  (3,  'segunda_andaluza', '2025-09-20', '2025-09-21', TRUE),
  (4,  'segunda_andaluza', '2025-09-27', '2025-09-28', TRUE),
  (5,  'segunda_andaluza', '2025-10-04', '2025-10-05', TRUE),
  (6,  'segunda_andaluza', '2025-10-11', '2025-10-12', TRUE),
  (7,  'segunda_andaluza', '2025-10-18', '2025-10-19', TRUE),
  (8,  'segunda_andaluza', '2025-10-25', '2025-10-26', FALSE),
  (9,  'segunda_andaluza', '2025-11-01', '2025-11-02', FALSE),
  (10, 'segunda_andaluza', '2025-11-08', '2025-11-09', FALSE)
ON CONFLICT (numero, division) DO NOTHING;

-- ── Jugadores de ejemplo ─────────────────────────────────────
INSERT INTO public.jugadores (id, nombre, apellidos, equipo_id, posicion, dorsal, precio) VALUES
  -- Montequinto FC
  ('10000000-0000-0000-0000-000000000001', 'Jorge',   'Martínez Vega',    '00000000-0000-0000-0000-000000000001', 'portero',        1,  800000),
  ('10000000-0000-0000-0000-000000000002', 'Rubén',   'Mora Sánchez',     '00000000-0000-0000-0000-000000000001', 'defensa',        4,  600000),
  ('10000000-0000-0000-0000-000000000003', 'Antonio', 'García Heredia',   '00000000-0000-0000-0000-000000000001', 'defensa',        5,  550000),
  ('10000000-0000-0000-0000-000000000004', 'Luis',    'Vega Castillo',    '00000000-0000-0000-0000-000000000001', 'centrocampista', 8,  900000),
  ('10000000-0000-0000-0000-000000000005', 'Iñaki',   'Gómez Barrera',    '00000000-0000-0000-0000-000000000001', 'delantero',      9,  1500000),
  ('10000000-0000-0000-0000-000000000006', 'Nacho',   'Bellido Torres',   '00000000-0000-0000-0000-000000000001', 'delantero',      11, 1200000),
  -- Los Palacios CF
  ('10000000-0000-0000-0000-000000000007', 'Paco',    'López Jiménez',    '00000000-0000-0000-0000-000000000002', 'portero',        1,  750000),
  ('10000000-0000-0000-0000-000000000008', 'Manuel',  'Heredia Ruiz',     '00000000-0000-0000-0000-000000000002', 'defensa',        3,  580000),
  ('10000000-0000-0000-0000-000000000009', 'José',    'Soria Pérez',      '00000000-0000-0000-0000-000000000002', 'centrocampista', 10, 850000),
  ('10000000-0000-0000-0000-000000000010', 'Carlos',  'Ruiz Molina',      '00000000-0000-0000-0000-000000000002', 'centrocampista', 7,  700000),
  ('10000000-0000-0000-0000-000000000011', 'Fran',    'Fuentes Domínguez','00000000-0000-0000-0000-000000000002', 'delantero',      11, 1100000),
  -- Alcalá de Guadaíra
  ('10000000-0000-0000-0000-000000000012', 'Pablo',   'García Nieto',     '00000000-0000-0000-0000-000000000003', 'portero',        13, 700000),
  ('10000000-0000-0000-0000-000000000013', 'Sergio',  'Romero Cano',      '00000000-0000-0000-0000-000000000003', 'defensa',        6,  620000),
  ('10000000-0000-0000-0000-000000000014', 'David',   'Navarro Blanco',   '00000000-0000-0000-0000-000000000003', 'centrocampista', 8,  780000),
  ('10000000-0000-0000-0000-000000000015', 'Alejandro','Díaz Roca',       '00000000-0000-0000-0000-000000000003', 'delantero',      9,  1300000),
  -- Utrera CD
  ('10000000-0000-0000-0000-000000000016', 'Tomás',   'Fernández Gil',    '00000000-0000-0000-0000-000000000004', 'portero',        1,  720000),
  ('10000000-0000-0000-0000-000000000017', 'Raúl',    'Prieto Leal',      '00000000-0000-0000-0000-000000000004', 'defensa',        2,  560000),
  ('10000000-0000-0000-0000-000000000018', 'Óscar',   'Moreno Santana',   '00000000-0000-0000-0000-000000000004', 'centrocampista', 6,  830000),
  ('10000000-0000-0000-0000-000000000019', 'Álvaro',  'Cano Espinosa',    '00000000-0000-0000-0000-000000000004', 'delantero',      10, 1400000),
  ('10000000-0000-0000-0000-000000000020', 'Miguel',  'Torres Aguilar',   '00000000-0000-0000-0000-000000000004', 'delantero',      7,  950000)
ON CONFLICT (id) DO NOTHING;

-- ── Partidos de jornada 8 (en curso) ─────────────────────────
WITH j8 AS (
  SELECT id FROM public.jornadas WHERE numero = 8 AND division = 'segunda_andaluza'
)
INSERT INTO public.partidos (jornada_id, equipo_local_id, equipo_visit_id, fecha_hora, estado)
SELECT
  j8.id,
  unnest(ARRAY[
    '00000000-0000-0000-0000-000000000001'::UUID,
    '00000000-0000-0000-0000-000000000003'::UUID,
    '00000000-0000-0000-0000-000000000005'::UUID,
    '00000000-0000-0000-0000-000000000007'::UUID
  ]) AS local,
  unnest(ARRAY[
    '00000000-0000-0000-0000-000000000002'::UUID,
    '00000000-0000-0000-0000-000000000004'::UUID,
    '00000000-0000-0000-0000-000000000006'::UUID,
    '00000000-0000-0000-0000-000000000008'::UUID
  ]) AS visitante,
  '2025-10-26 11:00:00+01'::TIMESTAMPTZ,
  'programado'::partido_estado
FROM j8
ON CONFLICT DO NOTHING;
