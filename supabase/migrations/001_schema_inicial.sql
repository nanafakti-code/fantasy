-- ============================================================
-- Fantasy Andalucía — Migración 001: Schema completo
-- Ejecutar en: Supabase → SQL Editor → New query
-- ============================================================

-- ── EXTENSIONES ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── TIPOS ENUM ───────────────────────────────────────────────
CREATE TYPE liga_estado    AS ENUM ('pendiente', 'activa', 'finalizada');
CREATE TYPE posicion       AS ENUM ('portero', 'defensa', 'centrocampista', 'delantero');
CREATE TYPE division       AS ENUM ('segunda_andaluza', 'primera_andaluza', 'division_honor');
CREATE TYPE partido_estado AS ENUM ('programado', 'en_curso', 'finalizado');

-- ── FUNCIÓN updated_at (reutilizable) ────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ════════════════════════════════════════════════════════════
-- PASO 1: CREAR TODAS LAS TABLAS
-- (sin policies todavía, para evitar referencias cruzadas)
-- ════════════════════════════════════════════════════════════

-- 1. USUARIOS
CREATE TABLE public.usuarios (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  username    VARCHAR(50)  UNIQUE NOT NULL,
  email       VARCHAR(255) UNIQUE NOT NULL,
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_usuarios_updated_at
  BEFORE UPDATE ON public.usuarios
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 2. EQUIPOS REALES
CREATE TABLE public.equipos_reales (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      VARCHAR(100) NOT NULL,
  escudo_url  TEXT,
  division    division     NOT NULL DEFAULT 'segunda_andaluza',
  ciudad      VARCHAR(100),
  activo      BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 3. JUGADORES
CREATE TABLE public.jugadores (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      VARCHAR(100) NOT NULL,
  apellidos   VARCHAR(100),
  equipo_id   UUID         REFERENCES public.equipos_reales(id) ON DELETE SET NULL,
  posicion    posicion     NOT NULL,
  dorsal      INT,
  foto_url    TEXT,
  precio      NUMERIC(12,2) NOT NULL DEFAULT 1000000,
  activo      BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_jugadores_equipo   ON public.jugadores(equipo_id);
CREATE INDEX idx_jugadores_posicion ON public.jugadores(posicion);
CREATE INDEX idx_jugadores_activo   ON public.jugadores(activo);

-- 4. LIGAS
CREATE TABLE public.ligas (
  id                   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre               VARCHAR(100)  NOT NULL,
  creador_id           UUID          REFERENCES public.usuarios(id) ON DELETE SET NULL,
  codigo_invitacion    CHAR(8)       UNIQUE NOT NULL,
  estado               liga_estado   NOT NULL DEFAULT 'pendiente',
  max_participantes    INT           NOT NULL DEFAULT 20 CHECK (max_participantes BETWEEN 2 AND 50),
  presupuesto_inicial  NUMERIC(14,2) NOT NULL DEFAULT 50000000,
  jornada_actual       INT           NOT NULL DEFAULT 1,
  division             division      NOT NULL DEFAULT 'segunda_andaluza',
  created_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ligas_codigo ON public.ligas(codigo_invitacion);
CREATE INDEX idx_ligas_estado ON public.ligas(estado);

-- 5. USUARIOS ↔ LIGAS (membresía)
CREATE TABLE public.usuarios_ligas (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID          NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  liga_id         UUID          NOT NULL REFERENCES public.ligas(id) ON DELETE CASCADE,
  puntos_totales  NUMERIC(10,2) NOT NULL DEFAULT 0,
  presupuesto     NUMERIC(14,2) NOT NULL,
  posicion        INT,
  joined_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, liga_id)
);

CREATE INDEX idx_usuarios_ligas_liga ON public.usuarios_ligas(liga_id);
CREATE INDEX idx_usuarios_ligas_user ON public.usuarios_ligas(user_id);

-- 6. EQUIPOS FANTASY
CREATE TABLE public.equipos_fantasy (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID         NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  liga_id     UUID         NOT NULL REFERENCES public.ligas(id) ON DELETE CASCADE,
  nombre      VARCHAR(100),
  formacion   VARCHAR(10)  NOT NULL DEFAULT '4-3-3',
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, liga_id)
);

CREATE INDEX idx_equipos_fantasy_liga ON public.equipos_fantasy(liga_id);
CREATE INDEX idx_equipos_fantasy_user ON public.equipos_fantasy(user_id);

-- 7. EQUIPO FANTASY ↔ JUGADORES
CREATE TABLE public.equipo_fantasy_jugadores (
  id                UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  equipo_fantasy_id UUID    NOT NULL REFERENCES public.equipos_fantasy(id) ON DELETE CASCADE,
  jugador_id        UUID    NOT NULL REFERENCES public.jugadores(id) ON DELETE CASCADE,
  es_titular        BOOLEAN NOT NULL DEFAULT FALSE,
  orden_suplente    INT     CHECK (orden_suplente BETWEEN 1 AND 4),
  fecha_fichaje     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(equipo_fantasy_id, jugador_id)
);

CREATE INDEX idx_efj_equipo  ON public.equipo_fantasy_jugadores(equipo_fantasy_id);
CREATE INDEX idx_efj_jugador ON public.equipo_fantasy_jugadores(jugador_id);

-- 8. JORNADAS
CREATE TABLE public.jornadas (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  numero      INT         NOT NULL CHECK (numero > 0),
  division    division    NOT NULL,
  fecha_ini   DATE,
  fecha_fin   DATE,
  cerrada     BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(numero, division)
);

-- 9. PARTIDOS
CREATE TABLE public.partidos (
  id               UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  jornada_id       UUID           NOT NULL REFERENCES public.jornadas(id) ON DELETE CASCADE,
  equipo_local_id  UUID           NOT NULL REFERENCES public.equipos_reales(id),
  equipo_visit_id  UUID           NOT NULL REFERENCES public.equipos_reales(id),
  goles_local      INT            NOT NULL DEFAULT 0 CHECK (goles_local >= 0),
  goles_visitante  INT            NOT NULL DEFAULT 0 CHECK (goles_visitante >= 0),
  fecha_hora       TIMESTAMPTZ,
  estado           partido_estado NOT NULL DEFAULT 'programado',
  created_at       TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  CHECK (equipo_local_id <> equipo_visit_id)
);

CREATE INDEX idx_partidos_jornada ON public.partidos(jornada_id);
CREATE INDEX idx_partidos_estado  ON public.partidos(estado);

-- 10. ESTADÍSTICAS DE JUGADORES
CREATE TABLE public.estadisticas_jugadores (
  id                   UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  jugador_id           UUID    NOT NULL REFERENCES public.jugadores(id) ON DELETE CASCADE,
  partido_id           UUID    NOT NULL REFERENCES public.partidos(id) ON DELETE CASCADE,
  titular              BOOLEAN NOT NULL DEFAULT FALSE,
  minutos_jugados      INT     NOT NULL DEFAULT 0 CHECK (minutos_jugados BETWEEN 0 AND 120),
  goles                INT     NOT NULL DEFAULT 0 CHECK (goles >= 0),
  asistencias          INT     NOT NULL DEFAULT 0 CHECK (asistencias >= 0),
  tarjetas_amarillas   INT     NOT NULL DEFAULT 0 CHECK (tarjetas_amarillas BETWEEN 0 AND 2),
  tarjetas_rojas       INT     NOT NULL DEFAULT 0 CHECK (tarjetas_rojas BETWEEN 0 AND 1),
  puntos_calculados    NUMERIC(6,2) NOT NULL DEFAULT 0,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(jugador_id, partido_id)
);

CREATE INDEX idx_stats_jugador ON public.estadisticas_jugadores(jugador_id);
CREATE INDEX idx_stats_partido ON public.estadisticas_jugadores(partido_id);

-- 11. PUNTOS POR JORNADA (caché)
CREATE TABLE public.puntos_jornada (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID          NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  liga_id         UUID          NOT NULL REFERENCES public.ligas(id) ON DELETE CASCADE,
  jornada_id      UUID          NOT NULL REFERENCES public.jornadas(id) ON DELETE CASCADE,
  puntos          NUMERIC(8,2)  NOT NULL DEFAULT 0,
  calculated_at   TIMESTAMPTZ,
  UNIQUE(user_id, liga_id, jornada_id)
);

CREATE INDEX idx_puntos_jornada_liga ON public.puntos_jornada(liga_id);
CREATE INDEX idx_puntos_jornada_user ON public.puntos_jornada(user_id);


-- ════════════════════════════════════════════════════════════
-- PASO 2: HABILITAR RLS EN TODAS LAS TABLAS
-- ════════════════════════════════════════════════════════════
ALTER TABLE public.usuarios                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipos_reales            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jugadores                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ligas                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios_ligas            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipos_fantasy           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipo_fantasy_jugadores  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jornadas                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partidos                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estadisticas_jugadores    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.puntos_jornada            ENABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════
-- PASO 3: CREAR TODAS LAS POLICIES
-- (aquí ya existen todas las tablas, sin errores de referencia)
-- ════════════════════════════════════════════════════════════

-- usuarios
CREATE POLICY "usuarios: ver propio"
  ON public.usuarios FOR SELECT USING (auth.uid() = id);

CREATE POLICY "usuarios: editar propio"
  ON public.usuarios FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "usuarios: insertar propio"
  ON public.usuarios FOR INSERT WITH CHECK (auth.uid() = id);

-- datos públicos (lectura)
CREATE POLICY "equipos_reales: lectura pública"
  ON public.equipos_reales FOR SELECT USING (true);

CREATE POLICY "jugadores: lectura pública"
  ON public.jugadores FOR SELECT USING (true);

CREATE POLICY "jornadas: lectura pública"
  ON public.jornadas FOR SELECT USING (true);

CREATE POLICY "partidos: lectura pública"
  ON public.partidos FOR SELECT USING (true);

CREATE POLICY "estadisticas: lectura pública"
  ON public.estadisticas_jugadores FOR SELECT USING (true);

-- ligas: referencia usuarios_ligas (ahora ya existe)
CREATE POLICY "ligas: ver si eres miembro"
  ON public.ligas FOR SELECT
  USING (
    id IN (
      SELECT liga_id FROM public.usuarios_ligas WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "ligas: crear si autenticado"
  ON public.ligas FOR INSERT
  WITH CHECK (auth.uid() = creador_id);

CREATE POLICY "ligas: editar si eres creador"
  ON public.ligas FOR UPDATE
  USING (auth.uid() = creador_id);

-- usuarios_ligas
CREATE POLICY "usuarios_ligas: ver compañeros de liga"
  ON public.usuarios_ligas FOR SELECT
  USING (
    liga_id IN (
      SELECT liga_id FROM public.usuarios_ligas ul2 WHERE ul2.user_id = auth.uid()
    )
  );

CREATE POLICY "usuarios_ligas: insertar propio"
  ON public.usuarios_ligas FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "usuarios_ligas: actualizar propio"
  ON public.usuarios_ligas FOR UPDATE USING (auth.uid() = user_id);

-- equipos_fantasy
CREATE POLICY "equipos_fantasy: propietario gestiona"
  ON public.equipos_fantasy FOR ALL
  USING (user_id = auth.uid());

CREATE POLICY "equipos_fantasy: ver si mismo liga"
  ON public.equipos_fantasy FOR SELECT
  USING (
    liga_id IN (
      SELECT liga_id FROM public.usuarios_ligas WHERE user_id = auth.uid()
    )
  );

-- equipo_fantasy_jugadores
CREATE POLICY "efj: propietario gestiona"
  ON public.equipo_fantasy_jugadores FOR ALL
  USING (
    equipo_fantasy_id IN (
      SELECT id FROM public.equipos_fantasy WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "efj: rivales ven alineacion"
  ON public.equipo_fantasy_jugadores FOR SELECT
  USING (
    equipo_fantasy_id IN (
      SELECT ef.id FROM public.equipos_fantasy ef
      JOIN public.usuarios_ligas ul ON ul.liga_id = ef.liga_id
      WHERE ul.user_id = auth.uid()
    )
  );

-- puntos_jornada
CREATE POLICY "puntos_jornada: ver si mismo liga"
  ON public.puntos_jornada FOR SELECT
  USING (
    liga_id IN (
      SELECT liga_id FROM public.usuarios_ligas WHERE user_id = auth.uid()
    )
  );


-- ════════════════════════════════════════════════════════════
-- PASO 4: TRIGGERS DE NEGOCIO
-- ════════════════════════════════════════════════════════════

-- Trigger: validar máximo 15 jugadores y 11 titulares por equipo
CREATE OR REPLACE FUNCTION public.check_max_jugadores()
RETURNS TRIGGER AS $$
DECLARE
  total     INT;
  titulares INT;
BEGIN
  SELECT COUNT(*) INTO total
  FROM public.equipo_fantasy_jugadores
  WHERE equipo_fantasy_id = NEW.equipo_fantasy_id;

  IF total >= 15 THEN
    RAISE EXCEPTION 'Un equipo fantasy no puede tener más de 15 jugadores';
  END IF;

  IF NEW.es_titular THEN
    SELECT COUNT(*) INTO titulares
    FROM public.equipo_fantasy_jugadores
    WHERE equipo_fantasy_id = NEW.equipo_fantasy_id AND es_titular = TRUE;

    IF titulares >= 11 THEN
      RAISE EXCEPTION 'No puedes tener más de 11 titulares';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_max_jugadores
  BEFORE INSERT ON public.equipo_fantasy_jugadores
  FOR EACH ROW EXECUTE FUNCTION public.check_max_jugadores();

-- Trigger: calcular puntos automáticamente al insertar/actualizar stats
CREATE OR REPLACE FUNCTION public.calcular_puntos_jugador()
RETURNS TRIGGER AS $$
DECLARE
  pos_jugador posicion;
  pts         NUMERIC := 0;
BEGIN
  SELECT posicion INTO pos_jugador
  FROM public.jugadores
  WHERE id = NEW.jugador_id;

  -- Titular
  IF NEW.titular THEN
    pts := pts + 2;
  END IF;

  -- Goles por posición
  CASE pos_jugador
    WHEN 'portero'        THEN pts := pts + (NEW.goles * 10);
    WHEN 'defensa'        THEN pts := pts + (NEW.goles * 8);
    WHEN 'centrocampista' THEN pts := pts + (NEW.goles * 6);
    WHEN 'delantero'      THEN pts := pts + (NEW.goles * 4);
  END CASE;

  -- Asistencias
  pts := pts + (NEW.asistencias * 3);

  -- Tarjetas (doble amarilla = -5 total: -2 ya por amarillas -3 extra)
  IF NEW.tarjetas_amarillas >= 2 THEN
    pts := pts - 5;
  ELSE
    pts := pts - (NEW.tarjetas_amarillas * 1);
  END IF;

  pts := pts - (NEW.tarjetas_rojas * 4);

  NEW.puntos_calculados := GREATEST(pts, 0);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calcular_puntos
  BEFORE INSERT OR UPDATE ON public.estadisticas_jugadores
  FOR EACH ROW EXECUTE FUNCTION public.calcular_puntos_jugador();

-- ════════════════════════════════════════════════════════════
-- PASO 5: TRIGGER de auth.users → crear perfil automáticamente
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.usuarios (id, email, username)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NEW.raw_user_meta_data->>'username',
      split_part(NEW.email, '@', 1)
    )
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
