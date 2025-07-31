-- Add the user 'testuser' to the posixmap schema
INSERT INTO posixmap.users (username, uid, primary_gid) VALUES ('testuser', 10001, 50001);

-- Add a corresponding group for 'testuser'
INSERT INTO posixmap.groups (groupname, gid) VALUES ('testuser', 50001);

-- Add the user to their own group
INSERT INTO posixmap.group_membership (uid, gid) VALUES (10001, 50001);
