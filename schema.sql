

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."gender_enum" AS ENUM (
    'Male',
    'Female',
    'Other'
);


ALTER TYPE "public"."gender_enum" OWNER TO "postgres";


CREATE TYPE "public"."partner_category" AS ENUM (
    'Doctors',
    'Clinics',
    'Homecare',
    'Charities'
);


ALTER TYPE "public"."partner_category" OWNER TO "postgres";


CREATE TYPE "public"."specialty_enum" AS ENUM (
    'Anatomy and Pathological Cytology',
    'Cardiology',
    'Dermatology and Venereology',
    'Endocrinology and Diabetology',
    'Epidemiology and Preventive Medicine',
    'Gastroenterology and Hepatology',
    'Hematology (Clinical)',
    'Infectious Diseases',
    'Internal Medicine',
    'Medical Oncology',
    'Nephrology',
    'Neurology',
    'Nuclear Medicine',
    'Pediatrics',
    'Physical Medicine and Rehabilitation',
    'Pneumology',
    'Psychiatry',
    'Radiology / Medical Imaging',
    'Radiotherapy',
    'Rheumatology',
    'Sports Medicine',
    'Anesthesiology and Reanimation',
    'Cardiovascular Surgery',
    'General Surgery',
    'Maxillofacial Surgery',
    'Neurosurgery',
    'Obstetrics and Gynecology',
    'Ophthalmology',
    'Orthopedics and Traumatology',
    'Otorhinolaryngology (ENT)',
    'Pediatric Surgery',
    'Plastic, Reconstructive, and Aesthetic Surgery',
    'Thoracic Surgery',
    'Urology',
    'Vascular Surgery',
    'Biochemistry',
    'Clinical Neurophysiology',
    'Hematology (Biological)',
    'Histology, Embryology, and Cytogenetics',
    'Immunology',
    'Microbiology',
    'Medical Biophysics',
    'Parasitology and Mycology',
    'Pharmacology',
    'Physiology',
    'Toxicology',
    'Child Psychiatry',
    'Community Health / Public Health',
    'Emergency Medicine',
    'Forensic Medicine and Medical Deontology',
    'Occupational Medicine',
    'Stomatology',
    'Transfusion Medicine (Hemobiology)'
);


ALTER TYPE "public"."specialty_enum" OWNER TO "postgres";


CREATE TYPE "public"."user_role_enum" AS ENUM (
    'Patient',
    'Medical Partner'
);


