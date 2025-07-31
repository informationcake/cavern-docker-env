-- Create the schema for the posix mapper
CREATE SCHEMA posixmap;
GRANT ALL ON SCHEMA posixmap TO cadmin;

-- Create the necessary tables within the schema
CREATE TABLE posixmap.users (
    username VARCHAR(255) PRIMARY KEY,
    uid INTEGER UNIQUE NOT NULL,
    primary_gid INTEGER NOT NULL
);

CREATE TABLE posixmap.groups (
    groupname VARCHAR(255) PRIMARY KEY,
    gid INTEGER UNIQUE NOT NULL
);

CREATE TABLE posixmap.group_membership (
    uid INTEGER REFERENCES posixmap.users(uid),
    gid INTEGER REFERENCES posixmap.groups(gid),
    PRIMARY KEY (uid, gid)
);
