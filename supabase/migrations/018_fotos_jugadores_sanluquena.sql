-- Actualizar fotos de los jugadores de la Juventud Sanluqueña A.D.
UPDATE public.jugadores
SET foto_url = 'https://res.cloudinary.com/dvdqltemk/image/upload/v1774291521/Gemini_Generated_Image_o7o7nfo7o7nfo7o7_hweel0.png'
WHERE equipo_id IN (
    SELECT id FROM public.equipos_reales 
    WHERE nombre = 'JUVENTUD SANLUQUEÑA A.D.'
);