ALTER TYPE "public"."user_role_enum" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."book_appointment"("partner_id_arg" "uuid", "appointment_time_arg" timestamp with time zone, "on_behalf_of_name_arg" "text", "on_behalf_of_phone_arg" "text", "is_partner_override" boolean, "case_description_arg" "text", "patient_location_arg" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  booking_user_id_arg UUID := auth.uid();
  partner_data RECORD;
  has_existing_appointment BOOLEAN;
  new_appointment_number INT;
  new_appointment_status TEXT;
  day_of_week_arg TEXT;
  is_within_working_hours BOOLEAN := FALSE;
  time_range TEXT;
BEGIN
  SELECT is_active, category, confirmation_mode, booking_system_type, daily_booking_limit, working_hours, closed_days
  INTO partner_data
  FROM public.medical_partners WHERE id = partner_id_arg;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Medical partner not found.';
  END IF;

  -- MODIFICATION: Add a server-side check to prevent booking on past dates for any system type.
  IF appointment_time_arg::date < current_date AND NOT is_partner_override THEN
      RAISE EXCEPTION 'You cannot book an appointment for a past date.';
  END IF;

  IF appointment_time_arg <= now() AND NOT is_partner_override AND partner_data.booking_system_type = 'time_based' THEN
      RAISE EXCEPTION 'You cannot book an appointment in the past.';
  END IF;

  IF partner_data.category = 'Charities' THEN
    RAISE EXCEPTION 'Booking is not available for this type of partner.';
  END IF;

  IF NOT partner_data.is_active AND NOT is_partner_override THEN
    RAISE EXCEPTION 'This partner is not currently accepting appointments.';
  END IF;

  IF appointment_time_arg::date = ANY(partner_data.closed_days) THEN
      RAISE EXCEPTION 'This partner is closed on the selected date.';
  END IF;

  IF partner_data.working_hours IS NOT NULL THEN
    day_of_week_arg := EXTRACT(ISODOW FROM appointment_time_arg)::TEXT;
    IF NOT (partner_data.working_hours ? day_of_week_arg) THEN
      RAISE EXCEPTION 'This provider does not work on the selected day.';
    END IF;

    FOR time_range IN SELECT * FROM jsonb_array_elements_text(partner_data.working_hours -> day_of_week_arg)
    LOOP
      IF appointment_time_arg::TIME >= split_part(time_range, '-', 1)::TIME AND
         appointment_time_arg::TIME < split_part(time_range, '-', 2)::TIME THEN
        is_within_working_hours := TRUE;
        EXIT;
      END IF;
    END LOOP;

    IF NOT is_within_working_hours THEN
      RAISE EXCEPTION 'The selected time is outside of the provider''s working hours.';
    END IF;
  ELSE
      RAISE EXCEPTION 'This provider has not set up their working hours.';
  END IF;
  
  IF partner_data.category = 'Homecare' THEN
    new_appointment_status := 'Pending';
  ELSE
    IF partner_data.confirmation_mode = 'auto' THEN
      new_appointment_status := 'Confirmed';
    ELSE
      new_appointment_status := 'Pending';
    END IF;
  END IF;

  IF NOT is_partner_override THEN
    IF partner_data.booking_system_type = 'number_based' THEN
      SELECT EXISTS (
        SELECT 1 FROM public.appointments
        WHERE
          booking_user_id = booking_user_id_arg AND
          partner_id = partner_id_arg AND
          DATE(appointment_time AT TIME ZONE 'utc') = DATE(appointment_time_arg AT TIME ZONE 'utc') AND
          status IN ('Pending', 'Confirmed', 'Rescheduled')
      ) INTO has_existing_appointment;
      IF has_existing_appointment THEN
        RAISE EXCEPTION 'You already have an active appointment with this partner for today.';
      END IF;
    ELSE -- time_based
      SELECT EXISTS (
        SELECT 1 FROM public.appointments
        WHERE
          partner_id = partner_id_arg AND
          appointment_time = appointment_time_arg AND
          status IN ('Pending', 'Confirmed', 'Rescheduled')
      ) INTO has_existing_appointment;
      IF has_existing_appointment THEN
        RAISE EXCEPTION 'This time slot has already been booked.';
      END IF;
    END IF;
  END IF;
  
  IF partner_data.booking_system_type = 'time_based' THEN
    INSERT INTO public.appointments (partner_id, booking_user_id, appointment_time, on_behalf_of_patient_name, on_behalf_of_patient_phone, status, case_description, patient_location)
    VALUES (partner_id_arg, booking_user_id_arg, appointment_time_arg, on_behalf_of_name_arg, on_behalf_of_phone_arg, new_appointment_status, case_description_arg, patient_location_arg);
  ELSIF partner_data.booking_system_type = 'number_based' THEN
    SELECT COALESCE(MAX(appointment_number), 0) + 1
    INTO new_appointment_number
    FROM public.appointments
    WHERE
      partner_id = partner_id_arg AND
      DATE(appointment_time AT TIME ZONE 'utc') = DATE(appointment_time_arg AT TIME ZONE 'utc') AND
      status IN ('Pending', 'Confirmed', 'Rescheduled');
    
    IF partner_data.daily_booking_limit IS NOT NULL AND new_appointment_number > partner_data.daily_booking_limit THEN
      RAISE EXCEPTION 'This partner is fully booked on this day.';
    END IF;
    
    INSERT INTO public.appointments (partner_id, booking_user_id, appointment_time, on_behalf_of_patient_name, on_behalf_of_patient_phone, status, appointment_number, case_description, patient_location)
    VALUES (partner_id_arg, booking_user_id_arg, appointment_time_arg, on_behalf_of_name_arg, on_behalf_of_phone_arg, new_appointment_status, new_appointment_number, case_description_arg, patient_location_arg);
  END IF;
END;
$$;


ALTER FUNCTION "public"."book_appointment"("partner_id_arg" "uuid", "appointment_time_arg" timestamp with time zone, "on_behalf_of_name_arg" "text", "on_behalf_of_phone_arg" "text", "is_partner_override" boolean, "case_description_arg" "text", "patient_location_arg" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_and_reorder_queue"("appointment_id_arg" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  canceled_app_partner_id UUID;
  canceled_app_number INT;
  canceled_app_date DATE;
  current_user_id UUID := auth.uid();
  is_partner BOOLEAN;
BEGIN
  -- Check if the current user is the partner for this appointment
  SELECT TRUE INTO is_partner
  FROM public.appointments
  WHERE id = appointment_id_arg AND partner_id = current_user_id;

  -- Get appointment details. Allow either the patient or the partner to initiate cancellation.
  -- MODIFICATION: Cast appointment_time to DATE in UTC for consistency
  SELECT partner_id, appointment_number, DATE(appointment_time AT TIME ZONE 'utc')
  INTO canceled_app_partner_id, canceled_app_number, canceled_app_date
  FROM public.appointments
  WHERE id = appointment_id_arg AND (booking_user_id = current_user_id OR partner_id = current_user_id);

  -- If the appointment doesn't exist or doesn't belong to the user/partner, do nothing.
  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Update the status based on who is canceling
  UPDATE public.appointments
  SET status = CASE WHEN is_partner THEN 'Cancelled_ByPartner' ELSE 'Cancelled_ByUser' END
  WHERE id = appointment_id_arg;

  -- If it's not a numbered queue, there's no reordering to do.
  IF canceled_app_number IS NULL THEN
    RETURN;
  END IF;

  -- Reorder the queue for the remaining appointments on that day
  UPDATE public.appointments
  SET appointment_number = appointment_number - 1
  WHERE
    partner_id = canceled_app_partner_id
    AND DATE(appointment_time AT TIME ZONE 'utc') = canceled_app_date
    AND appointment_number > canceled_app_number
    AND status IN ('Pending', 'Confirmed', 'Rescheduled'); -- Only affect active appointments
END;
$$;


ALTER FUNCTION "public"."cancel_and_reorder_queue"("appointment_id_arg" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."close_day_and_cancel_appointments"("closed_day_arg" "date") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  partner_id_arg UUID := auth.uid();
  partner_name_text TEXT;
  affected_appointment RECORD;
BEGIN
  SELECT full_name INTO partner_name_text FROM public.medical_partners WHERE id = partner_id_arg;
  FOR affected_appointment IN
    SELECT id, booking_user_id, appointment_time
    FROM public.appointments
    WHERE partner_id = partner_id_arg
      AND status IN ('Pending', 'Confirmed')
      AND appointment_time::date = closed_day_arg
  LOOP
    PERFORM net.http_post(
      url:='https://jtoeizfokgydtsqdciuu.supabase.co/functions/v1/send-notification',
      headers:=jsonb_build_object('Content-Type', 'application/json','Authorization', 'Bearer ' || current_setting('request.jwt.claim.raw', true)),
      body:=jsonb_build_object(
        'recipient_user_id', affected_appointment.booking_user_id,
        'title', 'Appointment Canceled',
        'body', 'Your appointment on ' || to_char(affected_appointment.appointment_time, 'Mon DD') || ' with ' || partner_name_text || ' has been canceled as the provider will be closed that day.'
      )
    );
    UPDATE public.appointments
    SET status = 'Cancelled_ByPartner'
    WHERE id = affected_appointment.id;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."close_day_and_cancel_appointments"("closed_day_arg" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_user_profile"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Insert a new row into public.users
  INSERT INTO public.users (id, email, first_name, last_name, terms_agreed_at)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data ->> 'first_name',
    NEW.raw_user_meta_data ->> 'last_name',
    NOW() -- Sets the current timestamp
  );
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_user_profile"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_user_account"() RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  DELETE FROM auth.users WHERE id = auth.uid();
$$;


ALTER FUNCTION "public"."delete_user_account"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_all_specialties"() RETURNS TABLE("specialty" "text")
    LANGUAGE "plpgsql"
    AS $$
begin
  return query select unnest(enum_range(null::specialty_enum))::text;
end;
$$;


ALTER FUNCTION "public"."get_all_specialties"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_available_slots"("partner_id_arg" "uuid", "day_arg" "date") RETURNS TABLE("available_slot" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  partner_settings RECORD;
  day_of_week TEXT;
  time_ranges JSONB;
BEGIN
  SELECT category, is_active, working_hours, appointment_dur, closed_days INTO partner_settings
  FROM public.medical_partners
  WHERE id = partner_id_arg;

  -- MODIFICATION: Exit immediately if the partner is a charity or inactive.
  IF partner_settings.category = 'Charities' OR NOT partner_settings.is_active THEN
    RETURN;
  END IF;

  IF day_arg = ANY(partner_settings.closed_days) THEN
    RETURN;
  END IF;

  day_of_week := EXTRACT(ISODOW FROM day_arg)::TEXT;
  
  IF partner_settings.working_hours IS NULL OR NOT (partner_settings.working_hours ? day_of_week) THEN
    RETURN;
  END IF;

  time_ranges := partner_settings.working_hours -> day_of_week;

  RETURN QUERY
  WITH all_possible_slots AS (
    SELECT
      generate_series(
        (day_arg + split_part(range_item, '-', 1)::TIME)::TIMESTAMPTZ,
        (day_arg + split_part(range_item, '-', 2)::TIME)::TIMESTAMPTZ - (partner_settings.appointment_dur * interval '1 minute'),
        (partner_settings.appointment_dur * interval '1 minute')
      ) AS slot_time
    FROM jsonb_array_elements_text(time_ranges) AS range_item
  )
  SELECT aps.slot_time
  FROM all_possible_slots aps
  WHERE
    aps.slot_time > now() AND
    NOT EXISTS (
      SELECT 1
      FROM public.appointments a
      WHERE a.partner_id = partner_id_arg
        AND a.appointment_time = aps.slot_time
        AND a.status IN ('Pending', 'Confirmed', 'Rescheduled')
    );
END;
$$;


ALTER FUNCTION "public"."get_available_slots"("partner_id_arg" "uuid", "day_arg" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_clinic_analytics"("clinic_id_arg" "uuid") RETURNS json
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  summary_data json;
  weekly_data json;
  start_of_week date := date_trunc('week', current_date)::date;
  start_of_month date := date_trunc('month', current_date)::date;
BEGIN

  -- 1. Calculate Summary Stats
  SELECT json_build_object(
    'total', COUNT(*),
    'week_completed', COUNT(*) FILTER (WHERE a.status = 'Completed' AND a.appointment_time >= start_of_week),
    'month_completed', COUNT(*) FILTER (WHERE a.status = 'Completed' AND a.appointment_time >= start_of_month)
  )
  INTO summary_data
  FROM public.appointments a
  JOIN public.medical_partners mp ON a.partner_id = mp.id
  WHERE mp.parent_clinic_id = clinic_id_arg
    AND a.status <> 'Cancelled_ByUser';

  -- 2. Calculate Weekly Stats for the Chart
  WITH last_7_days AS (
    SELECT generate_series(
      CURRENT_DATE - INTERVAL '6 days',
      CURRENT_DATE,
      '1 day'
    )::date AS day
  ),
  clinic_doctors AS (
    SELECT id FROM public.medical_partners WHERE parent_clinic_id = clinic_id_arg
  )
  SELECT json_agg(stats)
  INTO weekly_data
  FROM (
    SELECT
      to_char(d.day, 'Dy') AS day_of_week,
      COUNT(a.id) AS appointment_count
    FROM last_7_days d
    LEFT JOIN public.appointments a
      ON DATE(a.appointment_time AT TIME ZONE 'utc') = d.day
      AND a.partner_id IN (SELECT id FROM clinic_doctors)
      AND a.status = 'Completed'
    GROUP BY d.day
    ORDER BY d.day
  ) stats;

  -- 3. Combine and Return
  RETURN json_build_object('summary', summary_data, 'weekly', weekly_data);
END;
$$;


ALTER FUNCTION "public"."get_clinic_analytics"("clinic_id_arg" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_clinic_appointments"("clinic_id_arg" "uuid", "doctor_id_arg" "uuid") RETURNS TABLE("id" bigint, "appointment_time" timestamp with time zone, "status" "text", "appointment_number" integer, "doctor_name" "text", "patient_name" "text", "case_description" "text", "patient_location" "text")
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.appointment_time,
    a.status,
    a.appointment_number,
    mp.full_name AS doctor_name,
    COALESCE(a.on_behalf_of_patient_name, u.first_name || ' ' || u.last_name, 'A Patient') AS patient_name,
    a.case_description,
    a.patient_location
  FROM
    public.appointments AS a
  JOIN
    public.medical_partners AS mp ON a.partner_id = mp.id
  LEFT JOIN
    public.users AS u ON a.booking_user_id = u.id
  WHERE
    mp.parent_clinic_id = clinic_id_arg
    AND (doctor_id_arg IS NULL OR a.partner_id = doctor_id_arg)
  ORDER BY
    a.appointment_time DESC;
END;
$$;


ALTER FUNCTION "public"."get_clinic_appointments"("clinic_id_arg" "uuid", "doctor_id_arg" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."medical_partners" (
    "id" "uuid" NOT NULL,
    "full_name" "text",
    "specialty" "public"."specialty_enum",
    "confirmation_mode" "text" DEFAULT 'auto'::"text" NOT NULL,
    "working_hours" "jsonb",
    "closed_days" "date"[],
    "appointment_dur" integer,
    "average_rating" numeric(2,1) DEFAULT 0.0,
    "review_count" integer DEFAULT 0,
    "is_verified" boolean DEFAULT false,
    "is_featured" boolean DEFAULT false,
    "photo_url" "text",
    "category" "public"."partner_category",
    "address" "text",
    "national_id_number" "text",
    "medical_license_number" "text",
    "bio" "text",
    "location_url" "text",
    "booking_system_type" "text" DEFAULT 'time_based'::"text" NOT NULL,
    "daily_booking_limit" integer DEFAULT 20,
    "is_active" boolean DEFAULT true,
    "parent_clinic_id" "uuid",
    "notifications_enabled" boolean DEFAULT true,
    "onesignal_player_id" "text",
    "fts" "tsvector"
);


ALTER TABLE "public"."medical_partners" OWNER TO "postgres";


COMMENT ON TABLE "public"."medical_partners" IS 'Stores profiles for all medical partners.';



CREATE OR REPLACE FUNCTION "public"."get_filtered_partners"("category_arg" "text", "state_arg" "text", "specialty_arg" "text") RETURNS SETOF "public"."medical_partners"
    LANGUAGE "sql"
    AS $$
  SELECT mp.*
  FROM public.medical_partners AS mp
  LEFT JOIN public.users AS u ON mp.id = u.id
  WHERE
    mp.is_verified = true AND
    mp.category::text = category_arg AND
    (state_arg IS NULL OR u.state = state_arg) AND
    (specialty_arg IS NULL OR mp.specialty = specialty_arg::public.specialty_enum);
$$;


ALTER FUNCTION "public"."get_filtered_partners"("category_arg" "text", "state_arg" "text", "specialty_arg" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_partner_analytics"("partner_id_arg" "uuid") RETURNS json
    LANGUAGE "plpgsql"
    AS $$
declare
    summary_data json;
    start_of_week date := date_trunc('week', current_date)::date;
    start_of_month date := date_trunc('month', current_date)::date;
begin
    select
        json_build_object(
            'total', count(*),
            'week_completed', count(*) filter (where status = 'Completed' and appointment_time >= start_of_week),
            'month_completed', count(*) filter (where status = 'Completed' and appointment_time >= start_of_month),
            'partner_canceled', count(*) filter (where status = 'Cancelled_ByPartner')
        )
    into summary_data
    from public.appointments
    where
        partner_id = partner_id_arg
        and status <> 'Cancelled_ByUser';

    return summary_data;
end;
$$;


ALTER FUNCTION "public"."get_partner_analytics"("partner_id_arg" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_partner_dashboard_appointments"("partner_id_arg" "uuid") RETURNS TABLE("id" bigint, "partner_id" "uuid", "booking_user_id" "uuid", "on_behalf_of_patient_name" "text", "appointment_time" timestamp with time zone, "status" "text", "on_behalf_of_patient_phone" "text", "appointment_number" integer, "is_rescheduled" boolean, "completed_at" timestamp with time zone, "has_review" boolean, "case_description" "text", "patient_location" "text", "patient_first_name" "text", "patient_last_name" "text", "patient_phone" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.partner_id,
    a.booking_user_id,
    a.on_behalf_of_patient_name,
    a.appointment_time,
    a.status,
    a.on_behalf_of_patient_phone,
    a.appointment_number,
    a.is_rescheduled,
    a.completed_at,
    a.has_review,
    a.case_description,
    a.patient_location,
    -- Aliasing user columns to match frontend expectations
    u.first_name as patient_first_name,
    u.last_name as patient_last_name,
    u.phone as patient_phone
  FROM
    public.appointments AS a
  LEFT JOIN
    public.users AS u ON a.booking_user_id = u.id
  WHERE
    a.partner_id = partner_id_arg;
END;
$$;


ALTER FUNCTION "public"."get_partner_dashboard_appointments"("partner_id_arg" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_reviews_with_user_names"("partner_id_arg" "uuid") RETURNS TABLE("rating" numeric, "review_text" "text", "created_at" timestamp with time zone, "first_name" "text", "gender" "text")
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$
  SELECT
    r.rating,
    r.review_text,
    r.created_at,
    u.first_name,
    u.gender
  FROM
    public.reviews AS r
  JOIN
    public.users AS u ON r.user_id = u.id
  WHERE
    r.partner_id = partner_id_arg
  ORDER BY
    r.created_at DESC;
$$;


ALTER FUNCTION "public"."get_reviews_with_user_names"("partner_id_arg" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_weekly_appointment_stats"("partner_id_arg" "uuid") RETURNS TABLE("day_of_week" "text", "appointment_count" bigint)
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$
  WITH last_7_days AS (
    SELECT generate_series(
      CURRENT_DATE - INTERVAL '6 days',
      CURRENT_DATE,
      '1 day'
    )::date AS day
  )
  SELECT
    to_char(d.day, 'Dy') AS day_of_week,
    COUNT(a.id) AS appointment_count
  FROM last_7_days d
  LEFT JOIN public.appointments a ON DATE(a.appointment_time AT TIME ZONE 'utc') = d.day
    AND a.partner_id = partner_id_arg
    AND a.status = 'Completed'
  GROUP BY d.day
  ORDER BY d.day;
$$;


ALTER FUNCTION "public"."get_weekly_appointment_stats"("partner_id_arg" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_appointment_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
  partner_name TEXT;
  patient_name TEXT;
  recipient_id UUID;
  notification_type TEXT;
  notification_data JSONB;
BEGIN
  SELECT full_name INTO partner_name FROM public.medical_partners WHERE id = NEW.partner_id;
  
  -- Get patient name, falling back gracefully
  SELECT COALESCE(u.first_name || ' ' || u.last_name, 'A patient')
  INTO patient_name
  FROM public.users u WHERE u.id = NEW.booking_user_id;
  
  -- Use on_behalf_of name if it exists
  IF NEW.on_behalf_of_patient_name IS NOT NULL THEN
    patient_name := NEW.on_behalf_of_patient_name;
  END IF;

  notification_data := jsonb_build_object(
    'partner_name', partner_name,
    'patient_name', patient_name,
    'appointment_time', to_char(NEW.appointment_time, 'Mon DD at HH24:MI')
  );

  IF TG_OP = 'INSERT' THEN
    recipient_id := NEW.partner_id;
    notification_type := 'NEW_BOOKING';
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status <> NEW.status THEN
      IF OLD.status = 'Pending' AND NEW.status = 'Confirmed' THEN
        recipient_id := NEW.booking_user_id;
        notification_type := 'APPOINTMENT_CONFIRMED';
      ELSIF (OLD.status = 'Pending' OR OLD.status = 'Confirmed') AND NEW.status = 'Cancelled_ByPartner' THEN
        recipient_id := NEW.booking_user_id;
        notification_type := 'APPOINTMENT_CANCELLED_BY_PARTNER';
      ELSIF NEW.status = 'Cancelled_ByUser' THEN
        recipient_id := NEW.partner_id;
        notification_type := 'APPOINTMENT_CANCELLED_BY_USER';
      END IF;
    END IF;
  END IF;

  IF recipient_id IS NOT NULL AND notification_type IS NOT NULL THEN
    PERFORM net.http_post(
        url:='https://jtoeizfokgydtsqdciuu.supabase.co/functions/v1/send-notification',
        headers:=jsonb_build_object('Content-Type', 'application/json','Authorization', 'Bearer ' || current_setting('request.jwt.claim.raw', true)),
        body:=jsonb_build_object(
            'recipient_user_id', recipient_id,
            'notification_type', notification_type,
            'data', notification_data
        )
    );
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_appointment_notification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_partner_emergency"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  partner_settings RECORD;
  affected_appointment RECORD;
BEGIN
  SELECT id, booking_system_type INTO partner_settings
  FROM public.medical_partners
  WHERE id = auth.uid();
  IF partner_settings.booking_system_type = 'time_based' THEN
    FOR affected_appointment IN
      SELECT id, booking_user_id FROM public.appointments
      WHERE partner_id = partner_settings.id
        AND status = 'Confirmed'
        AND appointment_time BETWEEN now() AND now() + interval '30 minutes'
    LOOP
      PERFORM net.http_post(
        url:='https://jtoeizfokgydtsqdciuu.supabase.co/functions/v1/send-notification',
        headers:=jsonb_build_object('Content-Type', 'application/json','Authorization', 'Bearer ' || current_setting('request.jwt.claim.raw', true)),
        body:=jsonb_build_object(
          'recipient_user_id', affected_appointment.booking_user_id,
          'title', 'Urgent Alert',
          'body', 'Due to an emergency, your upcoming appointment with ' || (SELECT full_name FROM medical_partners WHERE id = partner_settings.id) || ' has been canceled. We apologize for the inconvenience.'
        )
      );
      UPDATE public.appointments SET status = 'Cancelled_ByPartner' WHERE id = affected_appointment.id;
    END LOOP;
  ELSIF partner_settings.booking_system_type = 'number_based' THEN
    FOR affected_appointment IN
      SELECT id, booking_user_id FROM public.appointments
      WHERE partner_id = partner_settings.id
        AND status IN ('Confirmed', 'Pending')
        AND appointment_time::date = current_date
      ORDER BY appointment_number ASC
      LIMIT 5
    LOOP
      PERFORM net.http_post(
        url:='https://jtoeizfokgydtsqdciuu.supabase.co/functions/v1/send-notification',
        headers:=jsonb_build_object('Content-Type', 'application/json','Authorization', 'Bearer ' || current_setting('request.jwt.claim.raw', true)),
        body:=jsonb_build_object(
          'recipient_user_id', affected_appointment.booking_user_id,
          'title', 'Urgent Alert',
          'body', 'Due to an emergency, all upcoming appointments with ' || (SELECT full_name FROM medical_partners WHERE id = partner_settings.id) || ' today have been canceled. We apologize for the inconvenience.'
        )
      );
      UPDATE public.appointments SET status = 'Cancelled_ByPartner' WHERE id = affected_appointment.id;
    END LOOP;
  END IF;
END;
$$;


ALTER FUNCTION "public"."handle_partner_emergency"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reschedule_appointment_to_end_of_queue"("appointment_id_arg" bigint, "partner_id_arg" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
  current_num INT;
  max_num INT;
  appointment_date DATE;
BEGIN
  SELECT appointment_number, DATE(appointment_time)
  INTO current_num, appointment_date
  FROM public.appointments
  WHERE id = appointment_id_arg;
  IF NOT FOUND OR current_num IS NULL THEN
    RETURN;
  END IF;
  SELECT COALESCE(MAX(appointment_number), 0)
  INTO max_num
  FROM public.appointments
  WHERE
    partner_id = partner_id_arg
    AND DATE(appointment_time) = appointment_date
    AND status NOT IN ('Cancelled_ByUser', 'Cancelled_ByPartner');
  UPDATE public.appointments
  SET appointment_number = appointment_number - 1
  WHERE
    partner_id = partner_id_arg
    AND DATE(appointment_time) = appointment_date
    AND appointment_number > current_num;
  UPDATE public.appointments
  SET
    appointment_number = max_num,
    is_rescheduled = true
  WHERE id = appointment_id_arg;
END;
$$;


ALTER FUNCTION "public"."reschedule_appointment_to_end_of_queue"("appointment_id_arg" bigint, "partner_id_arg" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_partners"("search_term" "text") RETURNS SETOF "public"."medical_partners"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF search_term IS NULL OR search_term = '' THEN
    RETURN QUERY SELECT * FROM public.medical_partners WHERE is_verified = true LIMIT 20;
  ELSE
    RETURN QUERY
    SELECT *
    FROM public.medical_partners
    WHERE
      is_verified = true AND
      fts @@ websearch_to_tsquery('english', search_term);
  END IF;
END;
$$;


ALTER FUNCTION "public"."search_partners"("search_term" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_appointment_reminders"() RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
  upcoming_appointment RECORD;
  partner_name TEXT;
BEGIN
  FOR upcoming_appointment IN
    SELECT a.id, a.booking_user_id, a.partner_id, a.appointment_time
    FROM public.appointments a
    WHERE a.status = 'Confirmed'
    AND (
      (a.appointment_time > now() + interval '23 hours' AND a.appointment_time < now() + interval '25 hours')
      OR
      (a.appointment_time > now() AND a.appointment_time < now() + interval '2 hours')
    )
  LOOP
    SELECT full_name INTO partner_name FROM public.medical_partners WHERE id = upcoming_appointment.partner_id;
    IF upcoming_appointment.appointment_time > now() + interval '23 hours' THEN
      PERFORM net.http_post(
        url:='https://jtoeizfokgydtsqdciuu.supabase.co/functions/v1/send-notification',
        headers:=jsonb_build_object('Content-Type', 'application/json','Authorization', 'Bearer ' || current_setting('request.jwt.claim.raw', true)),
        body:=jsonb_build_object(
          'recipient_user_id', upcoming_appointment.booking_user_id,
          'title', 'Appointment Reminder',
          'body', 'This is a reminder for your appointment with ' || partner_name || ' tomorrow at ' || to_char(upcoming_appointment.appointment_time, 'HH24:MI') || '.'
        )
      );
    ELSE
      PERFORM net.http_post(
        url:='https://jtoeizfokgydtsqdciuu.supabase.co/functions/v1/send-notification',
        headers:=jsonb_build_object('Content-Type', 'application/json','Authorization', 'Bearer ' || current_setting('request.jwt.claim.raw', true)),
        body:=jsonb_build_object(
          'recipient_user_id', upcoming_appointment.booking_user_id,
          'title', 'Appointment Soon',
          'body', 'Your appointment with ' || partner_name || ' is in one hour at ' || to_char(upcoming_appointment.appointment_time, 'HH24:MI') || '.'
        )
      );
    END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."send_appointment_reminders"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_partner_application"("first_name_arg" "text", "last_name_arg" "text", "phone_arg" "text", "address_arg" "text", "national_id_arg" "text", "license_id_arg" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  user_id_arg UUID := auth.uid();
BEGIN
  -- Check if the user is already a partner
  IF EXISTS (SELECT 1 FROM public.medical_partners WHERE id = user_id_arg) THEN
    RAISE EXCEPTION 'You are already a medical partner.';
  END IF;

  -- Update the user's main profile with their latest info
  UPDATE public.users
  SET
    first_name = first_name_arg,
    last_name = last_name_arg,
    phone = phone_arg
  WHERE id = user_id_arg;

  -- Insert the application into the new table
  INSERT INTO public.partner_applications(user_id, first_name, last_name, phone, address, national_id_number, medical_license_number)
  VALUES (user_id_arg, first_name_arg, last_name_arg, phone_arg, address_arg, national_id_arg, license_id_arg);
END;
$$;


ALTER FUNCTION "public"."submit_partner_application"("first_name_arg" "text", "last_name_arg" "text", "phone_arg" "text", "address_arg" "text", "national_id_arg" "text", "license_id_arg" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_review"("appointment_id_arg" bigint, "rating_arg" integer, "comment_arg" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  target_appointment RECORD;
  reviewing_user_id UUID := auth.uid();
BEGIN
  -- Find the completed appointment
  SELECT * INTO target_appointment
  FROM public.appointments
  WHERE id = appointment_id_arg AND booking_user_id = reviewing_user_id AND status = 'Completed';

  -- Check if the appointment is valid for review
  IF NOT FOUND THEN
    RAISE EXCEPTION 'This appointment is not eligible for review.';
  END IF;

  -- Check if a review already exists for this appointment
  IF target_appointment.has_review THEN
    RAISE EXCEPTION 'A review has already been submitted for this appointment.';
  END IF;

  -- MODIFICATION: Change the review window from 2 hours to 48 hours
  IF now() > target_appointment.completed_at + INTERVAL '48 hours' THEN
    RAISE EXCEPTION 'The review period for this appointment has expired.';
  END IF;

  -- Insert the new review
  INSERT INTO public.reviews (appointment_id, partner_id, user_id, rating, comment)
  VALUES (appointment_id_arg, target_appointment.partner_id, reviewing_user_id, rating_arg, comment_arg);

  -- Mark the appointment as having a review to prevent duplicates
  UPDATE public.appointments
  SET has_review = TRUE
  WHERE id = appointment_id_arg;

END;
$$;


ALTER FUNCTION "public"."submit_review"("appointment_id_arg" bigint, "rating_arg" integer, "comment_arg" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_review"("appointment_id_arg" bigint, "rating_arg" numeric, "review_text_arg" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  target_appointment record;
BEGIN
  SELECT * INTO target_appointment
  FROM public.appointments
  WHERE id = appointment_id_arg AND booking_user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Appointment not found or you do not have permission to review it.';
  END IF;

  IF target_appointment.status <> 'Completed' THEN
    RAISE EXCEPTION 'You can only review completed appointments.';
  END IF;

  IF target_appointment.has_review = TRUE THEN
    RAISE EXCEPTION 'A review has already been submitted for this appointment.';
  END IF;

  IF target_appointment.completed_at IS NULL OR now() > target_appointment.completed_at + INTERVAL '48 hours' THEN
    RAISE EXCEPTION 'The 2-hour window to submit a review has passed.';
  END IF;

  INSERT INTO public.reviews(appointment_id, user_id, partner_id, rating, review_text)
  VALUES(appointment_id_arg, auth.uid(), target_appointment.partner_id, rating_arg, review_text_arg);

  UPDATE public.appointments
  SET has_review = TRUE
  WHERE id = appointment_id_arg;
END;
$$;


ALTER FUNCTION "public"."submit_review"("appointment_id_arg" bigint, "rating_arg" numeric, "review_text_arg" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_completed_appointments"() RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  UPDATE public.appointments AS a
  SET
    status = 'Completed',
    completed_at = now()
  FROM
    public.medical_partners AS mp
  WHERE
    a.partner_id = mp.id AND
    a.status = 'Confirmed' AND
    a.appointment_number IS NULL AND
    (a.appointment_time + (mp.appointment_dur * INTERVAL '1 minute')) < now();
END;
$$;


ALTER FUNCTION "public"."update_completed_appointments"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_partner_fts"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.fts := to_tsvector('english', NEW.full_name || ' ' || COALESCE(NEW.specialty::text, ''));
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_partner_fts"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_partner_rating_aggregates"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  UPDATE public.medical_partners
  SET
    review_count = (
      SELECT COUNT(*)
      FROM public.reviews
      WHERE partner_id = NEW.partner_id
    ),
    average_rating = (
      SELECT AVG(rating)
      FROM public.reviews
      WHERE partner_id = NEW.partner_id
    )
  WHERE id = NEW.partner_id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_partner_rating_aggregates"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_player_id"("player_id_arg" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  user_id_arg UUID := auth.uid();
BEGIN
  -- This function is called by an authenticated user.
  -- First, we update their record in the central users table.
  UPDATE public.users
  SET onesignal_player_id = player_id_arg
  WHERE id = user_id_arg;

  -- Then, we check if a record for this user also exists in the
  -- medical_partners table. If it does, we update that one too.
  UPDATE public.medical_partners
  SET onesignal_player_id = player_id_arg
  WHERE id = user_id_arg;
END;
$$;


ALTER FUNCTION "public"."update_player_id"("player_id_arg" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."appointments" (
    "id" bigint NOT NULL,
    "partner_id" "uuid" NOT NULL,
    "booking_user_id" "uuid" NOT NULL,
    "on_behalf_of_patient_name" "text",
    "appointment_time" timestamp with time zone NOT NULL,
    "status" "text" DEFAULT 'Pending'::"text" NOT NULL,
    "on_behalf_of_patient_phone" "text",
    "appointment_number" integer,
    "is_rescheduled" boolean DEFAULT false,
    "completed_at" timestamp with time zone,
    "has_review" boolean DEFAULT false,
    "case_description" "text",
    "patient_location" "text"
);


ALTER TABLE "public"."appointments" OWNER TO "postgres";


COMMENT ON TABLE "public"."appointments" IS 'Manages all appointment bookings and their status.';



ALTER TABLE "public"."appointments" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."appointments_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "is_read" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


COMMENT ON TABLE "public"."notifications" IS 'Stores notifications for users.';



ALTER TABLE "public"."notifications" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."notifications_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."partner_applications" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "first_name" "text" NOT NULL,
    "last_name" "text" NOT NULL,
    "phone" "text" NOT NULL,
    "address" "text" NOT NULL,
    "national_id_number" "text" NOT NULL,
    "medical_license_number" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."partner_applications" OWNER TO "postgres";


ALTER TABLE "public"."partner_applications" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."partner_applications_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."reviews" (
    "id" bigint NOT NULL,
    "partner_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "appointment_id" bigint NOT NULL,
    "rating" numeric(2,1) NOT NULL,
    "review_text" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."reviews" OWNER TO "postgres";


COMMENT ON TABLE "public"."reviews" IS 'Stores ratings and reviews for partners.';



ALTER TABLE "public"."reviews" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."reviews_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "first_name" "text",
    "last_name" "text",
    "phone" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "role" "public"."user_role_enum" DEFAULT 'Patient'::"public"."user_role_enum",
    "state" "text",
    "date_of_birth" "date",
    "gender" "public"."gender_enum",
    "onesignal_player_id" "text",
    "notifications_enabled" boolean DEFAULT true,
    "terms_agreed_at" timestamp with time zone
);


ALTER TABLE "public"."users" OWNER TO "postgres";


COMMENT ON TABLE "public"."users" IS 'Stores user profile data. Links to auth.users.';



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."medical_partners"
    ADD CONSTRAINT "medical_partners_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."partner_applications"
    ADD CONSTRAINT "partner_applications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."partner_applications"
    ADD CONSTRAINT "user_id_unique" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



CREATE INDEX "fts_idx" ON "public"."medical_partners" USING "gin" ("fts");



CREATE INDEX "idx_appointments_booking_user_id" ON "public"."appointments" USING "btree" ("booking_user_id");



CREATE INDEX "idx_appointments_status" ON "public"."appointments" USING "btree" ("status");



CREATE INDEX "idx_appointments_time" ON "public"."appointments" USING "btree" ("appointment_time");



CREATE INDEX "idx_notifications_user_id" ON "public"."notifications" USING "btree" ("user_id");



CREATE INDEX "idx_parent_clinic_id" ON "public"."medical_partners" USING "btree" ("parent_clinic_id");



CREATE INDEX "idx_reviews_appointment_id" ON "public"."reviews" USING "btree" ("appointment_id");



CREATE INDEX "idx_reviews_partner_id" ON "public"."reviews" USING "btree" ("partner_id");



CREATE INDEX "idx_reviews_user_id" ON "public"."reviews" USING "btree" ("user_id");



CREATE UNIQUE INDEX "unique_active_appointment_number_idx" ON "public"."appointments" USING "btree" ("partner_id", "appointment_number", "date"(("appointment_time" AT TIME ZONE 'utc'::"text"))) WHERE ("status" = ANY (ARRAY['Pending'::"text", 'Confirmed'::"text", 'Rescheduled'::"text"]));



CREATE UNIQUE INDEX "unique_active_appointment_time" ON "public"."appointments" USING "btree" ("partner_id", "appointment_time") WHERE ("status" <> ALL (ARRAY['Cancelled_ByUser'::"text", 'Cancelled_ByPartner'::"text"]));



CREATE OR REPLACE TRIGGER "on_appointment_change" AFTER INSERT OR UPDATE ON "public"."appointments" FOR EACH ROW EXECUTE FUNCTION "public"."handle_appointment_notification"();



CREATE OR REPLACE TRIGGER "on_new_review_update_aggregates" AFTER INSERT ON "public"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."update_partner_rating_aggregates"();



CREATE OR REPLACE TRIGGER "on_partner_insert_update" BEFORE INSERT OR UPDATE ON "public"."medical_partners" FOR EACH ROW EXECUTE FUNCTION "public"."update_partner_fts"();



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_booking_user_id_fkey" FOREIGN KEY ("booking_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "public"."medical_partners"("id");



ALTER TABLE ONLY "public"."medical_partners"
    ADD CONSTRAINT "medical_partners_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."medical_partners"
    ADD CONSTRAINT "medical_partners_parent_clinic_id_fkey" FOREIGN KEY ("parent_clinic_id") REFERENCES "public"."medical_partners"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."partner_applications"
    ADD CONSTRAINT "partner_applications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "public"."appointments"("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "public"."medical_partners"("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Allow authenticated users to create appointments" ON "public"."appointments" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Allow authenticated users to create reviews" ON "public"."reviews" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Allow authenticated users to read partner data" ON "public"."medical_partners" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow individual user read access" ON "public"."users" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "id"));



CREATE POLICY "Allow individual user update access" ON "public"."users" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Allow partners to update their own profile" ON "public"."medical_partners" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Allow public read access to reviews" ON "public"."reviews" FOR SELECT USING (true);



CREATE POLICY "Allow users to create their own partner application" ON "public"."partner_applications" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Allow users to read their own notifications" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Allow users to update their own notifications" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Allow users to view their own partner application" ON "public"."partner_applications" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Allow users/partners to update their own appointments" ON "public"."appointments" FOR UPDATE TO "authenticated" USING ((("auth"."uid"() = "booking_user_id") OR ("auth"."uid"() = "partner_id"))) WITH CHECK ((("auth"."uid"() = "booking_user_id") OR ("auth"."uid"() = "partner_id")));



CREATE POLICY "Allow users/partners to view their own appointments" ON "public"."appointments" FOR SELECT TO "authenticated" USING ((("auth"."uid"() = "booking_user_id") OR ("auth"."uid"() = "partner_id")));



ALTER TABLE "public"."appointments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."medical_partners" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."partner_applications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."appointments";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."medical_partners";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."users";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";














































































































































































GRANT ALL ON FUNCTION "public"."book_appointment"("partner_id_arg" "uuid", "appointment_time_arg" timestamp with time zone, "on_behalf_of_name_arg" "text", "on_behalf_of_phone_arg" "text", "is_partner_override" boolean, "case_description_arg" "text", "patient_location_arg" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."book_appointment"("partner_id_arg" "uuid", "appointment_time_arg" timestamp with time zone, "on_behalf_of_name_arg" "text", "on_behalf_of_phone_arg" "text", "is_partner_override" boolean, "case_description_arg" "text", "patient_location_arg" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."book_appointment"("partner_id_arg" "uuid", "appointment_time_arg" timestamp with time zone, "on_behalf_of_name_arg" "text", "on_behalf_of_phone_arg" "text", "is_partner_override" boolean, "case_description_arg" "text", "patient_location_arg" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."cancel_and_reorder_queue"("appointment_id_arg" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_and_reorder_queue"("appointment_id_arg" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_and_reorder_queue"("appointment_id_arg" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."close_day_and_cancel_appointments"("closed_day_arg" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."close_day_and_cancel_appointments"("closed_day_arg" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."close_day_and_cancel_appointments"("closed_day_arg" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_user_profile"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_user_profile"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_user_profile"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_user_account"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_user_account"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_user_account"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_all_specialties"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_all_specialties"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_all_specialties"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_available_slots"("partner_id_arg" "uuid", "day_arg" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_available_slots"("partner_id_arg" "uuid", "day_arg" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_available_slots"("partner_id_arg" "uuid", "day_arg" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_clinic_analytics"("clinic_id_arg" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_clinic_analytics"("clinic_id_arg" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_clinic_analytics"("clinic_id_arg" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_clinic_appointments"("clinic_id_arg" "uuid", "doctor_id_arg" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_clinic_appointments"("clinic_id_arg" "uuid", "doctor_id_arg" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_clinic_appointments"("clinic_id_arg" "uuid", "doctor_id_arg" "uuid") TO "service_role";



GRANT ALL ON TABLE "public"."medical_partners" TO "anon";
GRANT ALL ON TABLE "public"."medical_partners" TO "authenticated";
GRANT ALL ON TABLE "public"."medical_partners" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_filtered_partners"("category_arg" "text", "state_arg" "text", "specialty_arg" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_filtered_partners"("category_arg" "text", "state_arg" "text", "specialty_arg" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_filtered_partners"("category_arg" "text", "state_arg" "text", "specialty_arg" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_partner_analytics"("partner_id_arg" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_partner_analytics"("partner_id_arg" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_partner_analytics"("partner_id_arg" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_partner_dashboard_appointments"("partner_id_arg" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_partner_dashboard_appointments"("partner_id_arg" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_partner_dashboard_appointments"("partner_id_arg" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_reviews_with_user_names"("partner_id_arg" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_reviews_with_user_names"("partner_id_arg" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_reviews_with_user_names"("partner_id_arg" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_weekly_appointment_stats"("partner_id_arg" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_weekly_appointment_stats"("partner_id_arg" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_weekly_appointment_stats"("partner_id_arg" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_appointment_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_appointment_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_appointment_notification"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_partner_emergency"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_partner_emergency"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_partner_emergency"() TO "service_role";



GRANT ALL ON FUNCTION "public"."reschedule_appointment_to_end_of_queue"("appointment_id_arg" bigint, "partner_id_arg" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."reschedule_appointment_to_end_of_queue"("appointment_id_arg" bigint, "partner_id_arg" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reschedule_appointment_to_end_of_queue"("appointment_id_arg" bigint, "partner_id_arg" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."search_partners"("search_term" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."search_partners"("search_term" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_partners"("search_term" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."send_appointment_reminders"() TO "anon";
GRANT ALL ON FUNCTION "public"."send_appointment_reminders"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_appointment_reminders"() TO "service_role";



GRANT ALL ON FUNCTION "public"."submit_partner_application"("first_name_arg" "text", "last_name_arg" "text", "phone_arg" "text", "address_arg" "text", "national_id_arg" "text", "license_id_arg" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."submit_partner_application"("first_name_arg" "text", "last_name_arg" "text", "phone_arg" "text", "address_arg" "text", "national_id_arg" "text", "license_id_arg" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_partner_application"("first_name_arg" "text", "last_name_arg" "text", "phone_arg" "text", "address_arg" "text", "national_id_arg" "text", "license_id_arg" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."submit_review"("appointment_id_arg" bigint, "rating_arg" integer, "comment_arg" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."submit_review"("appointment_id_arg" bigint, "rating_arg" integer, "comment_arg" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_review"("appointment_id_arg" bigint, "rating_arg" integer, "comment_arg" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."submit_review"("appointment_id_arg" bigint, "rating_arg" numeric, "review_text_arg" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."submit_review"("appointment_id_arg" bigint, "rating_arg" numeric, "review_text_arg" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_review"("appointment_id_arg" bigint, "rating_arg" numeric, "review_text_arg" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_completed_appointments"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_completed_appointments"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_completed_appointments"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_partner_fts"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_partner_fts"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_partner_fts"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_partner_rating_aggregates"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_partner_rating_aggregates"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_partner_rating_aggregates"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_player_id"("player_id_arg" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_player_id"("player_id_arg" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_player_id"("player_id_arg" "text") TO "service_role";
























GRANT ALL ON TABLE "public"."appointments" TO "anon";
GRANT ALL ON TABLE "public"."appointments" TO "authenticated";
GRANT ALL ON TABLE "public"."appointments" TO "service_role";



GRANT ALL ON SEQUENCE "public"."appointments_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."appointments_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."appointments_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."partner_applications" TO "anon";
GRANT ALL ON TABLE "public"."partner_applications" TO "authenticated";
GRANT ALL ON TABLE "public"."partner_applications" TO "service_role";



GRANT ALL ON SEQUENCE "public"."partner_applications_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."partner_applications_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."partner_applications_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."reviews" TO "anon";
GRANT ALL ON TABLE "public"."reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."reviews" TO "service_role";



GRANT ALL ON SEQUENCE "public"."reviews_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."reviews_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."reviews_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";






























RESET ALL;
