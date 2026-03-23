-- ============================================================
-- Fantasy Andalucía — Migración 005: Funciones de Administrador
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- FUNCION: Expulsar a un usuario de la liga
-- Solo el creador de la liga puede ejecutar esta acción.
-- Borrará al usuario, su clasificación, su equipo y puntos.
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.expulsar_usuario(
  p_liga_id UUID,
  p_user_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_creador_id UUID;
BEGIN
  -- 1. Verificar quién es el creador de la liga
  SELECT creador_id INTO v_creador_id
  FROM public.ligas
  WHERE id = p_liga_id;

  -- 2. Asegurarse de que quien ejecuta es el propio creador
  IF auth.uid() != v_creador_id THEN
    RETURN json_build_object('error', 'Solo el administrador (creador) puede expulsar a otros usuarios.');
  END IF;

  -- 3. Evitar que el administrador se expulse a sí mismo por error
  IF auth.uid() = p_user_id THEN
    RETURN json_build_object('error', 'No puedes expulsarte a ti mismo. Si deseas salir, debes transferir la administración o eliminar la liga.');
  END IF;

  -- 4. Borrar membresía de la liga
  DELETE FROM public.usuarios_ligas
  WHERE liga_id = p_liga_id AND user_id = p_user_id;

  -- 5. Borrar su equipo fantasy (esto borrará también a sus jugadores fichados por la restricción CASCADE en bd)
  DELETE FROM public.equipos_fantasy
  WHERE liga_id = p_liga_id AND user_id = p_user_id;

  -- 6. Borrar su historial de puntos de jornadas pasadas en esa liga
  DELETE FROM public.puntos_jornada
  WHERE liga_id = p_liga_id AND user_id = p_user_id;

  RETURN json_build_object('success', true, 'message', 'Jugador expulsado correctamente e historial limpiado.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ════════════════════════════════════════════════════════════
-- POLÍTICAS RLS (Seguridad de Nivel de Fila)
-- Actualización para permitir salir voluntariamente (Abandonar)
-- ════════════════════════════════════════════════════════════

-- Permitir a un usuario abandonar la liga él mismo borrando su fila en usuarios_ligas
CREATE POLICY "usuarios_ligas: abandonar liga propio"
  ON public.usuarios_ligas FOR DELETE
  USING (auth.uid() = user_id);

-- Para que un usuario pueda borrar su propio equipo al abandonar
CREATE POLICY "equipos_fantasy: borrar propio"
  ON public.equipos_fantasy FOR DELETE
  USING (auth.uid() = user_id);

-- Para que un usuario pueda borrar sus puntos si abandona
CREATE POLICY "puntos_jornada: borrar propio"
  ON public.puntos_jornada FOR DELETE
  USING (auth.uid() = user_id);

