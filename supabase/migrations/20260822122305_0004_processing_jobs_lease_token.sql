ALTER TABLE public.processing_jobs
ADD COLUMN lease_token UUID NULL;
