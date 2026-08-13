SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'app_users';

SELECT grantee, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_name = 'app_users' AND grantee IN ('anon', 'authenticated');

SELECT polname, polroles, polcmd, polqual, polwithcheck 
FROM pg_policy 
WHERE polrelid = 'public.app_users'::regclass;
