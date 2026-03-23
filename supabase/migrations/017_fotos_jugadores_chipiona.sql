-- Actualizar fotos de los jugadores del Chipiona C.F.
UPDATE public.jugadores
SET foto_url = 'https://res.cloudinary.com/dvdqltemk/image/upload/v1774290913/jugador-futbol-simple-icono-negro-aislado-sobre-fondo-blanco_98402-68338_usdanm.png'
WHERE equipo_id IN (
    SELECT id FROM public.equipos_reales 
    WHERE nombre = 'CHIPIONA C.F.'
);
