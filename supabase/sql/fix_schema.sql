BEGIN;

-- ====================================================================
-- SECTION 1: CORE SCHEMA (cleaned + normalized)
-- ====================================================================

CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT auth.uid(),
  full_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  trip_count INTEGER NOT NULL DEFAULT 0,
  booking_count INTEGER NOT NULL DEFAULT 0
);

-- CITIES
CREATE TABLE IF NOT EXISTS public.cities (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  state_name TEXT,
  country TEXT DEFAULT 'India',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (name, state_name)
);

-- Compatibility: ensure both `name` and `city_name` columns exist and are populated so
-- downstream migrations and seeds that reference either variant won't fail with NOT NULL
DO $$
BEGIN
  -- add missing columns if needed
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='name') THEN
    ALTER TABLE public.cities ADD COLUMN name TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='city_name') THEN
    ALTER TABLE public.cities ADD COLUMN city_name TEXT;
  END IF;

  -- copy values between the two variants when present
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='city_name') THEN
    UPDATE public.cities SET city_name = COALESCE(city_name, name) WHERE name IS NOT NULL OR city_name IS NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='name') THEN
    UPDATE public.cities SET name = COALESCE(name, city_name) WHERE city_name IS NOT NULL OR name IS NULL;
  END IF;

  -- ensure no NULLs remain (use empty string for safety)
  UPDATE public.cities SET name = '' WHERE name IS NULL;
  UPDATE public.cities SET city_name = '' WHERE city_name IS NULL;

  -- set a harmless default on city_name so INSERTs that omit it won't create NULLs
  BEGIN
    -- only set default if column exists
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='city_name') THEN
      ALTER TABLE public.cities ALTER COLUMN city_name SET DEFAULT '';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- non-fatal: ignore if we cannot alter default (permissions etc.)
    RAISE NOTICE 'Could not set default on public.cities.city_name: %', SQLERRM;
  END;
END$$;

-- TRIPS
CREATE TABLE IF NOT EXISTS public.trips (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  start_date DATE,
  end_date DATE,
  budget_per_person NUMERIC(10,2),
  total_days INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- legacy array preserved for migration compatibility
  cities TEXT[],
  -- search_vector for full-text search
  search_vector TSVECTOR
);

-- TRIP_CITIES
CREATE TABLE IF NOT EXISTS public.trip_cities (
  id BIGSERIAL PRIMARY KEY,
  trip_id BIGINT NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  city_id BIGINT NOT NULL REFERENCES public.cities(id) ON DELETE RESTRICT,
  day_number INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (trip_id, city_id)
);

-- ITINERARIES
CREATE TABLE IF NOT EXISTS public.itineraries (
  id BIGSERIAL PRIMARY KEY,
  trip_id BIGINT NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  day_number INT NOT NULL,
  activity TEXT NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (trip_id, day_number)
);

