-- Sharing: public samples, names everyone can see, comments and reactions.
alter table public.smash_samples add column if not exists is_public boolean not null default false;
create index if not exists smash_samples_public on public.smash_samples (is_public, created_at desc);

drop policy if exists "own profile" on public.smash_profiles;
drop policy if exists "profiles readable" on public.smash_profiles;
drop policy if exists "own profile write" on public.smash_profiles;
drop policy if exists "own profile update" on public.smash_profiles;
create policy "profiles readable" on public.smash_profiles for select using (true);
create policy "own profile write" on public.smash_profiles for insert with check (id = auth.uid());
create policy "own profile update" on public.smash_profiles for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "own samples" on public.smash_samples;
drop policy if exists "samples readable" on public.smash_samples;
drop policy if exists "own samples insert" on public.smash_samples;
drop policy if exists "own samples update" on public.smash_samples;
drop policy if exists "own samples delete" on public.smash_samples;
create policy "samples readable" on public.smash_samples for select using (is_public or user_id = auth.uid());
create policy "own samples insert" on public.smash_samples for insert with check (user_id = auth.uid());
create policy "own samples update" on public.smash_samples for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own samples delete" on public.smash_samples for delete using (user_id = auth.uid());

create table if not exists public.smash_comments (
  id uuid primary key default gen_random_uuid(),
  sample_id uuid not null references public.smash_samples on delete cascade,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);
create index if not exists smash_comments_sample on public.smash_comments (sample_id, created_at);
alter table public.smash_comments enable row level security;
drop policy if exists "comments readable" on public.smash_comments;
drop policy if exists "own comments insert" on public.smash_comments;
drop policy if exists "own comments delete" on public.smash_comments;
create policy "comments readable" on public.smash_comments for select
  using (exists (select 1 from public.smash_samples s where s.id = sample_id and (s.is_public or s.user_id = auth.uid())));
create policy "own comments insert" on public.smash_comments for insert
  with check (user_id = auth.uid() and exists (select 1 from public.smash_samples s where s.id = sample_id and (s.is_public or s.user_id = auth.uid())));
create policy "own comments delete" on public.smash_comments for delete using (user_id = auth.uid());

create table if not exists public.smash_reactions (
  sample_id uuid not null references public.smash_samples on delete cascade,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  emoji text not null check (char_length(emoji) <= 8),
  created_at timestamptz not null default now(),
  primary key (sample_id, user_id, emoji)
);
alter table public.smash_reactions enable row level security;
drop policy if exists "reactions readable" on public.smash_reactions;
drop policy if exists "own reactions insert" on public.smash_reactions;
drop policy if exists "own reactions delete" on public.smash_reactions;
create policy "reactions readable" on public.smash_reactions for select
  using (exists (select 1 from public.smash_samples s where s.id = sample_id and (s.is_public or s.user_id = auth.uid())));
create policy "own reactions insert" on public.smash_reactions for insert
  with check (user_id = auth.uid() and exists (select 1 from public.smash_samples s where s.id = sample_id and s.is_public));
create policy "own reactions delete" on public.smash_reactions for delete using (user_id = auth.uid());

drop policy if exists "smash samples public audio" on storage.objects;
create policy "smash samples public audio" on storage.objects for select
  using (bucket_id = 'smash-samples' and exists (select 1 from public.smash_samples s where s.audio_path = storage.objects.name and s.is_public));

do $$ begin
  alter publication supabase_realtime add table public.smash_comments;
exception when duplicate_object then null; when undefined_object then null; end $$;

notify pgrst, 'reload schema';
