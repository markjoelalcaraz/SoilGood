-- SoilGood — one shared illustration per catalog crop.
-- Run in the Supabase SQL Editor after supabase_crop_ranges_v1.sql.
-- Safe to re-run.
--
-- The JPG files live in the repo at assets/crops/<file>.jpg.
-- illustration_path is the object key for a later public Storage bucket
-- named crop-illustrations. Do not store the image bytes in this table.
-- Upload those files when the farm grid ships in the app. Until then the
-- column can stay null on a database that has not been seeded yet.

alter table public.crops
  add column if not exists illustration_path text;

update public.crops set illustration_path = 'crops/rice.jpg' where name = 'Rice (Palay)';
update public.crops set illustration_path = 'crops/corn.jpg' where name = 'Corn (Mais)';
update public.crops set illustration_path = 'crops/tomato.jpg' where name = 'Tomato';
update public.crops set illustration_path = 'crops/eggplant.jpg' where name = 'Eggplant (Talong)';
update public.crops set illustration_path = 'crops/ampalaya.jpg' where name = 'Ampalaya';
update public.crops set illustration_path = 'crops/sitaw.jpg' where name = 'Sitaw';
update public.crops set illustration_path = 'crops/okra.jpg' where name = 'Okra';
update public.crops set illustration_path = 'crops/cabbage.jpg' where name = 'Cabbage (Repolyo)';
update public.crops set illustration_path = 'crops/onion.jpg' where name = 'Onion (Sibuyas)';
update public.crops set illustration_path = 'crops/garlic.jpg' where name = 'Garlic (Bawang)';
update public.crops set illustration_path = 'crops/chili.jpg' where name = 'Chili (Sili)';
update public.crops set illustration_path = 'crops/cucumber.jpg' where name = 'Cucumber (Pipino)';
update public.crops set illustration_path = 'crops/squash.jpg' where name = 'Squash (Kalabasa)';
update public.crops set illustration_path = 'crops/peanut.jpg' where name = 'Peanut (Mani)';
update public.crops set illustration_path = 'crops/cassava.jpg' where name = 'Cassava (Kamoteng kahoy)';
update public.crops set illustration_path = 'crops/sweet-potato.jpg' where name = 'Sweet potato (Kamote)';
update public.crops set illustration_path = 'crops/banana.jpg' where name = 'Banana (Saba)';