-- HOTELS
CREATE TABLE IF NOT EXISTS public.hotels (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  city_id BIGINT REFERENCES public.cities(id) ON DELETE SET NULL,
  state TEXT,
  rating NUMERIC(2,1),
  price_per_night NUMERIC(10,2),
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hotels_city_id ON public.hotels (city_id);

-- HOTEL IMAGES
CREATE TABLE IF NOT EXISTS public.hotel_images (
  id BIGSERIAL PRIMARY KEY,
  hotel_id BIGINT NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- TRANSPORT OPTIONS
CREATE TABLE IF NOT EXISTS public.transport_options (
  id BIGSERIAL PRIMARY KEY,
  type TEXT NOT NULL,
  name TEXT NOT NULL,
  price_per_day NUMERIC(10,2),
  features JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- GUIDES
CREATE TABLE IF NOT EXISTS public.guides (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  rating NUMERIC(2,1),
  price_per_day NUMERIC(10,2),
  phone_number TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_guides_name ON public.guides (name);

-- GUIDE LANGUAGES
CREATE TABLE IF NOT EXISTS public.guide_languages (
  id BIGSERIAL PRIMARY KEY,
  guide_id BIGINT NOT NULL REFERENCES public.guides(id) ON DELETE CASCADE,
  language TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (guide_id, language)
);

-- BOOKINGS
CREATE TABLE IF NOT EXISTS public.bookings (
  id BIGSERIAL PRIMARY KEY,
  trip_id BIGINT REFERENCES public.trips(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  -- selections: JSON blob persisted from the frontend (which stores chosen hotels/transport/guides)
  selections JSONB,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','confirmed','cancelled')),
  booked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  total_amount NUMERIC(12,2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_bookings_trip ON public.bookings (trip_id);
CREATE INDEX IF NOT EXISTS idx_bookings_user ON public.bookings (user_id);

-- BOOKING RELATIONS
CREATE TABLE IF NOT EXISTS public.booking_travelers (
  id BIGSERIAL PRIMARY KEY,
  booking_id BIGINT NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  traveler_name TEXT,
  traveler_age INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.booking_hotels (
  id BIGSERIAL PRIMARY KEY,
  booking_id BIGINT NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  hotel_id BIGINT REFERENCES public.hotels(id) ON DELETE SET NULL,
  nights INT DEFAULT 1,
  price_per_night NUMERIC(10,2),
  total_price NUMERIC(12,2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.booking_transport (
  id BIGSERIAL PRIMARY KEY,
  booking_id BIGINT NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  transport_id BIGINT REFERENCES public.transport_options(id) ON DELETE SET NULL,
  days INT DEFAULT 1,
  price_per_day NUMERIC(10,2),
  total_price NUMERIC(12,2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.booking_guides (
  id BIGSERIAL PRIMARY KEY,
  booking_id BIGINT NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  guide_id BIGINT REFERENCES public.guides(id) ON DELETE SET NULL,
  days INT DEFAULT 1,
  price_per_day NUMERIC(10,2),
  total_price NUMERIC(12,2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ====================================================================
-- SECTION 2: AUDIT LOGS + AUDIT FUNCTION (omitted previously, now restored)
-- ====================================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id BIGSERIAL PRIMARY KEY,
  table_name TEXT NOT NULL,
  operation TEXT NOT NULL,
  record_id TEXT,
  performed_by UUID,
  payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.fn_audit_log() RETURNS TRIGGER AS $$
DECLARE
  user_id UUID;
BEGIN
  BEGIN
    user_id := current_setting('request.jwt.claim.sub')::uuid;
  EXCEPTION WHEN OTHERS THEN
    user_id := NULL;
  END;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.audit_logs(table_name, operation, record_id, performed_by, payload, created_at)
    VALUES (TG_TABLE_NAME, TG_OP, NEW.id::text, user_id, row_to_json(NEW)::jsonb, now());
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.audit_logs(table_name, operation, record_id, performed_by, payload, created_at)
    VALUES (TG_TABLE_NAME, TG_OP, NEW.id::text, user_id,
            jsonb_build_object('old', row_to_json(OLD), 'new', row_to_json(NEW)), now());
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.audit_logs(table_name, operation, record_id, performed_by, payload, created_at)
    VALUES (TG_TABLE_NAME, TG_OP, OLD.id::text, user_id, row_to_json(OLD)::jsonb, now());
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ====================================================================
-- SECTION 3: COUNTER FUNCTIONS (trip_count, booking_count)
-- ====================================================================

CREATE OR REPLACE FUNCTION public.fn_update_user_trip_count() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.user_id IS NOT NULL THEN
      UPDATE public.users SET trip_count = COALESCE(trip_count,0) + 1 WHERE id = NEW.user_id;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.user_id IS NOT NULL THEN
      UPDATE public.users SET trip_count = GREATEST(COALESCE(trip_count,0) - 1, 0) WHERE id = OLD.user_id;
    END IF;
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.user_id IS DISTINCT FROM NEW.user_id THEN
      IF OLD.user_id IS NOT NULL THEN
        UPDATE public.users SET trip_count = GREATEST(COALESCE(trip_count,0) - 1, 0) WHERE id = OLD.user_id;
      END IF;
      IF NEW.user_id IS NOT NULL THEN
        UPDATE public.users SET trip_count = COALESCE(trip_count,0) + 1 WHERE id = NEW.user_id;
      END IF;
    END IF;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.fn_update_user_booking_count() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.user_id IS NOT NULL THEN
      UPDATE public.users SET booking_count = COALESCE(booking_count,0) + 1 WHERE id = NEW.user_id;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.user_id IS NOT NULL THEN
      UPDATE public.users SET booking_count = GREATEST(COALESCE(booking_count,0) - 1, 0) WHERE id = OLD.user_id;
    END IF;
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.user_id IS DISTINCT FROM NEW.user_id THEN
      IF OLD.user_id IS NOT NULL THEN
        UPDATE public.users SET booking_count = GREATEST(COALESCE(booking_count,0) - 1, 0) WHERE id = OLD.user_id;
      END IF;
      IF NEW.user_id IS NOT NULL THEN
        UPDATE public.users SET booking_count = COALESCE(booking_count,0) + 1 WHERE id = NEW.user_id;
      END IF;
    END IF;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ====================================================================
-- SECTION 4: SEARCH VECTOR (function, trigger, index, and backfill)
-- ====================================================================

CREATE OR REPLACE FUNCTION public.fn_update_trip_search_vector() RETURNS TRIGGER AS $$
BEGIN
  -- Build a safe tsvector from available trip fields. We avoid referencing columns
  -- that may not exist across different schema versions (e.g. description). Use
  -- title plus the cities array as a fallback searchable corpus.
  NEW.search_vector := to_tsvector('english',
    COALESCE(NEW.title,'') || ' ' || COALESCE(array_to_string(NEW.cities, ' '), ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger (before insert/update)
DROP TRIGGER IF EXISTS trg_trip_search_vector ON public.trips;
CREATE TRIGGER trg_trip_search_vector
BEFORE INSERT OR UPDATE ON public.trips
FOR EACH ROW
EXECUTE FUNCTION public.fn_update_trip_search_vector();

-- GIN index
CREATE INDEX IF NOT EXISTS idx_trips_search_vector ON public.trips USING gin (search_vector);

-- Backfill search_vector (safe: use description if present, otherwise fall back to title + cities)
ALTER TABLE IF EXISTS public.trips DISABLE TRIGGER USER;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'description'
  ) THEN
    UPDATE public.trips
    SET search_vector = to_tsvector('english', coalesce(title,'') || ' ' || coalesce(description,''))
    WHERE search_vector IS NULL;
  ELSE
    UPDATE public.trips
    SET search_vector = to_tsvector('english', coalesce(title,'') || ' ' || coalesce(array_to_string(cities, ' '), ''))
    WHERE search_vector IS NULL;
  END IF;
END$$;
ALTER TABLE IF EXISTS public.trips ENABLE TRIGGER USER;

-- ====================================================================
-- SECTION 5: PREVENT OVERLAP (prevent overlapping trips per user)
-- ====================================================================

CREATE OR REPLACE FUNCTION public.fn_prevent_overlapping_trips() RETURNS TRIGGER AS $$
DECLARE
  conflicts INT;
BEGIN
  IF NEW.user_id IS NULL OR NEW.start_date IS NULL OR NEW.end_date IS NULL THEN
    RETURN NEW; -- can't validate
  END IF;

  SELECT COUNT(*) INTO conflicts
  FROM public.trips
  WHERE user_id = NEW.user_id
    AND id <> COALESCE(NEW.id, -1)
    AND (COALESCE(start_date, 'infinity') <= COALESCE(NEW.end_date, '-infinity'))
    AND (COALESCE(end_date, '-infinity') >= COALESCE(NEW.start_date, 'infinity'));

  IF conflicts > 0 THEN
    RAISE EXCEPTION 'Overlapping trip exists for this user';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_prevent_overlap ON public.trips;
CREATE TRIGGER trg_prevent_overlap
BEFORE INSERT OR UPDATE ON public.trips
FOR EACH ROW
EXECUTE FUNCTION public.fn_prevent_overlapping_trips();

-- ====================================================================
-- SECTION 6: UPDATED_AT helper (minimal) — kept from cleaned version
-- ====================================================================

CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_updated_at_users ON public.users;
CREATE TRIGGER trg_set_updated_at_users
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at_trips ON public.trips;
CREATE TRIGGER trg_set_updated_at_trips
BEFORE UPDATE ON public.trips
FOR EACH ROW
EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at_bookings ON public.bookings;
CREATE TRIGGER trg_set_updated_at_bookings
BEFORE UPDATE ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.fn_set_updated_at();

-- ====================================================================
-- SECTION 7: ATTACH AUDIT & COUNTER TRIGGERS (drop-if-exists then create)
-- ====================================================================

-- Audit triggers (selected tables)
DROP TRIGGER IF EXISTS trg_audit_trips ON public.trips;
CREATE TRIGGER trg_audit_trips AFTER INSERT OR UPDATE OR DELETE ON public.trips
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();

DROP TRIGGER IF EXISTS trg_audit_itineraries ON public.itineraries;
CREATE TRIGGER trg_audit_itineraries AFTER INSERT OR UPDATE OR DELETE ON public.itineraries
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();

DROP TRIGGER IF EXISTS trg_audit_hotels ON public.hotels;
CREATE TRIGGER trg_audit_hotels AFTER INSERT OR UPDATE OR DELETE ON public.hotels
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();

DROP TRIGGER IF EXISTS trg_audit_transport ON public.transport_options;
CREATE TRIGGER trg_audit_transport AFTER INSERT OR UPDATE OR DELETE ON public.transport_options
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();

DROP TRIGGER IF EXISTS trg_audit_guides ON public.guides;
CREATE TRIGGER trg_audit_guides AFTER INSERT OR UPDATE OR DELETE ON public.guides
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();

DROP TRIGGER IF EXISTS trg_audit_bookings ON public.bookings;
CREATE TRIGGER trg_audit_bookings AFTER INSERT OR UPDATE OR DELETE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();

-- Trip counters
DROP TRIGGER IF EXISTS trg_trip_count ON public.trips;
CREATE TRIGGER trg_trip_count AFTER INSERT OR DELETE OR UPDATE ON public.trips
FOR EACH ROW EXECUTE FUNCTION public.fn_update_user_trip_count();

-- Booking counters
DROP TRIGGER IF EXISTS trg_booking_count ON public.bookings;
CREATE TRIGGER trg_booking_count AFTER INSERT OR DELETE OR UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.fn_update_user_booking_count();

-- Itinerary count updating: reuse itinerary function logic by calling trip update function
CREATE OR REPLACE FUNCTION public.fn_update_itinerary_count_and_touch() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.trips SET total_days = GREATEST(COALESCE(total_days,0), NEW.day_number), updated_at = now() WHERE id = NEW.trip_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.trips SET updated_at = now() WHERE id = OLD.trip_id;
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.trips SET updated_at = now() WHERE id = NEW.trip_id;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_itinerary_count ON public.itineraries;
CREATE TRIGGER trg_itinerary_count AFTER INSERT OR DELETE OR UPDATE ON public.itineraries
FOR EACH ROW EXECUTE FUNCTION public.fn_update_itinerary_count_and_touch();

-- ====================================================================
-- SECTION 8: MIGRATION HELPERS (trips.cities -> cities/trip_cities), PK-safety
-- ====================================================================

-- Normalize trips.cities if present
DO $$
DECLARE
  has_cities boolean;
  has_state boolean;
  has_state_name boolean;
  state_col text;
  target_name_col text;
  target_state_col text;
  alt_name_col text := NULL;
  alt_name_notnull boolean := false;
  alt_state_col text := NULL;
  alt_state_notnull boolean := false;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'cities'
  ) INTO has_cities;

  SELECT EXISTS(
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'state'
  ) INTO has_state;

  SELECT EXISTS(
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'state_name'
  ) INTO has_state_name;

  IF NOT has_cities THEN
    RETURN;
  END IF;

  -- Prefer 'state' column if present, else 'state_name', else NULL (use empty string)
  IF has_state THEN
    state_col := 'state';
  ELSIF has_state_name THEN
    state_col := 'state_name';
  ELSE
    state_col := NULL;
  END IF;

  -- detect what the cities table actually calls the name/state columns (legacy variants)
  SELECT CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='name') THEN 'name'
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='city_name') THEN 'city_name'
    ELSE NULL END
  INTO target_name_col;

  SELECT CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='state_name') THEN 'state_name'
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='state') THEN 'state'
    ELSE NULL END
  INTO target_state_col;

  -- detect alternate name/state column presence and not-null status so we can populate both if needed
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='name') AND
     EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='city_name') THEN
    IF target_name_col = 'name' THEN
      alt_name_col := 'city_name';
    ELSE
      alt_name_col := 'name';
    END IF;
    SELECT is_nullable = 'NO' INTO alt_name_notnull FROM information_schema.columns
    WHERE table_schema='public' AND table_name='cities' AND column_name = alt_name_col;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='state_name') AND
     EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='state') THEN
    IF target_state_col = 'state_name' THEN
      alt_state_col := 'state';
    ELSE
      alt_state_col := 'state_name';
    END IF;
    SELECT is_nullable = 'NO' INTO alt_state_notnull FROM information_schema.columns
    WHERE table_schema='public' AND table_name='cities' AND column_name = alt_state_col;
  END IF;

  IF target_name_col IS NULL THEN
    RAISE NOTICE 'public.cities has no name-like column (name/city_name); skipping cities migration';
  ELSE
    IF state_col IS NOT NULL THEN
      -- Insert unique cities using the detected state column using anti-join, mapping into actual cities columns
      IF target_state_col IS NOT NULL THEN
        IF alt_name_col IS NOT NULL AND alt_name_notnull THEN
          -- populate both name variants to avoid leaving NOT NULL alt column empty
          EXECUTE format(
            'INSERT INTO public.cities (%I, %I, %I)
             SELECT COALESCE(names.name, '''') AS name, COALESCE(names.name, '''') AS alt_name, COALESCE(names.state, '''') AS state
             FROM (
               SELECT DISTINCT name, COALESCE(%I::text, '''') AS state
               FROM public.trips, unnest(cities) AS name
               WHERE cities IS NOT NULL AND name IS NOT NULL AND trim(name) <> ''''
             ) AS names
             WHERE NOT EXISTS (
               SELECT 1 FROM public.cities c WHERE c.%I = COALESCE(names.name, '''') AND c.%I = COALESCE(names.state, '''')
             )',
            target_name_col, alt_name_col, target_state_col, state_col, target_name_col, target_state_col
          );
        ELSE
          EXECUTE format(
            'INSERT INTO public.cities (%I, %I)
             SELECT COALESCE(names.name, '''') AS name, COALESCE(names.state, '''') AS state
             FROM (
               SELECT DISTINCT name, COALESCE(%I::text, '''') AS state
               FROM public.trips, unnest(cities) AS name
               WHERE cities IS NOT NULL AND name IS NOT NULL AND trim(name) <> ''''
             ) AS names
             WHERE NOT EXISTS (
               SELECT 1 FROM public.cities c WHERE c.%I = COALESCE(names.name, '''') AND c.%I = COALESCE(names.state, '''')
             )',
            target_name_col, target_state_col, state_col, target_name_col, target_state_col
          );
        END IF;
      ELSE
        -- target has no state column; only insert name
        IF alt_name_col IS NOT NULL AND alt_name_notnull THEN
          EXECUTE format(
            'INSERT INTO public.cities (%I, %I)
             SELECT DISTINCT COALESCE(name, '''') AS name, COALESCE(name, '''') AS alt_name
             FROM public.trips, unnest(cities) AS name
             WHERE cities IS NOT NULL AND name IS NOT NULL AND trim(name) <> ''''
             AND NOT EXISTS (SELECT 1 FROM public.cities c WHERE c.%I = COALESCE(name, ''''))',
            target_name_col, alt_name_col, target_name_col
          );
        ELSE
          EXECUTE format(
            'INSERT INTO public.cities (%I)
             SELECT DISTINCT COALESCE(name, '''') AS name
             FROM public.trips, unnest(cities) AS name
             WHERE cities IS NOT NULL AND name IS NOT NULL AND trim(name) <> ''''
             AND NOT EXISTS (SELECT 1 FROM public.cities c WHERE c.%I = COALESCE(name, ''''))',
            target_name_col, target_name_col
          );
        END IF;
      END IF;

      -- Populate trip_cities mapping using the detected target columns
      IF target_state_col IS NOT NULL THEN
        EXECUTE format(
          'INSERT INTO public.trip_cities (trip_id, city_id, day_number)
           SELECT t.id, c.id, NULL
           FROM public.trips t
           CROSS JOIN LATERAL unnest(t.cities) AS cname(name)
           JOIN public.cities c ON c.%I = COALESCE(cname.name, '''') AND c.%I = COALESCE(t.%I::text, '''')
           WHERE cname.name IS NOT NULL AND trim(cname.name) <> ''''
           AND NOT EXISTS (SELECT 1 FROM public.trip_cities tc WHERE tc.trip_id = t.id AND tc.city_id = c.id)',
          target_name_col, target_state_col, state_col
        );
      ELSE
        EXECUTE format(
          'INSERT INTO public.trip_cities (trip_id, city_id, day_number)
           SELECT t.id, c.id, NULL
           FROM public.trips t
           CROSS JOIN LATERAL unnest(t.cities) AS cname(name)
           JOIN public.cities c ON c.%I = COALESCE(cname.name, '''')
           WHERE cname.name IS NOT NULL AND trim(cname.name) <> ''''
           AND NOT EXISTS (SELECT 1 FROM public.trip_cities tc WHERE tc.trip_id = t.id AND tc.city_id = c.id)',
          target_name_col
        );
      END IF;
    ELSE
      -- No state column available in trips; treat state as empty string
      IF target_state_col IS NOT NULL THEN
        EXECUTE format(
          'INSERT INTO public.cities (%I, %I)
           SELECT COALESCE(names.name, '''') AS name, COALESCE(names.state, '''') AS state
           FROM (
             SELECT DISTINCT name, '''' AS state
             FROM public.trips, unnest(cities) AS name
             WHERE cities IS NOT NULL AND name IS NOT NULL AND trim(name) <> ''''
           ) AS names
           WHERE NOT EXISTS (
             SELECT 1 FROM public.cities c WHERE c.%I = COALESCE(names.name, '''') AND c.%I = COALESCE(names.state, '''')
           )',
          target_name_col, target_state_col, target_name_col, target_state_col
        );

        EXECUTE format(
          'INSERT INTO public.trip_cities (trip_id, city_id, day_number)
           SELECT t.id, c.id, NULL
           FROM public.trips t
           CROSS JOIN LATERAL unnest(t.cities) AS cname(name)
           JOIN public.cities c ON c.%I = COALESCE(cname.name, '''') AND c.%I = ''''
           WHERE cname.name IS NOT NULL AND trim(cname.name) <> ''''
           AND NOT EXISTS (SELECT 1 FROM public.trip_cities tc WHERE tc.trip_id = t.id AND tc.city_id = c.id)',
          target_name_col, target_state_col
        );
      ELSE
        -- target has no state column; insert only names
        EXECUTE format(
          'INSERT INTO public.cities (%I)
           SELECT DISTINCT COALESCE(name, '''') AS name
           FROM public.trips, unnest(cities) AS name
           WHERE cities IS NOT NULL AND name IS NOT NULL AND trim(name) <> ''''
           AND NOT EXISTS (SELECT 1 FROM public.cities c WHERE c.%I = COALESCE(name, ''''))',
          target_name_col, target_name_col
        );

        EXECUTE format(
          'INSERT INTO public.trip_cities (trip_id, city_id, day_number)
           SELECT t.id, c.id, NULL
           FROM public.trips t
           CROSS JOIN LATERAL unnest(t.cities) AS cname(name)
           JOIN public.cities c ON c.%I = COALESCE(cname.name, '''')
           WHERE cname.name IS NOT NULL AND trim(cname.name) <> ''''
           AND NOT EXISTS (SELECT 1 FROM public.trip_cities tc WHERE tc.trip_id = t.id AND tc.city_id = c.id)',
          target_name_col
        );
      END IF;
    END IF;
  END IF;
END$$;

-- PK safety helper: attempts to add primary keys if safe
CREATE OR REPLACE FUNCTION public._add_pk_if_safe(tbl regclass, colname text, pk_name text) RETURNS text AS $$
DECLARE
  null_count bigint;
  dup_count bigint;
  has_pk boolean;
BEGIN
  EXECUTE format('SELECT count(*) FROM %s WHERE %I IS NULL', tbl::text, colname) INTO null_count;
  EXECUTE format('SELECT count(*) FROM (SELECT %I FROM %s GROUP BY %I HAVING count(*)>1) _x', colname, tbl::text, colname) INTO dup_count;
  SELECT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid = tbl::oid AND contype = 'p') INTO has_pk;
  IF has_pk THEN
    RETURN format('table %s already has a PK', tbl::text);
  END IF;
  IF null_count = 0 AND dup_count = 0 THEN
    EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I PRIMARY KEY (%I)', tbl::text, pk_name, colname);
    RETURN format('PK added to %s(%s)', tbl::text, colname);
  ELSE
    RETURN format('SKIPPED adding PK to %s: null_count=%s dup_count=%s', tbl::text, null_count, dup_count);
  END IF;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE r text;
BEGIN
  r := public._add_pk_if_safe('public.users'::regclass, 'id', 'users_pkey'); RAISE NOTICE '%', r;
  r := public._add_pk_if_safe('public.trips'::regclass, 'id', 'trips_pkey'); RAISE NOTICE '%', r;
  r := public._add_pk_if_safe('public.itineraries'::regclass, 'id', 'itineraries_pkey'); RAISE NOTICE '%', r;
  r := public._add_pk_if_safe('public.hotels'::regclass, 'id', 'hotels_pkey'); RAISE NOTICE '%', r;
  r := public._add_pk_if_safe('public.transport_options'::regclass, 'id', 'transport_options_pkey'); RAISE NOTICE '%', r;
  r := public._add_pk_if_safe('public.guides'::regclass, 'id', 'guides_pkey'); RAISE NOTICE '%', r;
  r := public._add_pk_if_safe('public.bookings'::regclass, 'id', 'bookings_pkey'); RAISE NOTICE '%', r;
END$$;

DROP FUNCTION IF EXISTS public._add_pk_if_safe(regclass, text, text);

-- ====================================================================
-- SECTION 9: SANITY FIXES (safe defaults fill; not destructive)
-- ====================================================================

DO $$
BEGIN
  -- bookings defaults
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='bookings') THEN
    UPDATE public.bookings SET total_amount = 0 WHERE total_amount IS NULL;
    UPDATE public.bookings SET status = 'pending' WHERE status IS NULL;
  END IF;

  -- trips defaults
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='trips') THEN
    UPDATE public.trips SET title = 'Untitled Trip' WHERE title IS NULL;
  END IF;

  -- hotels/guides/transport default names
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='hotels') THEN
    UPDATE public.hotels SET name = 'Unknown Hotel' WHERE name IS NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='transport_options') THEN
    UPDATE public.transport_options SET name = 'Unknown Transport' WHERE name IS NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='guides') THEN
    UPDATE public.guides SET name = 'Unknown Guide' WHERE name IS NULL;
  END IF;
END$$;

-- ====================================================================
-- SECTION 10: SEED DATA (idempotent)
-- ====================================================================

-- Cities
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.cities WHERE name='Calangute' AND state_name='Goa') THEN
    INSERT INTO public.cities (name, state_name) VALUES ('Calangute','Goa');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cities WHERE name='Panaji' AND state_name='Goa') THEN
    INSERT INTO public.cities (name, state_name) VALUES ('Panaji','Goa');
  END IF;
END$$;

-- Hotels
DO $$
DECLARE
  cid_cal BIGINT;
  cid_pan BIGINT;
BEGIN
  -- try to lookup city ids, but insert hotels even if cities are missing (allows seeds to work
  -- when the cities migration hasn't run or failed)
  SELECT id INTO cid_cal FROM public.cities WHERE name='Calangute' LIMIT 1;
  SELECT id INTO cid_pan FROM public.cities WHERE name='Panaji' LIMIT 1;

  IF NOT EXISTS (SELECT 1 FROM public.hotels WHERE name='Luxury Beach Resort') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='hotels' AND column_name='description') THEN
      INSERT INTO public.hotels (name, city_id, state, rating, price_per_night, description)
      VALUES ('Luxury Beach Resort', cid_cal, 'Goa', 4.8, 5000, 'Beachfront resort with pool');
    ELSE
      INSERT INTO public.hotels (name, city_id, state, rating, price_per_night)
      VALUES ('Luxury Beach Resort', cid_cal, 'Goa', 4.8, 5000);
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

-- Hotel images (no-op if empty url already exists)
DO $$
DECLARE hid BIGINT;
BEGIN
  SELECT id INTO hid FROM public.hotels WHERE name='Luxury Beach Resort' LIMIT 1;
  IF hid IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.hotel_images WHERE hotel_id = hid AND image_url = '') THEN
      INSERT INTO public.hotel_images (hotel_id, image_url) VALUES (hid, '');
    END IF;
  END IF;
END$$;

-- Transport options
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

-- Guides + languages
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

-- Trips seed
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.trips WHERE title = 'Seed: Weekend in Lisbon') THEN
    INSERT INTO public.trips (user_id, title, total_days, budget_per_person) VALUES (NULL, 'Seed: Weekend in Lisbon', 2, 10000);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.trips WHERE title = 'Seed: Mountain Hike') THEN
    INSERT INTO public.trips (user_id, title, total_days, budget_per_person) VALUES (NULL, 'Seed: Mountain Hike', 2, 8000);
  END IF;
END$$;

-- Bookings + relations seed (safe)
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
    -- Use 'pending' for seed bookings so they don't appear as confirmed by default
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

-- ====================================================================
-- SECTION 11: FINAL INDEXES / PERFORMANCE
-- ====================================================================

CREATE INDEX IF NOT EXISTS idx_trip_cities_trip ON public.trip_cities (trip_id);
CREATE INDEX IF NOT EXISTS idx_itineraries_trip ON public.itineraries (trip_id);
CREATE INDEX IF NOT EXISTS idx_guides_language ON public.guide_languages (language);

-- Development-friendly grants: allow simple SELECT access so frontend (anon) can read seeds
-- NOTE: In production you should use RLS policies instead of broad grants.
-- Allow anonymous/select access for development seeds and frontend reads.
-- In production, prefer explicit RLS policies instead of broad grants.
GRANT SELECT ON TABLE
  public.hotels,
  public.transport_options,
  public.guides,
  public.cities,
  public.hotel_images,
  public.trips,
  public.trip_cities,
  public.itineraries,
  public.bookings,
  public.booking_hotels,
  public.booking_transport,
  public.booking_guides,
  public.booking_travelers
TO public;

COMMIT;

-- ====================================================================
-- END OF MASTER SCRIPT
-- ====================================================================
