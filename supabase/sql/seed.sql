/*******************************************************************************************
  🚀 TRAVELPLANNER — IDP (idempotent) SEED DATA SCRIPT
  Environment: SUPABASE SQL Editor / CLI
  Purpose: Populate baseline test data for validation and front-end integration
  Notes: This script is defensive: it checks for required tables and inserts only when
         missing. Run after your schema migration (`fix_schema.sql`).
*******************************************************************************************/

-- Helper: guard execution if core tables missing
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='hotels') THEN
    RAISE NOTICE 'Skipping seed: core tables not found. Run schema migration first.';
    RETURN;
  END IF;
END$$;

-- ==================================================================
-- SECTION 1: CITIES
-- ==================================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.cities WHERE name='Calangute' AND state_name='Goa') THEN
    INSERT INTO public.cities (name, state_name) VALUES ('Calangute','Goa');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cities WHERE name='Panaji' AND state_name='Goa') THEN
    INSERT INTO public.cities (name, state_name) VALUES ('Panaji','Goa');
  END IF;
END$$;


-- ==================================================================
-- SECTION 2: HOTELS + HOTEL_IMAGES
-- ==================================================================
DO $$
DECLARE
  cid_cal BIGINT;
  cid_pan BIGINT;
  hid BIGINT;
BEGIN
  SELECT id INTO cid_cal FROM public.cities WHERE name='Calangute' LIMIT 1;
  SELECT id INTO cid_pan FROM public.cities WHERE name='Panaji' LIMIT 1;

  IF NOT EXISTS (SELECT 1 FROM public.hotels WHERE name='Luxury Beach Resort') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='hotels' AND column_name='description') THEN
      INSERT INTO public.hotels (name, city_id, state, rating, price_per_night, description)
      VALUES ('Luxury Beach Resort', cid_cal, 'Goa', 4.8, 5000, 'Beachfront resort with pool') RETURNING id INTO hid;
    ELSE
      INSERT INTO public.hotels (name, city_id, state, rating, price_per_night)
      VALUES ('Luxury Beach Resort', cid_cal, 'Goa', 4.8, 5000) RETURNING id INTO hid;
    END IF;
    IF hid IS NOT NULL THEN
      IF NOT EXISTS (SELECT 1 FROM public.hotel_images WHERE hotel_id = hid AND image_url = '') THEN
        INSERT INTO public.hotel_images (hotel_id, image_url) VALUES (hid, '');
      END IF;
    END IF;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.hotels WHERE name='City Center Hotel') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='hotels' AND column_name='description') THEN
      INSERT INTO public.hotels (name, city_id, state, rating, price_per_night, description)
      VALUES ('City Center Hotel', cid_pan, 'Goa', 4.5, 3500, 'Comfortable hotel near attractions');
    ELSE
      INSERT INTO public.hotels (name, city_id, state, rating, price_per_night)
      VALUES ('City Center Hotel', cid_pan, 'Goa', 4.5, 3500);
    END IF;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.hotels WHERE name='Budget Inn') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='hotels' AND column_name='description') THEN
      INSERT INTO public.hotels (name, city_id, state, rating, price_per_night, description)
      VALUES ('Budget Inn', cid_pan, 'Goa', 4.0, 2000, 'Affordable stay with basic amenities');
    ELSE
      INSERT INTO public.hotels (name, city_id, state, rating, price_per_night)
      VALUES ('Budget Inn', cid_pan, 'Goa', 4.0, 2000);
    END IF;
  END IF;
END$$;


-- ==================================================================
-- SECTION 3: TRANSPORT OPTIONS
-- ==================================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.transport_options WHERE name='AC Sedan' AND type='Private Car') THEN
    INSERT INTO public.transport_options (type, name, price_per_day, features) VALUES ('Private Car','AC Sedan',2500,'{"comfort":"AC","capacity":4}');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.transport_options WHERE name='Tourist Cab' AND type='Shared Taxi') THEN
    INSERT INTO public.transport_options (type, name, price_per_day, features) VALUES ('Shared Taxi','Tourist Cab',1200,'{"shared":true,"capacity":6}');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.transport_options WHERE name='AC Bus' AND type='Public Bus') THEN
    INSERT INTO public.transport_options (type, name, price_per_day, features) VALUES ('Public Bus','AC Bus',500,'{"shared":true,"capacity":40}');
  END IF;
END$$;


