-- Lyric Smash tables. Every table is prefixed smash_ so it can live in a shared Supabase project.
create table if not exists public.smash_profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);
create table if not exists public.smash_samples (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null,
  recipe jsonb not null,
  audio_path text,
  created_at timestamptz not null default now()
);
create table if not exists public.smash_timeline (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  kind text not null,
  title text,
  artist text,
  ref text,
  data jsonb,
  created_at timestamptz not null default now()
);
create index if not exists smash_samples_user on public.smash_samples (user_id, created_at desc);
create index if not exists smash_timeline_user on public.smash_timeline (user_id, created_at desc);

alter table public.smash_profiles enable row level security;
alter table public.smash_samples enable row level security;
alter table public.smash_timeline enable row level security;

drop policy if exists "own profile" on public.smash_profiles;
create policy "own profile" on public.smash_profiles for all using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists "own samples" on public.smash_samples;
create policy "own samples" on public.smash_samples for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "own timeline" on public.smash_timeline;
create policy "own timeline" on public.smash_timeline for all using (user_id = auth.uid()) with check (user_id = auth.uid());

insert into storage.buckets (id, name, public) values ('smash-samples', 'smash-samples', false)
on conflict (id) do nothing;
drop policy if exists "smash samples own folder read" on storage.objects;
create policy "smash samples own folder read" on storage.objects for select
  using (bucket_id = 'smash-samples' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "smash samples own folder write" on storage.objects;
create policy "smash samples own folder write" on storage.objects for insert
  with check (bucket_id = 'smash-samples' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "smash samples own folder delete" on storage.objects;
create policy "smash samples own folder delete" on storage.objects for delete
  using (bucket_id = 'smash-samples' and (storage.foldername(name))[1] = auth.uid()::text);
