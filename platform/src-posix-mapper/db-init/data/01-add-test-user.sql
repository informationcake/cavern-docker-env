-- Add the user to the posixmap.users table.
INSERT INTO posixmap.users (username) VALUES ('alexclarke') ON CONFLICT (username) DO NOTHING;

-- Add a corresponding group
INSERT INTO posixmap.groups (groupuri) VALUES ('ivo://opencadc.org/groups/alexclarke') ON CONFLICT (groupuri) DO NOTHING;