-- ==================================================================
-- SECTION 4: GUIDES + LANGUAGES
-- ==================================================================
DO $$
DECLARE raj_id BIGINT;
DECLARE priya_id BIGINT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.guides WHERE name='Rajesh Kumar') THEN
    INSERT INTO public.guides (name, rating, price_per_day, phone_number) VALUES ('Rajesh Kumar',4.9,2000,'+91-9876543210') RETURNING id INTO raj_id;
  ELSE
    SELECT id INTO raj_id FROM public.guides WHERE name='Rajesh Kumar' LIMIT 1;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.guides WHERE name='Priya Sharma') THEN
    INSERT INTO public.guides (name, rating, price_per_day, phone_number) VALUES ('Priya Sharma',4.7,1800,'+91-9123456780') RETURNING id INTO priya_id;
  ELSE
    SELECT id INTO priya_id FROM public.guides WHERE name='Priya Sharma' LIMIT 1;
  END IF;

  IF raj_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.guide_languages WHERE guide_id = raj_id AND language = 'English') THEN
      INSERT INTO public.guide_languages (guide_id, language) VALUES (raj_id, 'English');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.guide_languages WHERE guide_id = raj_id AND language = 'Hindi') THEN
      INSERT INTO public.guide_languages (guide_id, language) VALUES (raj_id, 'Hindi');
    END IF;
  END IF;

  IF priya_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.guide_languages WHERE guide_id = priya_id AND language = 'English') THEN
      INSERT INTO public.guide_languages (guide_id, language) VALUES (priya_id, 'English');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.guide_languages WHERE guide_id = priya_id AND language = 'Hindi') THEN
      INSERT INTO public.guide_languages (guide_id, language) VALUES (priya_id, 'Hindi');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.guide_languages WHERE guide_id = priya_id AND language = 'Tamil') THEN
      INSERT INTO public.guide_languages (guide_id, language) VALUES (priya_id, 'Tamil');
    END IF;
  END IF;
END$$;


-- ==================================================================
-- SECTION 5: TRIPS
-- ==================================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.trips WHERE title = 'Seed: Weekend in Lisbon') THEN
    INSERT INTO public.trips (user_id, title, total_days, budget_per_person) VALUES (NULL, 'Seed: Weekend in Lisbon', 2, 10000);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.trips WHERE title = 'Seed: Mountain Hike') THEN
    INSERT INTO public.trips (user_id, title, total_days, budget_per_person) VALUES (NULL, 'Seed: Mountain Hike', 2, 8000);
  END IF;
END$$;


-- ==================================================================
-- SECTION 6: BOOKINGS + RELATIONS
-- ==================================================================
DO $$
DECLARE trip1 BIGINT;
DECLARE booking1 BIGINT;
DECLARE hid BIGINT;
DECLARE tid BIGINT;
DECLARE gid BIGINT;
BEGIN
  SELECT id INTO trip1 FROM public.trips WHERE title = 'Seed: Weekend in Lisbon' LIMIT 1;
  IF trip1 IS NULL THEN
    RAISE NOTICE 'No seed trip found; skipping booking seed';
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.bookings WHERE trip_id = trip1 AND total_amount = 15000) THEN
    -- Seed as 'pending' to avoid auto-confirmed demo bookings
    INSERT INTO public.bookings (trip_id, user_id, status, booked_at, total_amount) VALUES (trip1, NULL, 'pending', now(), 15000) RETURNING id INTO booking1;
  ELSE
    SELECT id INTO booking1 FROM public.bookings WHERE trip_id = trip1 AND total_amount = 15000 LIMIT 1;
  END IF;

  SELECT id INTO hid FROM public.hotels WHERE name = 'Luxury Beach Resort' LIMIT 1;
  IF hid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.booking_hotels WHERE booking_id = booking1 AND hotel_id = hid) THEN
    INSERT INTO public.booking_hotels (booking_id, hotel_id, nights, price_per_night, total_price) VALUES (booking1, hid, 2, 5000, 10000);
  END IF;

  SELECT id INTO tid FROM public.transport_options WHERE name = 'AC Sedan' LIMIT 1;
  IF tid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.booking_transport WHERE booking_id = booking1 AND transport_id = tid) THEN
    INSERT INTO public.booking_transport (booking_id, transport_id, days, price_per_day, total_price) VALUES (booking1, tid, 2, 2500, 5000);
  END IF;

  SELECT id INTO gid FROM public.guides WHERE name = 'Rajesh Kumar' LIMIT 1;
  IF gid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.booking_guides WHERE booking_id = booking1 AND guide_id = gid) THEN
    INSERT INTO public.booking_guides (booking_id, guide_id, days, price_per_day, total_price) VALUES (booking1, gid, 2, 2000, 4000);
  END IF;
END$$;


-- ==================================================================
-- END OF SEED SCRIPT
-- ==================================================================
-- Notes: sequences may need a setval reset after running this script (see verify_and_debug.sql)

