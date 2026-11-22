-- Proves the harness can actually fail: role switching must change the active
-- database role and the identity auth.uid() sees. If these pass vacuously, every
-- cross-user test after this one would be meaningless.
begin;
select plan(7);

select is(current_user::text, 'postgres', 'setup runs as the superuser');

select tests.create_user('alice@example.test') as alice \gset
select tests.create_user('bob@example.test') as bob \gset

select tests.authenticate_as(:'alice'::uuid);
select is(current_user::text, 'authenticated', 'authenticate_as switches the database role');
select is(auth.uid(), :'alice'::uuid, 'auth.uid() returns the impersonated user');

reset role;
select tests.authenticate_as(:'bob'::uuid);
select is(auth.uid(), :'bob'::uuid, 'switching to a second user changes auth.uid()');
select isnt(auth.uid(), :'alice'::uuid, 'the previous user is no longer active');

reset role;
select tests.authenticate_as_anon();
select is(current_user::text, 'anon', 'authenticate_as_anon switches to the anon role');
select is(auth.uid(), null::uuid, 'a signed-out caller has no user id');

select * from finish();
rollback;
