-- Backfill bookings.selections with structured data aggregated from booking_* tables
-- Safe / idempotent: only updates rows where selections IS NULL or 'null'
BEGIN;

-- Ensure selections column exists before attempting backfill
ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS selections JSONB DEFAULT '{}'::jsonb;

UPDATE public.bookings b
SET selections = COALESCE(b.selections, jsonb_build_object(
  'hotels', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'booking_hotel_id', bh.id,
      'hotel_id', bh.hotel_id,
      'hotel_name', h.name,
      'nights', bh.nights,
      'price_per_night', bh.price_per_night,
      'total_price', bh.total_price
    )) FROM public.booking_hotels bh LEFT JOIN public.hotels h ON bh.hotel_id = h.id WHERE bh.booking_id = b.id
  ), '[]'::jsonb),
  'transport', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'booking_transport_id', bt.id,
      'transport_id', bt.transport_id,
      'transport_name', t.name,
      'days', bt.days,
      'price_per_day', bt.price_per_day,
      'total_price', bt.total_price
    )) FROM public.booking_transport bt LEFT JOIN public.transport_options t ON bt.transport_id = t.id WHERE bt.booking_id = b.id
  ), '[]'::jsonb),
  'guides', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'booking_guide_id', bg.id,
      'guide_id', bg.guide_id,
      'guide_name', g.name,
      'days', bg.days,
      'price_per_day', bg.price_per_day,
      'total_price', bg.total_price
    )) FROM public.booking_guides bg LEFT JOIN public.guides g ON bg.guide_id = g.id WHERE bg.booking_id = b.id
  ), '[]'::jsonb),
  'travelers', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'traveler_id', bt.id,
      'traveler_name', bt.traveler_name,
      'traveler_age', bt.traveler_age
    )) FROM public.booking_travelers bt WHERE bt.booking_id = b.id
  ), '[]'::jsonb)
))
WHERE b.selections IS NULL OR b.selections = 'null'::jsonb;

-- Keep default to empty object
ALTER TABLE public.bookings ALTER COLUMN selections SET DEFAULT '{}'::jsonb;

COMMIT;
