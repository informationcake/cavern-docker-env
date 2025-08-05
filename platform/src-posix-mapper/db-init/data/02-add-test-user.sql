-- Add the user 'testuser' to the posixmap.users table.
INSERT INTO posixmap.users (username) VALUES ('testuser') ON CONFLICT (username) DO NOTHING;

-- Add a corresponding group for 'testuser'
INSERT INTO posixmap.groups (groupuri) VALUES ('ivo://opencadc.org/groups/testuser') ON CONFLICT (groupuri) DO NOTHING;
