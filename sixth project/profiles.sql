-- Create the profiles table
create table profiles (
    id uuid default uuid_generate_v4() primary key,
    user_id uuid references auth.users on delete cascade,
    updated_at timestamp with time zone,
    username text unique,
    full_name text,
    first_name text,
    last_name text,
    email text,
    location text,
    phone_number text,
    avatar_url text,
    professional_title text
);

-- Enable Row Level Security
alter table profiles enable row level security;

-- Create storage bucket for avatars (if it doesn't exist)
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Drop existing policies (in case they exist)
drop policy if exists "Public profiles are viewable by everyone." on profiles;
drop policy if exists "Users can insert their own profile." on profiles;
drop policy if exists "Users can update own profile." on profiles;
drop policy if exists "Avatar images are publicly accessible." on storage.objects;
drop policy if exists "Anyone can upload an avatar." on storage.objects;

-- Create policies for profiles table
create policy "Public profiles are viewable by everyone."
    on profiles for select
    using (true);

create policy "Users can insert their own profile."
    on profiles for insert
    with check (auth.uid() = user_id);

create policy "Users can update own profile."
    on profiles for update
    using (auth.uid() = user_id);

-- Create policies for avatar storage
create policy "Avatar images are publicly accessible."
    on storage.objects for select
    using (bucket_id = 'avatars');

create policy "Anyone can upload an avatar."
    on storage.objects for insert
    with check (bucket_id = 'avatars'); 