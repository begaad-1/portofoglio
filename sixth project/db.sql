-- Drop existing objects
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop policy if exists "Public profiles are viewable by everyone" on profiles;
drop policy if exists "Users can insert their own profile" on profiles;
drop policy if exists "Users can update own profile" on profiles;
drop policy if exists "Users can delete their own profile" on profiles;
drop table if exists public.profiles;

-- Create profiles table
create table public.profiles (
    id uuid references auth.users on delete cascade primary key,
    email text,
    full_name text,
    avatar_url text,
    username text unique,
    location text default 'Not set',
    professional_title text default 'Not set',
    updated_at timestamp with time zone default now(),
    constraint username_length check (char_length(username) >= 3)
);

-- Enable RLS
alter table public.profiles enable row level security;

-- Create policies
create policy "Profiles are viewable by everyone"
    on profiles for select
    using ( true );

create policy "Users can insert their own profile"
    on profiles for insert
    with check ( auth.uid() = id );

create policy "Users can update own profile"
    on profiles for update
    using ( auth.uid() = id );

-- Create function to handle new user creation
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
    username_base text;
    username_final text;
    counter integer := 0;
begin
    -- Get username from metadata or email
    username_base := coalesce(
        new.raw_user_meta_data->>'username',
        split_part(new.email, '@', 1)
    );
    
    -- Ensure username is at least 3 characters
    if length(username_base) < 3 then
        username_base := username_base || '_user';
    end if;
    
    -- Try to insert with unique username
    loop
        begin
            username_final := case
                when counter = 0 then username_base
                else username_base || counter::text
            end;
            
            insert into public.profiles (
                id,
                email,
                full_name,
                username,
                location,
                professional_title
            ) values (
                new.id,
                new.email,
                coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
                username_final,
                coalesce(new.raw_user_meta_data->>'location', 'Not set'),
                coalesce(new.raw_user_meta_data->>'professional_title', 'Not set')
            );
            exit;
        exception
            when unique_violation then
                counter := counter + 1;
                if counter > 1000 then
                    raise exception 'Could not generate unique username';
                end if;
                continue;
        end;
    end loop;
    
    return new;
end;
$$;

-- Create trigger for new user creation
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user(); 