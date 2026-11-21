-- 패키지 메이커 공유 갤러리 설정
-- Supabase 화면 왼쪽 메뉴 [SQL Editor] → [New query]에 이 내용을 통째로 붙여넣고 [Run]을 누르세요.
-- 누구나(로그인 없이) 사진과 디자인을 올리고 볼 수 있지만, 고치거나 지우는 건 Supabase 화면에서 관리자만 할 수 있어요.

-- 1) 올린 작품을 저장하는 표
create table if not exists public.gallery (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  title text not null check (char_length(title) between 1 and 60),
  author text check (author is null or char_length(author) <= 24),
  note text check (note is null or char_length(note) <= 300),
  photo_path text not null check (char_length(photo_path) <= 200),
  mockup_path text check (mockup_path is null or char_length(mockup_path) <= 200),
  design jsonb not null check (pg_column_size(design) <= 8000),
  hidden boolean not null default false
);
create index if not exists gallery_created_idx on public.gallery (created_at desc);

alter table public.gallery enable row level security;
-- 새 프로젝트는 표에 접근 권한을 따로 줘야 해요 (보기·올리기만)
grant select, insert on public.gallery to anon, authenticated;

drop policy if exists "누구나 보기" on public.gallery;
create policy "누구나 보기" on public.gallery
  for select to anon, authenticated using (hidden = false);

drop policy if exists "누구나 올리기" on public.gallery;
create policy "누구나 올리기" on public.gallery
  for insert to anon, authenticated with check (hidden = false);
-- 수정·삭제 정책은 일부러 만들지 않아요. 지우거나 숨기기는 [Table Editor]에서 관리자만 할 수 있어요.

-- 2) 사진을 저장하는 공간 (사진만, 한 장에 3MB까지)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('gallery', 'gallery', true, 3145728, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 3145728,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "갤러리 사진 올리기" on storage.objects;
create policy "갤러리 사진 올리기" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'gallery');

drop policy if exists "갤러리 사진 보기" on storage.objects;
create policy "갤러리 사진 보기" on storage.objects
  for select to anon, authenticated using (bucket_id = 'gallery');
